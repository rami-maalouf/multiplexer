import argparse
import json
import math
import subprocess
from pathlib import Path


STATES = {"inbox", "transition", "approved-thread", "profile", "voice-recording"}
FPS = 60


def probe(source):
    result = subprocess.run([
        "ffprobe", "-v", "error", "-show_entries",
        "format=duration:stream=codec_type,width,height", "-of", "json", str(source)
    ], check=True, capture_output=True, text=True)
    info = json.loads(result.stdout)
    video = next(stream for stream in info["streams"] if stream["codec_type"] == "video")
    return float(info["format"]["duration"]), video["width"], video["height"]


def validate(manifest):
    if set(manifest) != {"mux", "beeper", "scenes"}:
        raise ValueError("manifest requires exactly mux, beeper, and scenes")
    sources = [Path(manifest[app]).resolve(strict=True) for app in ("mux", "beeper")]
    details = [probe(source) for source in sources]
    durations = [detail[0] for detail in details]
    if details[0][1:] != details[1][1:]:
        raise ValueError("both source recordings must have matching dimensions")
    if not manifest["scenes"] or manifest["scenes"][0].get("state") != "inbox":
        raise ValueError("begin with a reviewed inbox scene; the first source frame supplies its safe header")
    previous_ends = {"mux": 0, "beeper": 0}
    for scene in manifest["scenes"]:
        if set(scene) != {"state", "duration", "mux", "beeper"} or scene["state"] not in STATES:
            raise ValueError("each scene needs an explicit privacy state, duration, mux and beeper ranges")
        duration = scene["duration"]
        if type(duration) not in (int, float) or not math.isfinite(duration) or duration <= 0:
            raise ValueError("scene duration must be positive and finite")
        if abs(duration * FPS - round(duration * FPS)) > 0.000001:
            raise ValueError(f"scene budgets must align to whole output frames at {FPS} fps")
        for app, source_duration in zip(("mux", "beeper"), durations):
            span = scene[app]
            if not isinstance(span, list) or len(span) != 2 or not all(isinstance(t, (int, float)) and math.isfinite(t) for t in span):
                raise ValueError("source ranges must be two finite numbers")
            start, end = span
            if not 0 <= start < end <= source_duration:
                raise ValueError("scene lies outside its source")
            if start < previous_ends[app] - 0.000001:
                raise ValueError("source ranges must stay chronological without replaying app motion")
            previous_ends[app] = end
            if end - start > duration + 0.001:
                raise ValueError("scene exceeds its budget; do not accelerate app motion")
    return sources


def filters(manifest, unredacted=False):
    graph = []
    status_mask = "" if unredacted else ",drawbox=x=0:y=0:w=iw:h=90:color=black:t=fill"
    for index, app in enumerate(("mux", "beeper")):
        clips = []
        for number, scene in enumerate(manifest["scenes"]):
            label = f"a{index}s{number}"
            start, end = scene[app]
            duration = scene["duration"]
            graph.append(f"[{index}:v]trim=start={start}:end={end},setpts=PTS-STARTPTS,scale=588:1280,setsar=1{status_mask}[{label}base]")
            if unredacted or scene["state"] == "approved-thread":
                current = f"{label}base"
            else:
                top, height = 154, 1126
                graph.append(f"[{label}base]split=2[{label}clean][{label}private]")
                graph.append(f"[{label}private]crop=588:{height}:0:{top},scale=16:64:flags=area,scale=588:{height}:flags=bilinear,gblur=sigma=18,drawbox=x=0:y=0:w=iw:h=ih:color=black@0.35:t=fill[{label}mask]")
                graph.append(f"[{label}clean][{label}mask]overlay=x=0:y={top}[{label}hidden]")
                graph.append(f"[{index}:v]trim=start=0:end=0.05,setpts=PTS-STARTPTS,scale=588:1280,crop=588:154:0:0,loop=loop=-1:size=1:start=0,drawbox=x=0:y=0:w=iw:h=90:color=black:t=fill[{label}chrome]")
                graph.append(f"[{label}hidden][{label}chrome]overlay=x=0:y=0:shortest=1[{label}safe]")
                current = f"{label}safe"
            frames = round(duration * FPS)
            graph.append(f"[{current}]tpad=stop_mode=clone:stop_duration={duration},fps={FPS},trim=end_frame={frames},settb=1/{FPS},setpts=N,format=yuv420p[{label}]")
            clips.append(f"[{label}]")
        graph.append(f"{''.join(clips)}concat=n={len(clips)}:v=1:a=0,fps={FPS},settb=1/{FPS},setpts=N[{app}]")
    graph.append("[2:v]scale=1600:1440,setsar=1[frame]")
    graph.append("[frame][mux]overlay=x=164:y=112:shortest=1[left]")
    graph.append("[left][beeper]overlay=x=848:y=112:shortest=1,format=yuv420p[final]")
    return ";".join(graph)


def render(manifest_path, frame, output, unredacted=False):
    manifest = json.loads(Path(manifest_path).read_text())
    sources = validate(manifest)
    output = Path(output)
    if output.exists():
        raise ValueError("output already exists; choose a fresh path")
    if not Path(frame).is_file():
        raise ValueError("generate the labeled frame with demo-frame.swift first")
    command = ["ffmpeg", "-hide_banner", "-loglevel", "error", "-n"]
    for source in sources:
        command += ["-i", str(source)]
    command += ["-loop", "1", "-framerate", str(FPS), "-i", str(frame), "-filter_complex", filters(manifest, unredacted),
                "-map", "[final]", "-an", "-map_metadata", "-1", "-r", str(FPS), "-fps_mode", "cfr", "-c:v", "libx264",
                "-preset", "fast", "-crf", "18", "-movflags", "+faststart", "-t",
                str(sum(scene["duration"] for scene in manifest["scenes"])), str(output)]
    subprocess.run(command, check=True)
    return probe(output)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("manifest")
    parser.add_argument("frame")
    parser.add_argument("output")
    parser.add_argument("--unredacted", action="store_true", help="explicit local preview with all inbox content and status chrome visible")
    args = parser.parse_args()
    print(json.dumps({"duration_and_size": render(args.manifest, args.frame, args.output, args.unredacted)}))
