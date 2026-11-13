# rebuild a constant-rate clip from a simulator screen recording, using each frame's own
# presentation time.
#
# simulator recordings (xcrun simctl io recordVideo) are variable-rate h264 whose decode
# timestamps go backwards mid-file. ffmpeg's `fps` filter and `-r` follow those timestamps,
# drop the frames that look "in the past" and hold the next one, so a smooth animation
# shows as a one-frame snap. this script decodes every frame in order, then places each one
# at its real presentation time.
#
# usage: uv run python -I scripts/retime-recording.py <source.mov> <out.mp4> <start-s> <duration-s>
#        [--width 402] [--crop w:h:x:y] [--fps 60]
import argparse
import os
import subprocess
import tempfile


def probe(src: str, entries: str) -> str:
    return subprocess.run(
        ["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries", entries, "-of", "csv=p=0", src],
        capture_output=True, text=True, check=True,
    ).stdout


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("source")
    p.add_argument("out")
    p.add_argument("start", type=float)
    p.add_argument("duration", type=float)
    p.add_argument("--width", type=int, default=402)
    p.add_argument("--crop", default="")
    p.add_argument("--fps", type=int, default=60)
    a = p.parse_args()

    num, den = map(int, probe(a.source, "stream=time_base").strip().split("/"))
    pts = [int(v.strip(",")) * num / den for v in probe(a.source, "frame=pts").split() if v.strip(",")]
    if any(b < x for x, b in zip(pts, pts[1:])):
        raise SystemExit("presentation times are not in order; this script cannot place the frames")

    with tempfile.TemporaryDirectory() as d:
        # the image writer reports every backwards decode timestamp; frames still come out in order.
        subprocess.run(
            ["ffmpeg", "-v", "fatal", "-y", "-i", a.source, "-vf", f"scale={a.width}:-2",
             "-fps_mode", "passthrough", os.path.join(d, "f_%05d.png")],
            check=True,
        )
        frames = sorted(f for f in os.listdir(d) if f.startswith("f_"))
        if len(frames) != len(pts):
            raise SystemExit(f"decoded {len(frames)} frames but the file lists {len(pts)}")
        listing = os.path.join(d, "frames.txt")
        with open(listing, "w") as c:
            for i, f in enumerate(frames):
                nxt = pts[i + 1] if i + 1 < len(pts) else pts[i] + 0.5
                c.write(f"file '{os.path.join(d, f)}'\nduration {max(nxt - pts[i], 0.0001):.6f}\n")
            c.write(f"file '{os.path.join(d, frames[-1])}'\n")
        chain = f"fps={a.fps},trim=start={a.start - pts[0]}:duration={a.duration},setpts=PTS-STARTPTS"
        if a.crop:
            chain += f",crop={a.crop}"
        subprocess.run(
            ["ffmpeg", "-v", "error", "-y", "-f", "concat", "-safe", "0", "-i", listing, "-vf", chain,
             "-pix_fmt", "yuv420p", "-c:v", "libx264", "-crf", "12", a.out],
            check=True,
        )
    print(a.out)


if __name__ == "__main__":
    main()
