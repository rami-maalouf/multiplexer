import argparse
import json
import os
import re
import selectors
import signal
import subprocess
import time
from pathlib import Path


FRAME = re.compile(r"\((-?[\d.]+), (-?[\d.]+), ([\d.]+), ([\d.]+)\)$")


def invoke(tool, args):
    command = ["argent", "run", tool, "--json"]
    if tool == "flow-add-step":
        for key, value in args.items():
            command += [f"--{key}", str(value)]
    else:
        command += ["--args", json.dumps(args)]
    result = subprocess.run(command, capture_output=True, text=True, timeout=100)
    if result.returncode:
        raise RuntimeError(f"{tool}: {result.stderr.strip()}")
    return json.loads(result.stdout)


def target(tree, label):
    stack = []
    for line in tree.splitlines():
        depth = len(line) - len(line.lstrip())
        while stack and stack[-1][0] >= depth:
            stack.pop()
        match = FRAME.search(line)
        if match:
            frame = tuple(map(float, match.groups()))
            if f'"{label}"' in line:
                if "AXButton" not in line:
                    buttons = [parent for _, parent in stack if "AXButton" in parent]
                    if buttons:
                        frame = tuple(map(float, FRAME.search(buttons[-1]).groups()))
                x, y, w, h = frame
                if w > 0 and h > 0 and 0 <= x + w / 2 <= 1 and 0 <= y + h / 2 <= 1:
                    return {"x": x + w / 2, "y": y + h / 2}
            stack.append((depth, line))
    raise RuntimeError(f"no visible accessible target for {label}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("app", choices=["mux", "beeper"])
    parser.add_argument("output")
    parser.add_argument("--udid", required=True)
    parser.add_argument("--screen", required=True)
    parser.add_argument("--recorder", required=True)
    args = parser.parse_args()
    os.umask(0o077)
    output = Path(args.output).resolve()
    output.mkdir(mode=0o700, parents=True, exist_ok=False)
    bundle = "com.ramimaalouf.multiplexer" if args.app == "mux" else "com.automattic.beeper"
    label = "Wafaa" if args.app == "mux" else "Mama"
    inbox_selector = {"identifier": "title-button"} if args.app == "mux" else {"identifier": "InboxTitleMenuButton"}
    invoke("restart-app", {"udid": args.udid, "bundleId": bundle})
    for selector in (inbox_selector, {"text": label}):
        ready = invoke("await-ui-element", {"udid": args.udid, "condition": "visible", "selector": selector, "timeoutMs": 30000})
        if not ready.get("success"):
            raise RuntimeError("approved inbox and contact did not load")
    tree = invoke("describe", {"udid": args.udid})["description"]
    target(tree, label)
    if 'id="composer"' in tree or "AXTextView" in tree:
        raise RuntimeError("expected inbox, not a conversation")
    name = f"{args.app}-mom-{int(time.time())}"
    root = str(output)
    invoke("flow-start-recording", {"name": name, "project_root": root,
        "executionPrerequisite": f"{args.app} is already registered with Argent, signed in on the approved account, showing the inbox at the top; only non-writing navigation is authorized"})
    timeline = {"app": args.app, "flow": name, "source": str(output / "source.mov"), "events": []}
    process = subprocess.Popen([args.recorder, args.screen, str(output / "source.mov"), "180"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    epoch = None
    try:
        selector = selectors.DefaultSelector()
        selector.register(process.stdout, selectors.EVENT_READ)
        deadline = time.monotonic() + 45
        while epoch is None and time.monotonic() < deadline:
            if selector.select(timeout=1):
                line = process.stdout.readline()
                if line.startswith("RECORDING "):
                    epoch = float(line.split()[1])
                elif not line and process.poll() is not None:
                    raise RuntimeError(process.stderr.read())
        if epoch is None:
            raise RuntimeError("wired capture did not become ready")
        timeline["captureEpoch"] = epoch

        def mark(event):
            timeline["events"].append({"event": event, "time": time.time() - epoch})
            (output / "timeline.json").write_text(json.dumps(timeline, indent=2))
            print(event, flush=True)

        def record(command, payload):
            invoke("flow-add-echo", {"name": name, "project_root": root, "message": f"Approved non-writing demo step: {command}"})
            result = invoke("flow-add-step", {"name": name, "project_root": root,
                "command": command, "args": json.dumps({"udid": args.udid, **payload})})
            live = result.get("toolResult", {})
            if live.get("success") is False or (command == "run-sequence" and live.get("completed") != len(payload["steps"])):
                raise RuntimeError(f"{command} did not establish its condition: {live}")
            if "warning" in result.get("message", "").lower():
                print(result["message"], flush=True)
            return result

        def check(selector):
            record("await-ui-element", {"condition": "visible", "selector": selector, "timeoutMs": 10000})

        def swipe_sequence(first, second):
            record("run-sequence", {"steps": [
                {"tool": "gesture-swipe", "args": {"fromX": 0.5, "fromY": first, "toX": 0.5, "toY": second, "durationMs": 700, "momentum": False}},
                {"tool": "gesture-swipe", "args": {"fromX": 0.5, "fromY": second, "toX": 0.5, "toY": first, "durationMs": 700, "momentum": False}}
            ]})

        check(inbox_selector)
        mark("inbox-ready")
        time.sleep(1)
        mark("inbox-scroll-start")
        swipe_sequence(0.75, 0.40)
        mark("inbox-scroll-end")
        check(inbox_selector)
        tree = invoke("describe", {"udid": args.udid})["description"]
        point = target(tree, label)
        mark("open-start")
        record("gesture-tap", point)
        time.sleep(1)
        tree = invoke("describe", {"udid": args.udid})["description"]
        if args.app == "mux":
            check({"identifier": "composer"})
        else:
            if 'id="BeeperChatView.RootChatView"' not in tree or '"Reply on WhatsApp"' not in tree:
                raise RuntimeError("approved conversation navigation and composer were not exposed")
            check({"identifier": "BeeperChatView.RootChatView"})
            check({"text": "Reply on WhatsApp"})
        mark("thread-ready")
        time.sleep(1)
        mark("thread-scroll-start")
        swipe_sequence(0.40, 0.70)
        mark("thread-scroll-end")
        time.sleep(1)
        mark("back-start")
        record("gesture-swipe", {"fromX": 0, "fromY": 0.50, "toX": 0.8, "toY": 0.50, "durationMs": 700})
        check(inbox_selector)
        mark("back-end")
        time.sleep(2)
        mark("end")
        result = invoke("flow-finish-recording", {"name": name, "project_root": root})
        timeline["flowPath"] = result.get("savedTo")
        timeline["status"] = "captured-needs-review-and-replay"
    except Exception as error:
        timeline["status"] = "incomplete"
        timeline["error"] = str(error)
        raise
    finally:
        (output / "timeline.json").write_text(json.dumps(timeline, indent=2))
        if process.poll() is None:
            process.send_signal(signal.SIGINT)
        stdout, stderr = process.communicate(timeout=30)
        if process.returncode:
            raise RuntimeError(f"wired capture failed: {stderr}")
        print(stdout.strip(), flush=True)


if __name__ == "__main__":
    main()
