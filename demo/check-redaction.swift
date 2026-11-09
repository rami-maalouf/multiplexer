import AVFoundation
import Vision
import Foundation

let args = CommandLine.arguments
guard args.count == 4 else { fatalError("usage: check-redaction <video> <manifest.json> <new-report.json>") }
let reportURL = URL(fileURLWithPath: args[3])
guard !FileManager.default.fileExists(atPath: reportURL.path) else { fatalError("report already exists") }
let manifest = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: args[2]))) as! [String: Any]
let scenes = manifest["scenes"] as! [[String: Any]]
var intervals: [(Double, Double)] = []
var cursor = 0.0
for scene in scenes {
    let duration = scene["duration"] as! Double
    if scene["state"] as! String != "approved-thread" { intervals.append((cursor, cursor + duration)) }
    cursor += duration
}
let asset = AVURLAsset(url: URL(fileURLWithPath: args[1]))
let track = try await asset.loadTracks(withMediaType: .video).first!
let size = try await track.load(.naturalSize)
let transform = try await track.load(.preferredTransform)
let frameDuration = try await track.load(.minFrameDuration)
let fps = Double(frameDuration.timescale) / Double(frameDuration.value)
guard size == CGSize(width: 1600, height: 1440), transform.isIdentity, [30.0, 60.0].contains(fps) else { fatalError("redaction regions require an upright 1600 x 1440 export at 30 or 60 fps") }
let reader = try AVAssetReader(asset: asset)
let output = AVAssetReaderTrackOutput(track: track, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
reader.add(output)
guard reader.startReading() else { throw reader.error! }
var frames = 0
var totalFrames = 0
var checks = 0
var findings: [[String: Any]] = []
while let sample = output.copyNextSampleBuffer() {
    totalFrames += 1
    let time = sample.presentationTimeStamp.seconds
    guard intervals.contains(where: { time >= $0.0 && time < $0.1 }), let buffer = sample.imageBuffer else { continue }
    frames += 1
    for (side, x) in [("mux", 164.0), ("beeper", 848.0)] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en-US", "ar-SA"]
        request.minimumTextHeight = 0.008
        request.regionOfInterest = CGRect(x: x / 1600, y: 48.0 / 1440, width: 588.0 / 1600, height: 1126.0 / 1440)
        try VNImageRequestHandler(cvPixelBuffer: buffer, orientation: .up).perform([request])
        checks += 1
        for observation in request.results ?? [] {
            guard let candidate = observation.topCandidates(1).first, candidate.confidence >= 0.3 else { continue }
            findings.append(["time": time, "side": side, "text": candidate.string, "confidence": candidate.confidence])
        }
    }
}
if let error = reader.error { throw error }
guard frames > 0, totalFrames == Int((cursor * fps).rounded()) else { fatalError("unexpected frame count or no masked frames were checked") }
let report: [String: Any] = ["fps": fps, "videoFrames": totalFrames, "maskedFrames": frames, "ocrChecks": checks, "findings": findings]
try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: reportURL, options: .withoutOverwriting)
print("videoFrames=\(totalFrames) maskedFrames=\(frames) ocrChecks=\(checks) findings=\(findings.count)")
if !findings.isEmpty { exit(1) }
