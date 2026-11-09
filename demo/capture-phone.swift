import AVFoundation
import CoreMediaIO
import Foundation

func waitForMediaReadiness(_ ready: () -> Bool, timeout: TimeInterval = 2) throws -> Bool {
    let deadline = ProcessInfo.processInfo.systemUptime + timeout
    var waited = false
    while !ready() {
        guard ProcessInfo.processInfo.systemUptime < deadline else {
            throw NSError(domain: "capture", code: 6, userInfo: [NSLocalizedDescriptionKey: "video writer did not become ready before the backpressure deadline"])
        }
        waited = true
        Thread.sleep(forTimeInterval: 0.001)
    }
    return waited
}

final class Recorder: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    let url: URL
    let queue = DispatchQueue(label: "mux.screen.capture")
    var writer: AVAssetWriter?
    var track: AVAssetWriterInput?
    var startedAt: Date?
    var failure: Error?
    var frames = 0
    var writerWaits = 0
    var captureDrops = 0
    var timings: [[Double]] = []

    init(url: URL) { self.url = url }

    func captureOutput(_ output: AVCaptureOutput, didDrop sample: CMSampleBuffer, from connection: AVCaptureConnection) {
        captureDrops += 1
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sample: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard failure == nil else { return }
        let arrived = ProcessInfo.processInfo.systemUptime
        var written = false
        defer {
            timings.append([sample.presentationTimeStamp.seconds, arrived, written ? 1 : 0, ProcessInfo.processInfo.systemUptime - arrived])
        }
        do {
            if writer == nil {
                guard let format = sample.formatDescription else { return }
                let size = CMVideoFormatDescriptionGetDimensions(format)
                let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
                let track = AVAssetWriterInput(mediaType: .video, outputSettings: [
                    AVVideoCodecKey: AVVideoCodecType.h264,
                    AVVideoWidthKey: Int(size.width),
                    AVVideoHeightKey: Int(size.height),
                    AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 20_000_000]
                ])
                track.expectsMediaDataInRealTime = true
                writer.add(track)
                guard writer.startWriting() else { throw writer.error! }
                writer.startSession(atSourceTime: sample.presentationTimeStamp)
                self.writer = writer
                self.track = track
                startedAt = Date()
                print("RECORDING \(startedAt!.timeIntervalSince1970) \(size.width)x\(size.height)")
                fflush(stdout)
            }
            if let track {
                if try waitForMediaReadiness({ track.isReadyForMoreMediaData }) { writerWaits += 1 }
                guard track.append(sample) else { throw writer!.error! }
                frames += 1
                written = true
            }
        } catch { failure = error }
    }
}

func run() throws {
    let args = CommandLine.arguments
    guard args.count == 4, let duration = Double(args[3]), duration > 0, duration <= 600 else {
        throw NSError(domain: "capture", code: 1, userInfo: [NSLocalizedDescriptionKey: "usage: capture-phone <screen-device-name> <new-output.mov> <seconds:1-600>"])
    }
    let url = URL(fileURLWithPath: args[2])
    guard !FileManager.default.fileExists(atPath: url.path) else {
        throw NSError(domain: "capture", code: 2, userInfo: [NSLocalizedDescriptionKey: "output already exists"])
    }
    var property = CMIOObjectPropertyAddress(mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyAllowScreenCaptureDevices), mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal), mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain))
    var enabled: UInt32 = 1
    let status = CMIOObjectSetPropertyData(CMIOObjectID(kCMIOObjectSystemObject), &property, 0, nil, UInt32(MemoryLayout<UInt32>.size), &enabled)
    guard status == 0 else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
    var screen: AVCaptureDevice?
    for _ in 0..<10 {
        screen = AVCaptureDevice.DiscoverySession(deviceTypes: [.external], mediaType: nil, position: .unspecified).devices.first { $0.localizedName == args[1] && $0.hasMediaType(.muxed) }
        if screen != nil { break }
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.5))
    }
    guard let screen else { throw NSError(domain: "capture", code: 3, userInfo: [NSLocalizedDescriptionKey: "wired screen device not found; connect and unlock the iPhone"] ) }
    let session = AVCaptureSession()
    session.sessionPreset = .high
    let input = try AVCaptureDeviceInput(device: screen)
    session.addInput(input)
    for port in input.ports where port.mediaType != .video { port.isEnabled = false }
    let recorder = Recorder(url: url)
    let output = AVCaptureVideoDataOutput()
    output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange]
    output.alwaysDiscardsLateVideoFrames = false
    output.setSampleBufferDelegate(recorder, queue: recorder.queue)
    session.addOutput(output)
    session.startRunning()
    let deadline = Date(timeIntervalSinceNow: 30)
    var startedAt: Date?
    var failure: Error?
    repeat {
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
        recorder.queue.sync { startedAt = recorder.startedAt; failure = recorder.failure }
    } while startedAt == nil && failure == nil && Date() < deadline
    if let failure { session.stopRunning(); throw failure }
    guard let startedAt else { session.stopRunning(); throw NSError(domain: "capture", code: 4, userInfo: [NSLocalizedDescriptionKey: "no wired video frames arrived in 30 seconds"] ) }
    while Date().timeIntervalSince(startedAt) < duration && failure == nil && !interrupted {
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
        recorder.queue.sync { failure = recorder.failure }
    }
    output.setSampleBufferDelegate(nil, queue: nil)
    session.stopRunning()
    var finished = false
    recorder.queue.sync {
        recorder.track?.markAsFinished()
        recorder.writer?.finishWriting { recorder.queue.async { finished = true } }
    }
    let finishDeadline = Date(timeIntervalSinceNow: 15)
    var done = false
    repeat {
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
        recorder.queue.sync { done = finished }
    } while !done && Date() < finishDeadline
    if let error = failure ?? recorder.writer?.error { throw error }
    guard done, recorder.frames > 1 else { throw NSError(domain: "capture", code: 5, userInfo: [NSLocalizedDescriptionKey: "video finalization failed"] ) }
    let statistics: [String: Any] = [
        "received": recorder.timings.count,
        "written": recorder.frames,
        "writerSkipped": recorder.timings.count - recorder.frames,
        "writerWaits": recorder.writerWaits,
        "captureDropped": recorder.captureDrops,
        "recordingEpoch": startedAt.timeIntervalSince1970,
        "columns": ["sourcePTS", "arrivalUptime", "written", "callbackSeconds"],
        "samples": recorder.timings
    ]
    try JSONSerialization.data(withJSONObject: statistics, options: [.sortedKeys]).write(to: url.appendingPathExtension("capture.json"), options: .withoutOverwriting)
    guard recorder.frames == recorder.timings.count, recorder.captureDrops == 0 else {
        throw NSError(domain: "capture", code: 7, userInfo: [NSLocalizedDescriptionKey: "recording rejected: writer skipped \(recorder.timings.count - recorder.frames) frames; capture reported \(recorder.captureDrops) drops"])
    }
    print("SAVED \(url.path) frames=\(recorder.frames) received=\(recorder.timings.count) writerSkipped=\(recorder.timings.count - recorder.frames) writerWaits=\(recorder.writerWaits) captureDropped=\(recorder.captureDrops)")
}

var interrupted = false
signal(SIGINT) { _ in interrupted = true }

do { try run() } catch {
    fputs("capture: \(error.localizedDescription)\n", stderr)
    exit(1)
}
