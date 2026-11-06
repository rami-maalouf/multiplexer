@testable import MatrixCore
import AVFoundation
import XCTest

/// Voice messages (B16, B17) as two test users (`scripts/test-matrix-core.sh` passes them), in
/// the test's own rooms, made on the first run.
final class VoiceTests: XCTestCase {
    private let voiceName = "Multiplexer voice test"
    private let receivedName = "Multiplexer voice test received"

    /// A recording (the phone's recorder writes AAC in a fragmented MP4, a drive's recorder WAV)
    /// goes as a voice message: Ogg Opus with the voice mark, its length and waveform, as the
    /// WhatsApp bridge needs to send a voice note. The other person sees a voice message with the
    /// same length and waveform, the list says "Voice message", and its sound downloads as the
    /// sender's bytes and plays on this device.
    func testAVoiceNoteReachesTheOtherWithItsLengthAndWaveform() async throws {
        let (homeserver, user, password, user2, password2) = try twoUsers()
        let owner = try await signIn(homeserver, user, password)
        let other = try await signIn(homeserver, user2, password2)
        let roomId = try await testRooms(owner, other, user2: user2)[voiceName]!
        _ = try await owner.messages(roomId: roomId, limit: 20)
        _ = try await other.messages(roomId: roomId, limit: 20)

        // both of the recorder's formats become the same kind of file. Each run's length is its own, so
        // the other person finds this run's message, not an earlier run's.
        let length = 3000 + 10 * Int.random(in: 1...49)
        let wav = try await VoiceNote.prepare(recording: try recording(seconds: 2.5, aac: false), directory: freshDirectory())
        let note = try await VoiceNote.prepare(recording: try recording(seconds: Double(length) / 1000, aac: true), directory: freshDirectory())
        for (prepared, length) in [(wav, 2500), (note, length)] {
            XCTAssertEqual(try Data(contentsOf: prepared.file).prefix(4), Data("OggS".utf8), "an ogg file")
            XCTAssertEqual(prepared.file.lastPathComponent, "Voice message.ogg")
            XCTAssertEqual(Double(prepared.duration), Double(length), accuracy: 30, "the recording's length")
            XCTAssertEqual(prepared.waveform.count, 64)
            XCTAssertEqual(prepared.waveform.max(), 1, "the loudest part is the top")
            XCTAssertLessThan(prepared.waveform.min() ?? 1, 0.6, "the quiet parts are lower")
            let decoded = try AVAudioFile(forReading: prepared.file)
            XCTAssertEqual(Double(decoded.length) / decoded.fileFormat.sampleRate * 1000, Double(length), accuracy: 40, "it decodes to its length")
        }

        // sent as a voice message: it shows at once, then the server has it.
        let id = try await owner.sendVoice(roomId: roomId, note: note)
        let echo = try XCTUnwrap(id, "the voice message did not show at once")
        let sent = try await message(owner, roomId, within: 30) { $0.id == echo && $0.sendState == .sent }
        XCTAssertEqual(sent.audio?.isVoice, true)

        // what the bridge reads: an m.audio with the voice mark, audio/ogg, the length and the waveform.
        let events = try await api("GET", ["rooms", roomId, "messages"], session: try other.savedSession(), query: ["dir": "b", "limit": "10"])
        let content = try XCTUnwrap((events["chunk"] as? [[String: Any]])?
            .first { ($0["sender"] as? String) == user && (($0["content"] as? [String: Any])?["msgtype"] as? String) == "m.audio" }?["content"]
            as? [String: Any], "no m.audio from the sender: \(events)")
        print("voice: the event's content without its url: \(content.filter { $0.key != "url" })")
        XCTAssertNotNil(content["org.matrix.msc3245.voice"], "the voice mark the bridge makes a voice note of")
        let info = try XCTUnwrap(content["info"] as? [String: Any])
        XCTAssertEqual(info["mimetype"] as? String, "audio/ogg")
        XCTAssertEqual(info["duration"] as? Int, note.duration, "milliseconds, as the bridge reads them")
        XCTAssertEqual(info["size"] as? Int, note.size)
        let extensible = try XCTUnwrap(content["org.matrix.msc1767.audio"] as? [String: Any])
        XCTAssertEqual((extensible["waveform"] as? [Int])?.count, 64)
        XCTAssertEqual(content["body"] as? String, "Voice message.ogg")

        // the other person: a voice message with its length and waveform, and the list's line. The
        // one this run sent, by its event: an earlier run's note has the same length and size (the
        // same recording), and the newest match can be that one while this one is on its way.
        XCTAssertFalse(sent.eventId.isEmpty, "the sent message has no event id")
        let received = try await message(other, roomId, within: 30) { $0.eventId == sent.eventId }
        let audio = try XCTUnwrap(received.audio)
        XCTAssertTrue(audio.isVoice)
        XCTAssertEqual(audio.duration, note.duration)
        XCTAssertEqual(audio.size, note.size)
        XCTAssertEqual(audio.mimetype, "audio/ogg")
        XCTAssertEqual(audio.waveform.count, 64)
        for (got, want) in zip(audio.waveform, note.waveform) { XCTAssertEqual(got, want, accuracy: 0.01, "the waveform comes through") }
        XCTAssertEqual(received.body, "", "no caption")
        XCTAssertNil(received.file)
        try await lastMessage(other, roomId, is: "Voice message")

        // its sound downloads once as the sender's bytes, and this device plays it.
        let directory = freshDirectory()
        let file = try await other.audioFile(roomId: roomId, messageId: received.id, directory: directory)
        XCTAssertEqual(try Data(contentsOf: file), try Data(contentsOf: note.file), "the sender's bytes")
        XCTAssertEqual(file.pathExtension, "ogg")
        let playable = try await AVURLAsset(url: file).load(.isPlayable)
        XCTAssertTrue(playable, "this device's player plays ogg opus")
        let shared = try await other.mediaFile(roomId: roomId, messageId: received.id, directory: freshDirectory())
        XCTAssertEqual(shared.lastPathComponent, "Voice message.ogg", "Share hands it over under its name")
    }

    /// A voice note as the WhatsApp bridge brings one (Ogg Opus, a waveform from 0 to 100, the
    /// length in milliseconds) and an audio file someone shared, as another client sends them.
    func testAVoiceNoteFromTheBridgeAndAnAudioFile() async throws {
        let (homeserver, user, password, user2, password2) = try twoUsers()
        let owner = try await signIn(homeserver, user, password)
        let other = try await signIn(homeserver, user2, password2)
        let roomId = try await testRooms(owner, other, user2: user2)[receivedName]!
        _ = try await owner.messages(roomId: roomId, limit: 20)

        let session = try other.savedSession()
        let note = try await VoiceNote.prepare(recording: try recording(seconds: 1.5, aac: false), directory: freshDirectory())
        let uri = try await upload(try Data(contentsOf: note.file), type: "audio/ogg", session: session)
        let waveform = [0, 25, 50, 100, 75, 10]
        // each run's length is its own, so this run's message is the one found.
        let ms = 1500 + Int.random(in: 1...999)
        _ = try await api("PUT", ["rooms", roomId, "send", "m.room.message", UUID().uuidString], [
            "msgtype": "m.audio", "body": "Voice message.ogg", "filename": "Voice message.ogg", "url": uri,
            "info": ["mimetype": "audio/ogg; codecs=opus", "size": note.size, "duration": ms],
            "org.matrix.msc1767.audio": ["duration": ms, "waveform": waveform], "org.matrix.msc3245.voice": [String: Any](),
        ], session: session)
        let voice = try await message(owner, roomId, within: 20) { $0.audio?.isVoice == true && $0.sender == user2 && $0.audio?.duration == ms }
        let audio = try XCTUnwrap(voice.audio)
        XCTAssertEqual(audio.size, note.size)
        XCTAssertEqual(audio.waveform, [0, 0.25, 0.5, 1, 0.75, 0.1], "the loudest part is the top")
        XCTAssertEqual((audio.fileName as NSString).pathExtension, "ogg")
        try await lastMessage(owner, roomId, is: "Voice message")
        let file = try await owner.audioFile(roomId: roomId, messageId: voice.id, directory: freshDirectory())
        XCTAssertEqual(try Data(contentsOf: file), try Data(contentsOf: note.file))

        // a shared audio file: no voice mark, no waveform; the list says "Audio".
        let song = try await VoiceNote.prepare(recording: try recording(seconds: 1, aac: false), directory: freshDirectory())
        let songUri = try await upload(try Data(contentsOf: song.file), type: "audio/mpeg", session: session)
        let title = "Song \(UUID().uuidString).mp3"
        let songMs = 1000 + Int.random(in: 1...999)
        _ = try await api("PUT", ["rooms", roomId, "send", "m.room.message", UUID().uuidString], [
            "msgtype": "m.audio", "body": title, "url": songUri, "info": ["mimetype": "audio/mpeg", "size": song.size, "duration": songMs],
        ], session: session)
        let shared = try await message(owner, roomId, within: 20) { $0.audio?.duration == songMs && $0.sender == user2 }
        XCTAssertEqual(shared.audio?.isVoice, false)
        XCTAssertEqual(shared.audio?.waveform, [])
        XCTAssertEqual(shared.audio.map { ($0.fileName as NSString).pathExtension }, "mp3")
        try await lastMessage(owner, roomId, is: "Audio")
    }

    // MARK: helpers

    /// A recording of `seconds`, louder and quieter in turns as speech is: a fragmented MP4 of AAC
    /// at 48 kHz, as the phone's recorder writes one, or a 16-bit WAV at 8 kHz, as a drive's does.
    private func recording(seconds: Double, aac: Bool) throws -> URL {
        let rate = aac ? 48_000.0 : 8_000.0
        let count = Int(seconds * rate)
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: rate, channels: 1, interleaved: false)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(count))!
        buffer.frameLength = AVAudioFrameCount(count)
        for i in 0..<count {
            let t = Double(i) / rate
            buffer.floatChannelData![0][i] = Float(sin(2 * .pi * 220 * t) * (0.1 + 0.8 * abs(sin(t * 3))))
        }
        let folder = freshDirectory()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        if !aac {
            let url = folder.appendingPathComponent("take.wav")
            let file = try AVAudioFile(forWriting: url, settings: [AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: rate, AVNumberOfChannelsKey: 1,
                                                                   AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false],
                                       commonFormat: .pcmFormatFloat32, interleaved: false)
            try file.write(from: buffer)
            return url
        }
        let url = folder.appendingPathComponent("take.m4a")
        let writer = try AVAssetWriter(outputURL: url, fileType: .m4a)
        writer.movieFragmentInterval = CMTime(seconds: 1, preferredTimescale: 600)
        let input = AVAssetWriterInput(mediaType: .audio, outputSettings: [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: rate, AVNumberOfChannelsKey: 1])
        writer.add(input)
        XCTAssertTrue(writer.startWriting())
        writer.startSession(atSourceTime: .zero)
        var at = 0
        while at < count {
            let n = min(4800, count - at)
            var description: CMAudioFormatDescription?
            CMAudioFormatDescriptionCreate(allocator: nil, asbd: format.streamDescription, layoutSize: 0, layout: nil,
                                           magicCookieSize: 0, magicCookie: nil, extensions: nil, formatDescriptionOut: &description)
            var block: CMBlockBuffer?
            CMBlockBufferCreateWithMemoryBlock(allocator: nil, memoryBlock: nil, blockLength: n * 4, blockAllocator: nil, customBlockSource: nil,
                                               offsetToData: 0, dataLength: n * 4, flags: 0, blockBufferOut: &block)
            CMBlockBufferReplaceDataBytes(with: buffer.floatChannelData![0].advanced(by: at), blockBuffer: block!, offsetIntoDestination: 0, dataLength: n * 4)
            var sample: CMSampleBuffer?
            CMAudioSampleBufferCreateReadyWithPacketDescriptions(allocator: nil, dataBuffer: block!, formatDescription: description!, sampleCount: n,
                                                                 presentationTimeStamp: CMTime(value: CMTimeValue(at), timescale: CMTimeScale(rate)),
                                                                 packetDescriptions: nil, sampleBufferOut: &sample)
            while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.005) }
            XCTAssertTrue(input.append(sample!))
            at += n
        }
        input.markAsFinished()
        let done = DispatchSemaphore(value: 0)
        writer.finishWriting { done.signal() }
        XCTAssertEqual(done.wait(timeout: .now() + 10), .success)
        XCTAssertEqual(writer.status, .completed, "\(String(describing: writer.error))")
        return url
    }

    private func twoUsers() throws -> (String, String, String, String, String) {
        let env = ProcessInfo.processInfo.environment
        guard let user = env["MATRIX_TEST_USER"], let password = env["MATRIX_TEST_PASSWORD"], !password.isEmpty,
              let user2 = env["MATRIX_TEST_USER2"], let password2 = env["MATRIX_TEST_PASSWORD2"], !password2.isEmpty else {
            throw XCTSkip("two test users are needed (MATRIX_TEST_USER2 and MATRIX_TEST_PASSWORD2)")
        }
        return (env["MATRIX_TEST_HOMESERVER"] ?? "matrix.org", user, password, user2, password2)
    }

    /// The test's rooms by name, made by the first user on the first run, with the second user in them.
    private func testRooms(_ owner: MatrixAccount, _ other: MatrixAccount, user2: String) async throws -> [String: String] {
        let session = try owner.savedSession(), otherSession = try other.savedSession()
        let known = try await owner.rooms()
        var ids: [String: String] = [:]
        for name in [voiceName, receivedName] {
            if let id = known.first(where: { $0.name == name })?.id {
                ids[name] = id
                continue
            }
            let created = try await api("POST", ["createRoom"], ["name": name, "preset": "private_chat", "invite": [user2]], session: session)
            let id = try XCTUnwrap(created["room_id"] as? String, "createRoom: \(created)")
            _ = try await api("POST", ["join", id], [:], session: otherSession)
            ids[name] = id
        }
        _ = try await other.rooms()
        let start = Date()
        while Date().timeIntervalSince(start) < 20 {
            let joined = try await owner.rooms().map(\.id)
            if ids.values.allSatisfy(joined.contains) { return ids }
            try await Task.sleep(nanoseconds: 300_000_000)
        }
        XCTFail("the test rooms did not reach the first user's list")
        throw CancellationError()
    }

    /// The last message the open chat shows that matches `match`, within `seconds`.
    private func message(_ account: MatrixAccount, _ roomId: String, within seconds: TimeInterval,
                         _ match: (Message) -> Bool) async throws -> Message {
        let start = Date()
        while true {
            if let found = try await account.messages(roomId: roomId, limit: 20).last(where: match) { return found }
            if Date().timeIntervalSince(start) > seconds {
                let last = try await account.messages(roomId: roomId, limit: 20).suffix(3)
                XCTFail("no such message within \(Int(seconds)) s; the last ones: \(last)")
                throw CancellationError()
            }
            try await Task.sleep(nanoseconds: 300_000_000)
        }
    }

    /// The chat list's line for the room once it is `text`, within 15 s: the list follows the timeline a moment later.
    private func lastMessage(_ account: MatrixAccount, _ roomId: String, is text: String) async throws {
        let start = Date()
        var shown = ""
        while Date().timeIntervalSince(start) < 15 {
            shown = try await account.rooms().first { $0.id == roomId }?.lastMessage ?? ""
            if shown == text { return }
            try await Task.sleep(nanoseconds: 300_000_000)
        }
        XCTAssertEqual(shown, text, "the chat list's line")
    }

    private func upload(_ data: Data, type: String, session: SavedSession) async throws -> String {
        var request = URLRequest(url: URL(string: session.homeserverUrl)!.appendingPathComponent("_matrix/media/v3/upload"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(type, forHTTPHeaderField: "Content-Type")
        let (uploaded, _) = try await URLSession.shared.upload(for: request, from: data)
        return try XCTUnwrap((try JSONSerialization.jsonObject(with: uploaded) as? [String: Any])?["content_uri"] as? String)
    }

    /// A client-server api call (`/_matrix/client/v3/...`); its JSON answer, an error's included.
    private func api(_ method: String, _ path: [String], _ body: Any? = nil, session: SavedSession,
                     query: [String: String] = [:]) async throws -> [String: Any] {
        var url = URL(string: session.homeserverUrl)!.appendingPathComponent("_matrix/client/v3")
        for part in path { url.appendPathComponent(part) }
        if !query.isEmpty {
            var parts = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            parts.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
            url = parts.url!
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, _) = try await URLSession.shared.data(for: request)
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    private func freshDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("matrix-core-\(UUID().uuidString)", isDirectory: true)
    }

    /// A new device of a test user, signed out at the test's end (TestDevices.swift).
    private func signIn(_ homeserver: String, _ user: String, _ password: String) async throws -> MatrixAccount {
        try await testAccount(homeserver, user, password)
    }
}
