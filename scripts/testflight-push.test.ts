import { describe, expect, test } from "bun:test";
import { existsSync, readdirSync, readFileSync } from "node:fs";
import { join, resolve } from "node:path";

const root = resolve(import.meta.dir, "..");
const bundle = "com.ramimaalouf.multiplexer";
const team = "3V2UU7RRK9";
const group = `group.${bundle}`;
const keychain = `${team}.${bundle}`;

function run(args: string[]): string {
  const result = Bun.spawnSync(args, { cwd: root });
  if (result.exitCode !== 0) throw new Error(`${args[0]} failed (${result.exitCode})`);
  return result.stdout.toString();
}

function plist(path: string): any {
  return JSON.parse(run(["plutil", "-convert", "json", "-o", "-", path]));
}

function entitlements(path: string): any {
  const xml = run(["codesign", "-d", "--entitlements", ":-", path]);
  const result = Bun.spawnSync(["plutil", "-convert", "json", "-o", "-", "-"], { stdin: Buffer.from(xml) });
  expect(result.exitCode).toBe(0);
  return JSON.parse(result.stdout.toString());
}

function uuids(path: string): string[] {
  const values = [...run(["xcrun", "dwarfdump", "--uuid", path]).matchAll(/UUID: ([A-F0-9-]+) \(([^)]+)\)/g)]
    .map((match) => `${match[1]} ${match[2]}`).sort();
  expect(values.length).toBeGreaterThan(0);
  return values;
}

test("packaging scripts parse without building", () => {
  run(["bash", "-n", "scripts/testflight.sh", "scripts/add-notification-extension.sh"]);
});

for (const args of [[], ["not-a-build"], ["4", "--unknown"], ["4", "--export", "extra"]]) {
  test(`invalid release arguments stop before building: ${args.join(" ")}`, () => {
    const result = Bun.spawnSync(["bash", "scripts/testflight.sh", ...args], { cwd: root });
    expect(result.exitCode).not.toBe(0);
    expect(result.stdout.toString()).not.toContain("work folder:");
  });
}

const archive = process.env.MUX_PUSH_ARCHIVE;
const exported = process.env.MUX_PUSH_EXPORTED_APP;

describe.skipIf(!archive)("actual store archive", () => {
  const archivePath = archive ?? "";
  const applications = join(archivePath, "Products/Applications");
  const app = () => join(applications, readdirSync(applications).find((name) => name.endsWith(".app"))!);
  const extension = () => join(app(), "PlugIns/MultiplexerNotifications.appex");

  test("embeds a notification service with matching version and shared session configuration", () => {
    const main = plist(join(app(), "Info.plist"));
    expect(existsSync(extension())).toBe(true);
    const ext = plist(join(extension(), "Info.plist"));
    expect(main.CFBundleIdentifier).toBe(bundle);
    expect(ext.CFBundleIdentifier).toBe(`${bundle}.notifications`);
    expect(ext.CFBundleVersion).toBe(main.CFBundleVersion);
    expect(ext.CFBundleShortVersionString).toBe(main.CFBundleShortVersionString);
    expect(ext.MinimumOSVersion).toBe(main.MinimumOSVersion);
    expect(ext.NSExtension).toEqual({
      NSExtensionPointIdentifier: "com.apple.usernotifications.service",
      NSExtensionPrincipalClass: "NotificationService",
    });
    expect(ext.MultiplexerAppGroup).toBe(group);
    expect(ext.MultiplexerKeychainGroup).toBe(keychain);
    expect(ext.MultiplexerSessionService).toBe(`${bundle}.session`);
    const properties = plist(join(archivePath, "Info.plist")).ApplicationProperties;
    expect(properties.CFBundleVersion).toBe(main.CFBundleVersion);
    expect(properties.CFBundleShortVersionString).toBe(main.CFBundleShortVersionString);
  });

  test("requests production push and shared app group/keychain access for export", () => {
    for (const [path, id] of [[app(), bundle], [extension(), `${bundle}.notifications`]]) {
      const ent = entitlements(path);
      expect(ent["application-identifier"]).toBe(`${team}.${id}`);
      expect(ent["com.apple.developer.team-identifier"]).toBe(team);
      expect(ent["get-task-allow"]).toBe(false);
      expect(ent["com.apple.security.application-groups"]).toEqual([group]);
      expect(ent["keychain-access-groups"]).toEqual([keychain]);
    }
    expect(entitlements(app())["aps-environment"]).toBe("production");
    expect(entitlements(app())["com.apple.developer.usernotifications.communication"]).toBe(true);
    expect(plist(join(app(), "Info.plist")).NSUserActivityTypes).toContain("INSendMessageIntent");
    run(["codesign", "--verify", "--deep", "--strict", app()]);
  });

  test("release native module contains remote notification registration", () => {
    const bytes = readFileSync(join(app(), "Frameworks/ExactModules.framework/ExactModules"));
    expect(bytes.includes(Buffer.from("registerForRemoteNotifications"))).toBe(true);
  });

  test("ships matching app, framework and extension symbols", () => {
    const main = plist(join(app(), "Info.plist"));
    const symbols = join(archivePath, "dSYMs");
    expect(uuids(join(symbols, `${app().split("/").pop()}.dSYM`)))
      .toEqual(uuids(join(app(), main.CFBundleExecutable)));
    for (const name of ["ExactModules", "ExactVideo"]) {
      expect(uuids(join(symbols, `${name}.framework.dSYM`)))
        .toEqual(uuids(join(app(), "Frameworks", `${name}.framework`, name)));
    }
    expect(uuids(join(symbols, "MultiplexerNotifications.appex.dSYM")))
      .toEqual(uuids(join(extension(), "MultiplexerNotifications")));
  });
});

describe.skipIf(!exported)("actual distribution export", () => {
  test("both signed products have distribution profiles granting their shared access", () => {
    const app = exported ?? "";
    const main = plist(join(app, "Info.plist"));
    for (const [path, id] of [[app, bundle], [join(app, "PlugIns/MultiplexerNotifications.appex"), `${bundle}.notifications`]]) {
      const info = plist(join(path, "Info.plist"));
      expect(info.CFBundleIdentifier).toBe(id);
      expect(info.CFBundleVersion).toBe(main.CFBundleVersion);
      expect(info.CFBundleShortVersionString).toBe(main.CFBundleShortVersionString);
      run(["codesign", "--verify", "--strict", path]);
      const ent = entitlements(path);
      const xml = run(["security", "cms", "-D", "-i", join(path, "embedded.mobileprovision")]);
      const result = Bun.spawnSync(["plutil", "-convert", "json", "-o", "-", "-"], { stdin: Buffer.from(xml) });
      expect(result.exitCode).toBe(0);
      const profile = JSON.parse(result.stdout.toString());
      for (const grants of [ent, profile.Entitlements]) {
        expect(grants["application-identifier"]).toBe(`${team}.${id}`);
        expect(grants["com.apple.developer.team-identifier"]).toBe(team);
        expect(grants["get-task-allow"]).toBe(false);
        expect(grants["com.apple.security.application-groups"]).toContain(group);
        expect(grants["keychain-access-groups"].some((value: string) =>
          value === keychain || (grants === profile.Entitlements && value === `${team}.*`))).toBe(true);
      }
      expect(profile.ProvisionedDevices).toBeUndefined();
      expect(profile.ProvisionsAllDevices).not.toBe(true);
      if (id === bundle) {
        expect(ent["aps-environment"]).toBe("production");
        expect(profile.Entitlements["aps-environment"]).toBe("production");
      }
    }
    run(["codesign", "--verify", "--deep", "--strict", app]);
  });
});
