import { tmpdir } from 'node:os';
import { describe, expect, test } from "bun:test";
import { existsSync, readdirSync, readFileSync, rmSync, mkdtempSync, mkdirSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { packagePreview, previewIOS } from './preview-ios.ts';

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

function plist(path: string, key?: string): any {
  return JSON.parse(run(key ? ['plutil', '-extract', key, 'json', '-o', '-', path]
    : ["plutil", "-convert", "json", "-o", "-", path]));
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

test('invalid preview arguments stop before building', () => {
  for (const args of [[], ['--update'], ['5', '--upload']]) expect(() => previewIOS(args)).toThrow('usage:');
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
    const properties = plist(join(archivePath, "Info.plist"), 'ApplicationProperties');
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

  test('the preview ipa retains the production notification extension and sender-photo configuration', () => {
    const ipa = packagePreview(archivePath);
    try {
      const entries = run(['unzip', '-Z1', ipa]);
      const name = app().split('/').pop();
      expect(entries).toContain(`Payload/${name}/PlugIns/MultiplexerNotifications.appex/MultiplexerNotifications`);
      const xml = run(['unzip', '-p', ipa, `Payload/${name}/Info.plist`]);
      const result = Bun.spawnSync(['plutil', '-extract', 'NSUserActivityTypes', 'json', '-o', '-', '-'], { stdin: Buffer.from(xml) });
      expect(result.exitCode).toBe(0);
      expect(JSON.parse(result.stdout.toString())).toContain('INSendMessageIntent');
    } finally { rmSync(dirname(ipa), { recursive: true, force: true }); }
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
      const result = Bun.spawnSync(["plutil", "-extract", "Entitlements", "json", "-o", "-", "-"], { stdin: Buffer.from(xml) });
      expect(result.exitCode).toBe(0);
      const profileEntitlements = JSON.parse(result.stdout.toString());
      for (const grants of [ent, profileEntitlements]) {
        expect(grants["application-identifier"]).toBe(`${team}.${id}`);
        expect(grants["com.apple.developer.team-identifier"]).toBe(team);
        expect(grants["get-task-allow"]).toBe(false);
        expect(grants["com.apple.security.application-groups"]).toContain(group);
        expect(grants["keychain-access-groups"].some((value: string) =>
          value === keychain || (grants === profileEntitlements && value === `${team}.*`))).toBe(true);
      }
      const devices = Bun.spawnSync(["plutil", "-extract", "ProvisionedDevices", "json", "-o", "-", "-"], { stdin: Buffer.from(xml) });
      expect(devices.exitCode).not.toBe(0);
      const allDevices = Bun.spawnSync(["plutil", "-extract", "ProvisionsAllDevices", "json", "-o", "-", "-"], { stdin: Buffer.from(xml) });
      if (allDevices.exitCode === 0) expect(JSON.parse(allDevices.stdout.toString())).not.toBe(true);
      if (id === bundle) {
        expect(ent["aps-environment"]).toBe("production");
        expect(profileEntitlements["aps-environment"]).toBe("production");
        expect(ent['com.apple.developer.usernotifications.communication']).toBe(true);
        expect(profileEntitlements['com.apple.developer.usernotifications.communication']).toBe(true);
      }
    }
    run(["codesign", "--verify", "--deep", "--strict", app]);
  });
});

test('custom preview refuses a missing or mismatched runtime gateway before signing or packaging', () => {
  const work = mkdtempSync(join(tmpdir(), 'mux-preview-config-'));
  const prior = process.env.MUX_IOS_CONFIG;
  try {
    const bundle = 'org.example.chat';
    const team = 'ABCDE12345';
    const config = join(work, 'config.json');
    writeFileSync(config, JSON.stringify({ teamId: team, bundleId: bundle, pushGateway: 'https://push.example.org/_matrix/push/v1/notify' }));
    process.env.MUX_IOS_CONFIG = config;
    const app = join(work, 'Products/Applications/Mux.app');
    const ext = join(app, 'PlugIns/MultiplexerNotifications.appex');
    mkdirSync(ext, { recursive: true });
    const main = { CFBundleIdentifier: bundle, CFBundleVersion: '1', NSUserActivityTypes: ['INSendMessageIntent'] };
    writeFileSync(join(ext, 'Info.plist'), JSON.stringify({ ...main, CFBundleIdentifier: `${bundle}.notifications`, MultiplexerAppGroup: `group.${bundle}`, MultiplexerKeychainGroup: `${team}.${bundle}`, MultiplexerSessionService: `${bundle}.session` }));
    for (const gateway of [undefined, 'https://wrong.example.org/_matrix/push/v1/notify']) {
      writeFileSync(join(app, 'Info.plist'), JSON.stringify({ ...main, MultiplexerPushGateway: gateway }));
      expect(() => packagePreview(work)).toThrow('runtime configuration');
    }
  } finally {
    if (prior === undefined) delete process.env.MUX_IOS_CONFIG; else process.env.MUX_IOS_CONFIG = prior;
    rmSync(work, { recursive: true, force: true });
  }
});
