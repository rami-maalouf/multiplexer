import AVFoundation
import Foundation

/// A recorded voice message made ready to send, as WhatsApp and Element send one: Ogg Opus, mono
/// at 48 kHz, with its length and the waveform other clients draw. The WhatsApp bridge passes the
/// file on as it is and makes a voice note of it (`ptt`) only in a format WhatsApp plays as one:
/// Ogg Opus is WhatsApp's own. A recorder's AAC or WAV becomes Ogg Opus here.
public struct VoiceNote: Equatable, Sendable {
    /// The Ogg Opus file.
    public var file: URL
    /// In milliseconds.
    public var duration: Int
    /// In bytes.
    public var size: Int
    /// How loud each part of it is, from 0 to 1, from its start to its end: the bars a waveform draws.
    public var waveform: [Double]

    public init(file: URL, duration: Int, size: Int, waveform: [Double]) {
        self.file = file
        self.duration = duration
        self.size = size
        self.waveform = waveform
    }

    /// Encodes `recording` (any audio file AVFoundation reads: the recorder's AAC, a WAV) as
    /// `Voice message.ogg` in a new folder in `directory`, with a waveform of `bars` parts.
    public static func prepare(recording: URL, directory: URL, bars: Int = 64) async throws -> VoiceNote {
        let asset = AVURLAsset(url: recording)
        guard let track = try await asset.loadTracks(withMediaType: .audio).first else { throw VoiceNoteError.noAudio }
        let folder = directory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appendingPathComponent("Voice message.ogg")
        let encoded = try OggOpusEncoder.encode(asset: asset, track: track)
        try encoded.ogg.write(to: file, options: .atomic)
        return VoiceNote(file: file, duration: Int((Double(encoded.frames) / OggOpusEncoder.rate * 1000).rounded()),
                         size: encoded.ogg.count, waveform: waveform(encoded.levels, bars: bars))
    }

    /// `levels` (one a 20 ms frame) as `bars` parts, each its loudest frame, the loudest part 1.
    static func waveform(_ levels: [Float], bars: Int) -> [Double] {
        guard !levels.isEmpty, bars > 0 else { return [] }
        let parts = (0..<bars).map { bar -> Double in
            let from = bar * levels.count / bars, to = max(from + 1, (bar + 1) * levels.count / bars)
            return Double(levels[min(from, levels.count - 1)..<min(to, levels.count)].max() ?? 0)
        }
        let loudest = parts.max() ?? 0
        return loudest > 0 ? parts.map { ($0 / loudest * 1000).rounded() / 1000 } : parts
    }
}

public enum VoiceNoteError: Error, Equatable {
    /// The file has no sound to read.
    case noAudio
    /// AVFoundation could not read or encode it, in its words.
    case encoding(String)
}

/// PCM to Opus with AudioToolbox's encoder, into Ogg pages (RFC 7845), and the level of each frame.
enum OggOpusEncoder {
    static let rate = 48_000.0
    /// 20 ms, as WhatsApp's voice notes have it.
    static let frame = 960
    /// The encoder's delay, which a player skips (libopus's, as AudioToolbox reports it).
    static let defaultPreSkip = 312

    static func encode(asset: AVURLAsset, track: AVAssetTrack) throws -> (ogg: Data, frames: Int, levels: [Float]) {
        let reader = try AVAssetReader(asset: asset)
        // the reader resamples and mixes down: 48 kHz mono floats, whatever the recording was.
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: rate, AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 32, AVLinearPCMIsFloatKey: true, AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
        ])
        reader.add(output)
        guard reader.startReading() else { throw VoiceNoteError.encoding(reader.error.map(String.init(describing:)) ?? "the reader did not start") }

        guard let pcm = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: rate, channels: 1, interleaved: false) else {
            throw VoiceNoteError.encoding("no pcm format")
        }
        var description = AudioStreamBasicDescription(mSampleRate: rate, mFormatID: kAudioFormatOpus, mFormatFlags: 0, mBytesPerPacket: 0,
                                                      mFramesPerPacket: UInt32(frame), mBytesPerFrame: 0, mChannelsPerFrame: 1,
                                                      mBitsPerChannel: 0, mReserved: 0)
        guard let opus = AVAudioFormat(streamDescription: &description), let converter = AVAudioConverter(from: pcm, to: opus) else {
            throw VoiceNoteError.encoding("this device has no opus encoder")
        }
        // speech at WhatsApp's quality: clear, and about 4 KB a second.
        converter.bitRate = 32_000
        let preSkip = converter.primeInfo.leadingFrames > 0 ? Int(converter.primeInfo.leadingFrames) : defaultPreSkip

        var frames = 0, levels: [Float] = [], square: Float = 0, inFrame = 0, ended = false
        func measure(_ samples: UnsafeBufferPointer<Float>) {
            for s in samples {
                square += s * s
                inFrame += 1
                if inFrame == frame {
                    levels.append((square / Float(frame)).squareRoot())
                    square = 0
                    inFrame = 0
                }
            }
        }
        // the converter pulls the reader's buffers as it needs them.
        let input: AVAudioConverterInputBlock = { _, status in
            while !ended {
                guard let sample = output.copyNextSampleBuffer() else {
                    ended = true
                    break
                }
                let count = CMSampleBufferGetNumSamples(sample)
                guard count > 0, let buffer = AVAudioPCMBuffer(pcmFormat: pcm, frameCapacity: AVAudioFrameCount(count)) else { continue }
                buffer.frameLength = AVAudioFrameCount(count)
                guard CMSampleBufferCopyPCMDataIntoAudioBufferList(sample, at: 0, frameCount: Int32(count),
                                                                   into: buffer.mutableAudioBufferList) == noErr,
                      let channel = buffer.floatChannelData?[0] else { continue }
                measure(UnsafeBufferPointer(start: channel, count: count))
                frames += count
                status.pointee = .haveData
                return buffer
            }
            status.pointee = .endOfStream
            return nil
        }

        var packets: [Data] = []
        let out = AVAudioCompressedBuffer(format: opus, packetCapacity: 64, maximumPacketSize: max(converter.maximumOutputPacketSize, 1500))
        while true {
            var error: NSError?
            let status = converter.convert(to: out, error: &error, withInputFrom: input)
            if status == .error { throw VoiceNoteError.encoding(error.map(String.init(describing:)) ?? "the encoder failed") }
            if let descriptions = out.packetDescriptions {
                for i in 0..<Int(out.packetCount) {
                    let d = descriptions[i]
                    packets.append(Data(bytes: out.data.advanced(by: Int(d.mStartOffset)), count: Int(d.mDataByteSize)))
                }
            }
            if status == .endOfStream || (status == .inputRanDry && ended) { break }
        }
        if reader.status == .failed { throw VoiceNoteError.encoding(reader.error.map(String.init(describing:)) ?? "the reader failed") }
        guard frames > 0, !packets.isEmpty else { throw VoiceNoteError.noAudio }
        if inFrame > 0 { levels.append((square / Float(inFrame)).squareRoot()) }
        return (OggWriter.opus(packets, preSkip: preSkip, frames: frames), frames, levels)
    }
}

/// Opus packets in an Ogg stream (RFC 7845): the head, the tags, then the audio, about a second
/// a page. A page's granule position counts the samples at 48 kHz up to its last packet's end.
struct OggWriter {
    private(set) var data = Data()
    private let serial = UInt32.random(in: 1...UInt32.max)
    private var sequence: UInt32 = 0

    static func opus(_ packets: [Data], preSkip: Int, frames: Int) -> Data {
        var writer = OggWriter()
        var head = Data("OpusHead".utf8)
        head.append(1) // version
        head.append(1) // one channel
        head.append(le: UInt16(preSkip))
        head.append(le: UInt32(OggOpusEncoder.rate))
        head.append(le: UInt16(0)) // no gain
        head.append(0) // mono or stereo, no mapping table
        writer.page([head], granule: 0, flags: 0x02)
        var tags = Data("OpusTags".utf8)
        let vendor = Data("Multiplexer".utf8)
        tags.append(le: UInt32(vendor.count))
        tags.append(vendor)
        tags.append(le: UInt32(0))
        writer.page([tags], granule: 0, flags: 0)

        var page: [Data] = [], segments = 0, samples = 0
        for (i, packet) in packets.enumerated() {
            let needs = packet.count / 255 + 1
            if segments + needs > 255 || page.count == 50 {
                writer.page(page, granule: Int64(preSkip + samples), flags: 0)
                page = []
                segments = 0
            }
            page.append(packet)
            segments += needs
            samples += OggOpusEncoder.frame
            if i == packets.count - 1 {
                // the last page ends where the recording does: a player drops the encoder's padding.
                writer.page(page, granule: Int64(preSkip + min(frames, samples)), flags: 0x04)
            }
        }
        return writer.data
    }

    private mutating func page(_ packets: [Data], granule: Int64, flags: UInt8) {
        var lacing: [UInt8] = []
        for packet in packets {
            lacing += Array(repeating: 255, count: packet.count / 255)
            lacing.append(UInt8(packet.count % 255))
        }
        var page = Data("OggS".utf8)
        page.append(0) // version
        page.append(flags)
        page.append(le: UInt64(bitPattern: granule))
        page.append(le: serial)
        page.append(le: sequence)
        page.append(le: UInt32(0)) // the checksum, below
        page.append(UInt8(lacing.count))
        page.append(contentsOf: lacing)
        for packet in packets { page.append(packet) }
        let crc = OggWriter.crc(page)
        page.replaceSubrange(22..<26, with: withUnsafeBytes(of: crc.littleEndian) { Data($0) })
        data.append(page)
        sequence += 1
    }

    /// Ogg's CRC-32: polynomial 0x04C11DB7, not reflected, from 0.
    private static let table: [UInt32] = (0..<256).map { i in
        var r = UInt32(i) << 24
        for _ in 0..<8 { r = r & 0x8000_0000 != 0 ? (r << 1) ^ 0x04C1_1DB7 : r << 1 }
        return r
    }

    static func crc(_ data: Data) -> UInt32 {
        data.reduce(UInt32(0)) { crc, byte in (crc << 8) ^ table[Int(((crc >> 24) ^ UInt32(byte)) & 0xFF)] }
    }
}

private extension Data {
    mutating func append<T: FixedWidthInteger>(le value: T) {
        Swift.withUnsafeBytes(of: value.littleEndian) { append(contentsOf: $0) }
    }
}
