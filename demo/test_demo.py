import copy
import importlib.util
import json
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch


def load(name, filename):
    spec = importlib.util.spec_from_file_location(name, Path(__file__).with_name(filename))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


compose = load("compose", "compose-private.py")
take = load("take", "take-argent.py")


class DemoTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        for name in ("mux.mov", "beeper.mov"):
            (self.root / name).touch()
        self.manifest = {
            "mux": str(self.root / "mux.mov"), "beeper": str(self.root / "beeper.mov"),
            "scenes": [{"state": "inbox", "duration": 1, "mux": [0, 1], "beeper": [0, 1]}]
        }
        self.probe = patch.object(compose, "probe", return_value=(30, 1206, 2622))
        self.probe.start()
        self.addCleanup(self.probe.stop)

    def test_valid_reviewed_scene(self):
        self.assertEqual(len(compose.validate(self.manifest)), 2)

    def test_rejects_missing_or_unknown_privacy_state(self):
        for state in (None, "chat", "approved-thead"):
            with self.subTest(state=state):
                value = copy.deepcopy(self.manifest)
                value["scenes"].append({"state": state, "duration": 1, "mux": [1, 2], "beeper": [1, 2]})
                with self.assertRaises(ValueError):
                    compose.validate(value)

    def test_profile_and_recording_states_remain_private_without_opt_in(self):
        for state in ("profile", "voice-recording"):
            with self.subTest(state=state):
                value = copy.deepcopy(self.manifest)
                value["scenes"].append({"state": state, "duration": 1, "mux": [1, 2], "beeper": [1, 2]})
                self.assertEqual(len(compose.validate(value)), 2)
                self.assertIn("a0s1mask", compose.filters(value))
                self.assertNotIn("gblur", compose.filters(value, unredacted=True))

    def test_rejects_invalid_ranges_and_acceleration(self):
        for span in ([-1, 0], [1, 1], [0, 31], [0, 2], [0, float("nan")]):
            with self.subTest(span=span):
                value = copy.deepcopy(self.manifest)
                value["scenes"][0]["mux"] = span
                with self.assertRaises(ValueError):
                    compose.validate(value)

    def test_rejects_backwards_or_repeated_motion(self):
        self.manifest["scenes"].append({"state": "approved-thread", "duration": 1, "mux": [0.5, 1.5], "beeper": [1, 2]})
        with self.assertRaises(ValueError):
            compose.validate(self.manifest)

    def test_rejects_non_frame_aligned_budget(self):
        self.manifest["scenes"][0]["duration"] = 1.01
        with self.assertRaises(ValueError):
            compose.validate(self.manifest)

    def test_rejects_mismatched_dimensions(self):
        compose.probe.side_effect = [(30, 1206, 2622), (30, 1080, 1920)]
        with self.assertRaises(ValueError):
            compose.validate(self.manifest)

    def test_inbox_and_transition_cover_content_and_freeze_safe_header(self):
        for state in ("inbox", "transition"):
            self.manifest["scenes"][0]["state"] = state
            graph = compose.filters(self.manifest)
            self.assertEqual(graph.count("scale=16:64:flags=area"), 2)
            self.assertEqual(graph.count("crop=588:154:0:0"), 2)
            self.assertEqual(graph.count("crop=588:1126:0:154"), 2)
            self.assertEqual(graph.count("loop=loop=-1:size=1:start=0"), 2)
            self.assertEqual(graph.count("trim=end_frame=60"), 2)
            self.assertEqual(graph.count("concat=n=1:v=1:a=0,fps=60,settb=1/60,setpts=N"), 2)

    def test_unredacted_requires_explicit_opt_in_and_removes_all_masks(self):
        private = compose.filters(self.manifest)
        self.assertIn("gblur", private)
        self.assertIn("drawbox", private)
        unredacted = compose.filters(self.manifest, unredacted=True)
        for mask in ("gblur", "drawbox", "crop=588:154", "scale=16:64", "loop=loop=-1"):
            self.assertNotIn(mask, unredacted)

    def test_only_explicit_approved_thread_is_unmasked(self):
        self.manifest["scenes"].append({"state": "approved-thread", "duration": 1, "mux": [1, 2], "beeper": [1, 2]})
        graph = compose.filters(self.manifest)
        self.assertEqual(graph.count("scale=16:64:flags=area"), 2)
        self.assertNotIn("a0s1mask", graph)
        self.assertNotIn("a1s1mask", graph)

    def test_flick_pair_releases_with_momentum_and_leaves_time_to_settle(self):
        events = []
        with patch.object(take.time, "sleep", side_effect=lambda seconds: events.append(("wait", seconds))):
            take.flick_pair(lambda command, args: events.append((command, args)), 0.75, 0.40)
        self.assertEqual(events, [
            ("gesture-swipe", {"fromX": 0.5, "fromY": 0.75, "toX": 0.5, "toY": 0.40, "durationMs": 300, "momentum": True}),
            ("wait", 2),
            ("gesture-swipe", {"fromX": 0.5, "fromY": 0.40, "toX": 0.5, "toY": 0.75, "durationMs": 300, "momentum": True}),
            ("wait", 2)
        ])

    def test_profile_is_opened_and_closed_before_returning_to_the_composer(self):
        trees = iter([
            '  AXButton "Wafaa, Chat Info" id="chat-title"  (0.3, 0.08, 0.4, 0.10)',
            '  AXButton "Close" id="close-info"  (0.02, 0.08, 0.12, 0.05)'
        ])
        events = []
        with patch.object(take.time, "sleep", side_effect=lambda seconds: events.append(("wait", seconds))):
            take.profile_roundtrip(lambda command, args: events.append((command, args)), lambda: next(trees))
        self.assertEqual([command for command, _ in events], [
            "gesture-tap", "await-ui-element", "await-ui-element", "wait", "gesture-tap", "await-ui-element", "await-ui-element"
        ])
        self.assertAlmostEqual(events[0][1]["x"], 0.5)
        self.assertAlmostEqual(events[0][1]["y"], 0.13)
        self.assertEqual(events[1][1]["selector"], {"identifier": "info-name"})
        self.assertEqual(events[2][1]["selector"], {"identifier": "close-info"})
        self.assertEqual(events[3], ("wait", 1))
        self.assertAlmostEqual(events[4][1]["x"], 0.08)
        self.assertAlmostEqual(events[4][1]["y"], 0.105)
        self.assertEqual(events[5][1]["condition"], "hidden")
        self.assertEqual(events[5][1]["selector"], {"identifier": "close-info"})
        self.assertEqual(events[6][1]["selector"], {"identifier": "composer"})

    def test_profile_roundtrip_does_not_guess_a_missing_header_target(self):
        events = []
        with self.assertRaises(RuntimeError):
            take.profile_roundtrip(lambda command, args: events.append(command), lambda: 'AXButton "chat-title" id="voice-send"  (0.8, 0.9, 0.1, 0.05)')
        self.assertEqual(events, [])

    def test_profile_option_rejects_unverified_beeper_targets_before_any_device_actions(self):
        result = subprocess.run([
            "uv", "run", "python", str(Path(__file__).with_name("take-argent.py")), "beeper", str(self.root / "take"),
            "--udid", "unused", "--screen", "unused", "--recorder", "unused", "--profile"
        ], capture_output=True, text=True, timeout=30)
        self.assertEqual(result.returncode, 2)
        self.assertIn("Beeper's profile targets must be verified first", result.stderr)
        self.assertFalse((self.root / "take").exists())

    def test_voice_demo_drags_only_the_stop_control_and_cancels_without_sending(self):
        idle = 'AXButton "Record Voice Message" id="voice-record"  (0.85, 0.918, 0.12, 0.055)'
        active = 'AXButton "Stop Recording" id="voice-stop"  (0.851, 0.918, 0.119, 0.055)'
        cancel = 'AXButton "Cancel Recording" id="voice-cancel"  (0.03, 0.918, 0.119, 0.055)'
        for interrupted in (False, True):
            with self.subTest(interrupted=interrupted):
                trees = iter([idle, active, cancel])
                events = []
                def record(command, args):
                    events.append((command, args))
                    if interrupted and command == "gesture-custom":
                        raise RuntimeError("drag interrupted")
                if interrupted:
                    with self.assertRaisesRegex(RuntimeError, "drag interrupted"):
                        take.voice_roundtrip(record, lambda: next(trees))
                else:
                    take.voice_roundtrip(record, lambda: next(trees))
                taps = [args for command, args in events if command == "gesture-tap"]
                self.assertEqual(len(taps), 2)
                self.assertAlmostEqual(taps[-1]["x"], 0.0895)
                drag = next(args["events"] for command, args in events if command == "gesture-custom")
                self.assertEqual([event["type"] for event in drag], ["Down", "Move", "Up"])
                self.assertEqual(drag[0]["x"], drag[1]["x"])
                self.assertAlmostEqual(drag[-1]["x"], 0.83)
                self.assertEqual(events[-1][1]["selector"], {"identifier": "voice-record"})

    def test_failed_recorder_marks_the_take_rejected(self):
        output = self.root / "rejected"
        tree = 'AXButton "Wafaa"  (0.5, 0.15, 0.2, 0.1)\nAXButton "Back" id="back"  (0.02, 0.08, 0.12, 0.05)'
        def invoke(tool, args):
            return {"description": tree} if tool == "describe" else {"success": True, "toolResult": {"success": True}}
        with patch("sys.argv", ["take-argent.py", "mux", str(output), "--udid", "test", "--screen", "test", "--recorder", "test"]), patch.object(take, "invoke", side_effect=invoke), patch.object(take.subprocess, "Popen") as launch, patch.object(take.selectors, "DefaultSelector"), patch.object(take.time, "sleep"), patch.object(take.os, "umask"), patch("builtins.print"):
            process = launch.return_value
            process.stdout.readline.return_value = "RECORDING 1.0 1206x2622\n"
            process.poll.return_value = 0
            process.communicate.return_value = ("", "capture: reported drops")
            process.returncode = 1
            with self.assertRaisesRegex(RuntimeError, "wired capture failed"):
                take.main()
        saved = json.loads((output / "timeline.json").read_text())
        self.assertEqual(saved["status"], "rejected-capture")
        self.assertIn("reported drops", saved["error"])

    def test_back_target_is_a_unique_visible_top_left_accessible_button(self):
        tree = '  AXButton "Back, 12" id="thread-back"  (0.020, 0.075, 0.150, 0.050)\n  AXButton "Inbox"  (0.271, 0.915, 0.169, 0.050)'
        point = take.back_target(tree)
        self.assertAlmostEqual(point["x"], 0.095)
        self.assertAlmostEqual(point["y"], 0.100)
        for invalid in ('  AXButton "Inbox"  (0.271, 0.915, 0.169, 0.050)', tree + '\n  AXButton "Back"  (0.030, 0.075, 0.100, 0.050)'):
            with self.assertRaises(RuntimeError):
                take.back_target(invalid)

    def test_target_uses_fresh_parent_button_frame(self):
        tree = '  AXButton  (0.521, 0.151, 0.269, 0.121)\n    AXStaticText "Mama"  (0.556, 0.253, 0.199, 0.018)'
        point = take.target(tree, "Mama")
        self.assertAlmostEqual(point["x"], 0.6555)
        self.assertAlmostEqual(point["y"], 0.2115)
        with self.assertRaises(RuntimeError):
            take.target(tree, "Other chat")


class CaptureTests(unittest.TestCase):
    def test_writer_readiness_waits_instead_of_dropping_and_has_a_timeout(self):
        source = Path(__file__).with_name("capture-phone.swift").read_text().split("\nfinal class Recorder:")[0]
        harness = '''
var polls = 0
let delayed = try waitForMediaReadiness({ polls += 1; return polls == 4 })
precondition(delayed && polls == 4)
let immediate = try waitForMediaReadiness({ true })
precondition(!immediate)
do {
    _ = try waitForMediaReadiness({ false }, timeout: 0)
    fatalError("an unready writer must time out")
} catch let error as NSError {
    precondition(error.domain == "capture" && error.code == 6)
}
'''
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "readiness.swift"
            path.write_text(source + harness)
            result = subprocess.run(["swift", str(path)], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)


class RenderTests(unittest.TestCase):
    def test_default_export_preserves_each_captured_60hz_update(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source, frame = root / "source.mp4", root / "frame.png"
            subprocess.run(["ffmpeg", "-v", "error", "-f", "lavfi", "-i", "nullsrc=s=300x652:r=60,geq=lum='if(mod(N,2),235,16)':cb=128:cr=128", "-t", "1", "-c:v", "libx264", str(source)], check=True)
            subprocess.run(["ffmpeg", "-v", "error", "-f", "lavfi", "-i", "color=c=0x0c1118:size=1600x1440", "-frames:v", "1", str(frame)], check=True)
            path = root / "edit.json"
            path.write_text(json.dumps({"mux": str(source), "beeper": str(source), "scenes": [{"state": "inbox", "duration": 1, "mux": [0, 1], "beeper": [0, 1]}]}))
            output = root / "native.mp4"
            compose.render(path, frame, output)
            raw = subprocess.check_output(["ffmpeg", "-v", "error", "-i", str(output), "-vf", "crop=32:32:400:600,format=gray", "-fps_mode", "passthrough", "-f", "rawvideo", "-"])
            means = [sum(raw[i:i+1024])/1024 for i in range(0, len(raw), 1024)]
            self.assertEqual(len(means), 60)
            self.assertEqual(sum(abs(b-a) > 64 for a,b in zip(means, means[1:])), 59)
            unredacted = root / "unredacted.mp4"
            compose.render(path, frame, unredacted, unredacted=True)
            raw = subprocess.check_output(["ffmpeg", "-v", "error", "-i", str(unredacted), "-vf", "crop=32:32:400:120,format=gray", "-fps_mode", "passthrough", "-f", "rawvideo", "-"])
            means = [sum(raw[i:i+1024])/1024 for i in range(0, len(raw), 1024)]
            self.assertEqual(len(means), 60)
            self.assertEqual(sum(abs(b-a) > 64 for a,b in zip(means, means[1:])), 59)

    def test_real_ffmpeg_export_is_silent_aligned_and_non_destructive(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "source.mp4"
            frame = root / "frame.png"
            subprocess.run(["ffmpeg", "-v", "error", "-f", "lavfi", "-i", "testsrc2=size=300x652:rate=30", "-t", "1", "-c:v", "libx264", str(source)], check=True)
            subprocess.run(["ffmpeg", "-v", "error", "-f", "lavfi", "-i", "color=c=0x0c1118:size=1600x1440", "-frames:v", "1", str(frame)], check=True)
            manifest = {"mux": str(source), "beeper": str(source), "scenes": [{"state": "inbox", "duration": 1, "mux": [0, 1], "beeper": [0, 1]}]}
            path = root / "edit.json"
            path.write_text(json.dumps(manifest))
            output = root / "out.mp4"
            duration, width, height = compose.render(path, frame, output)
            self.assertAlmostEqual(duration, 1, places=2)
            self.assertEqual((width, height), (1600, 1440))
            streams = json.loads(subprocess.check_output(["ffprobe", "-v", "error", "-show_streams", "-of", "json", str(output)]))["streams"]
            self.assertEqual(len(streams), 1)
            self.assertEqual(streams[0]["codec_type"], "video")
            self.assertEqual(streams[0]["r_frame_rate"], "60/1")
            with self.assertRaises(ValueError):
                compose.render(path, frame, output)
            pixels = subprocess.check_output(["ffmpeg", "-v", "error", "-i", str(output), "-vf", "crop=572:74:172:120,format=gray", "-frames:v", "1", "-f", "rawvideo", "-"])
            self.assertLess(max(pixels), 5)


if __name__ == "__main__":
    unittest.main()
