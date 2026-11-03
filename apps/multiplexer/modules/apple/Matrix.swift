import Foundation

/// Answers app.ts's asks with MatrixCore (the core-*.swift files beside this one).
/// The session is in the Keychain; the account's store is a folder in the app's data.
final class Matrix: ExactModule {
    // the agent's data is a fresh scratch tree, so it keeps its session apart from the app's.
    private lazy var keychain = SessionKeychain(service: "com.ramimaalouf.multiplexer.session" + (context.agent ? ".agent" : ""))
    /// A session the server must still forget. Until it does, its device stays on the account.
    private lazy var pending = SessionKeychain(service: keychain.service, slot: "sign-out")
    private var signingOutPending = false
    private var stores: URL { context.data.appendingPathComponent("matrix", isDirectory: true) }
    /// The signed-in account, made once and shared by every ask; nil when signed out or not restored yet.
    private var account: Task<MatrixAccount, Error>?
    /// Topics that changed and app.ts has not heard of yet: a burst of changes becomes one ask.
    private var changedTopics: Set<String> = []
    /// Downloaded pictures, as `app:/cache/matrix-media/<name>` in the view.
    private var media: URL { context.cache.appendingPathComponent("matrix-media", isDirectory: true) }
    /// Thumbnails on their way, and ones that failed (not tried again until the next launch).
    private var downloading: Set<String> = [], failedDownloads: Set<String> = []
    /// Each photo's last thumbnail shown, by room and message: a photo this device sent keeps it
    /// while the server's copy, under a new name, comes from the cache.
    private var shownThumbnails: [String: String] = [:]
    /// Files downloaded to open, as `app:/cache/matrix-files/<folder>/<name>` in the view.
    private var files: URL { context.cache.appendingPathComponent("matrix-files", isDirectory: true) }

    override func call(_ request: [String: Any]) throws -> [String: Any] {
        switch request["op"] as? String {
        case "session":
            defer { signOutPending() }
            return ["userId": try stored()?.session.userId ?? ""]
        default: throw ExactNativeRefusal("matrix answers session")
        }
    }

    override func later(_ request: [String: Any], reply: ExactReply) {
        Task { @MainActor in
            do {
                switch request["op"] as? String {
                case "signIn":
                    reply.send(await signIn(server: request["server"] as? String ?? "", user: request["user"] as? String ?? "",
                                            password: request["password"] as? String ?? ""))
                case "rooms":
                    // every chat, each saying whether the list (inbox, archive or lowPriority) shows it
                    // under the filter menu's choice and the filter sheet's network ("": every network),
                    // the pinned ones' ids in their pin order, and the sheet's rows with their unread chats.
                    let started = Date(), account = try await signedIn()
                    let network = request["network"] as? String ?? ""
                    let inbox = try await account.inbox(filter: RoomFilter(rawValue: request["filter"] as? String ?? "") ?? .all,
                                                        list: ChatList(rawValue: request["list"] as? String ?? "") ?? .inbox,
                                                        network: network.isEmpty ? nil : network)
                    let rooms = inbox.chats
                    print("matrix: rooms answered \(rooms.count) chats in \(Int(Date().timeIntervalSince(started) * 1000)) ms")
                    reply.send(["rooms": rooms.map { room in
                        ["id": room.id, "name": room.name, "isDirect": room.isDirect, "lastMessage": room.lastMessage,
                         "lastSender": room.lastSenderName, "lastIsOwn": room.lastIsOwn, "lastTime": Double(room.lastTimestamp),
                         "unread": room.unreadCount, "network": room.network, "markedUnread": room.isMarkedUnread,
                         "oneToOne": room.isOneToOne, "listed": inbox.listed.contains(room.id),
                         "muted": room.isMuted, "mentions": room.unreadMentions, "lowPriority": room.isLowPriority,
                         "archived": room.isArchived,
                         "avatar": cached(room.avatarName, then: .rooms) {
                             _ = try await account.avatarFile(roomId: room.id, directory: self.media) }]
                    }, "pinned": inbox.pinned.map(\.id), "unread": inbox.unreadChats,
                       "archiveUnread": inbox.unreadChats(in: .archive), "lowPriorityUnread": inbox.unreadChats(in: .lowPriority),
                       "networks": inbox.networks.map { ["network": $0.network, "unread": $0.unread] }])
                case "pin", "unpin":
                    let roomId = request["roomId"] as? String ?? "", account = try await signedIn()
                    if request["op"] as? String == "pin" { try await account.pin(roomId: roomId) } else { try await account.unpin(roomId: roomId) }
                    reply.send(["ok": true])
                case "chat":
                    // a chat's long-press actions (MatrixCore's ChatActions.swift).
                    let roomId = request["roomId"] as? String ?? "", account = try await signedIn()
                    guard try sendsReadReceipts(account) else { throw ExactNativeRefusal("a drive changes only a test user's chats") }
                    switch request["action"] as? String {
                    case "read": try await account.markRead(roomId: roomId)
                    case "unread": try await account.setMarkedUnread(roomId: roomId, true)
                    case "mute": try await account.mute(roomId: roomId)
                    case "unmute": try await account.unmute(roomId: roomId)
                    case "lowPriority": try await account.setLowPriority(roomId: roomId, true)
                    case "inbox": try await account.setLowPriority(roomId: roomId, false)
                    case "archive": try await account.archive(roomId: roomId)
                    case "unarchive": try await account.unarchive(roomId: roomId)
                    case "delete": try await account.hide(roomId: roomId)
                    default: throw ExactNativeRefusal("chat's actions: read, unread, mute, unmute, lowPriority, inbox, archive, unarchive and delete")
                    }
                    reply.send(["ok": true])
                case "messages":
                    let roomId = request["roomId"] as? String ?? "", account = try await signedIn()
                    let messages = try await account.messages(roomId: roomId, limit: request["limit"] as? Int ?? 20)
                    let atStart = try await account.isAtStart(roomId: roomId)
                    reply.send(["atStart": atStart, "messages": messages.map {
                        ["id": $0.id, "sender": $0.sender, "senderName": $0.senderName, "body": $0.body,
                         "time": Double($0.timestamp), "isOwn": $0.isOwn, "state": $0.sendState.rawValue,
                         "waitingForKey": $0.waitingForKey, "isEdited": $0.isEdited,
                         "isDeleted": $0.isDeleted, "isEditable": $0.isEditable,
                         "isImage": $0.image != nil, "image": thumbnail(account, roomId: roomId, message: $0),
                         "imageWidth": $0.image?.width ?? 0, "imageHeight": $0.image?.height ?? 0,
                         "senderPicture": senderPicture(account, roomId: roomId, message: $0),
                         "reply": $0.reply.map { ["senderName": $0.senderName, "body": $0.body, "isOwn": $0.isOwn] } ?? [:],
                         "reactions": $0.reactions.map { ["key": $0.key, "count": $0.count, "isMine": $0.isMine] },
                         "file": $0.file.map { ["name": $0.name, "size": $0.size, "mimetype": $0.mimetype] } ?? [:],
                         "progress": $0.uploadProgress ?? -1]
                    }])
                case "markRead":
                    // the screen asks once the reader has seen the chat's newest message; a load does not.
                    let account = try await signedIn()
                    if try sendsReadReceipts(account) { try await account.markRead(roomId: request["roomId"] as? String ?? "") }
                    reply.send(["ok": true])
                case "draft":
                    // the chat's kept draft, as the view's composer holds one; "" for none.
                    let roomId = request["roomId"] as? String ?? ""
                    let draft = try await signedIn().draft(roomId: roomId)
                    reply.send(["room": roomId, "text": draft?.text ?? "", "replyTo": draft?.reply?.messageId ?? "",
                                "replyName": draft?.reply.map { $0.isOwn ? "You" : $0.senderName } ?? "",
                                "replyBody": draft?.reply?.body ?? ""])
                case "saveDraft":
                    let replyTo = request["replyTo"] as? String ?? ""
                    try await signedIn().saveDraft(roomId: request["roomId"] as? String ?? "", text: request["text"] as? String ?? "",
                                                   replyTo: replyTo.isEmpty ? nil : replyTo)
                    reply.send(["ok": true])
                case "older":
                    let roomId = request["roomId"] as? String ?? ""
                    try await signedIn().loadOlder(roomId: roomId)
                    // older messages the timeline already held bring no change of their own.
                    changed(.room(roomId))
                    reply.send(["ok": true])
                case "photo":
                    let file = try await signedIn().imageFile(roomId: request["roomId"] as? String ?? "",
                                                              messageId: request["messageId"] as? String ?? "", full: true, directory: media)
                    reply.send(["path": "app:/cache/matrix-media/\(file.lastPathComponent)"])
                case "send":
                    // the message shows in the chat at once; its state says how the sending goes.
                    let replyTo = request["replyTo"] as? String ?? ""
                    try await signedIn().send(roomId: request["roomId"] as? String ?? "", text: request["text"] as? String ?? "",
                                              replyTo: replyTo.isEmpty ? nil : replyTo)
                    reply.send(["ok": true])
                case "sendMedia":
                    // the photo or file shows in the chat at once; its state and progress say how the upload goes.
                    reply.send(["ok": try await sendMedia(request)])
                case "file":
                    let file = try await signedIn().fileContent(roomId: request["roomId"] as? String ?? "",
                                                                 messageId: request["messageId"] as? String ?? "", directory: files)
                    let folder = file.deletingLastPathComponent().lastPathComponent
                    reply.send(["path": "app:/cache/matrix-files/\(folder)/\(file.lastPathComponent)", "name": file.lastPathComponent])
                case "maxUploadSize":
                    reply.send(["bytes": try await signedIn().maxUploadSize()])
                case "react":
                    let account = try await signedIn()
                    guard try sendsReadReceipts(account) else { throw ExactNativeRefusal("a drive changes only a test user's messages") }
                    try await account.toggleReaction(roomId: request["roomId"] as? String ?? "",
                                                     messageId: request["messageId"] as? String ?? "", key: request["key"] as? String ?? "")
                    reply.send(["ok": true])
                case "edit", "deleteMessage", "forward", "resetEmojis":
                    // a held message's actions (MatrixCore's MessageActions.swift); a drive makes them
                    // only as a test user, as it reacts.
                    try await messageAction(request)
                    reply.send(["ok": true])
                case "media":
                    // a photo's or file's original, under its sender's name, for the share sheet.
                    let file = try await signedIn().mediaFile(roomId: request["roomId"] as? String ?? "",
                                                              messageId: request["messageId"] as? String ?? "", directory: files)
                    let folder = file.deletingLastPathComponent().lastPathComponent
                    reply.send(["path": "app:/cache/matrix-files/\(folder)/\(file.lastPathComponent)", "name": file.lastPathComponent])
                case "emojis":
                    reply.send(["emojis": try await signedIn().frequentEmojis()])
                case "discard":
                    try await signedIn().discard(roomId: request["roomId"] as? String ?? "", messageId: request["messageId"] as? String ?? "")
                    reply.send(["ok": true])
                case "retry":
                    try await signedIn().retry(roomId: request["roomId"] as? String ?? "", messageId: request["messageId"] as? String ?? "")
                    reply.send(["ok": true])
                case "signOut":
                    try await signOut()
                    reply.send(["ok": true])
                default:
                    reply.fail("matrix answers signIn, rooms, pin, unpin, chat, messages, markRead, draft, saveDraft, older, photo, send, sendMedia, file, maxUploadSize, react, edit, deleteMessage, forward, media, emojis, resetEmojis, retry, discard and signOut")
                }
            } catch {
                reply.fail(String(describing: error))
            }
        }
    }

    /// The Keychain's session if its store is still there. A reinstall keeps the Keychain
    /// but not the store, and a session without its store has lost its encryption keys:
    /// it waits to be signed out on the server, and the app opens signed out.
    private func stored() throws -> StoredSession? {
        guard let stored = try keychain.read() else { return nil }
        if FileManager.default.fileExists(atPath: stores.appendingPathComponent(stored.store).path) { return stored }
        try pending.write(stored)
        try keychain.delete()
        return nil
    }

    /// Signs the pending session out on the server in the background. If the server cannot
    /// be reached, the session stays pending for the next launch.
    private func signOutPending() {
        guard !signingOutPending, let stale = try? pending.read() else { return }
        signingOutPending = true
        let scratch = context.temporary.appendingPathComponent("matrix-sign-out-\(UUID().uuidString)", isDirectory: true)
        Task { @MainActor in
            if await MatrixAccount.signOutOnServer(stale.session, scratchDirectory: scratch) {
                try? pending.delete()
                print("matrix: signed out a session whose store was gone")
            }
            signingOutPending = false
        }
    }

    /// A refusal is a reply: `problem` names it for app.ts, which says it to the person.
    @MainActor private func signIn(server: String, user: String, password: String) async -> [String: Any] {
        account = nil
        shownThumbnails = [:]
        try? FileManager.default.removeItem(at: stores)
        let store = UUID().uuidString
        do {
            let signedIn = try await MatrixAccount.signIn(homeserver: server, user: user, password: password,
                                                          deviceName: context.agent ? "Multiplexer test" : "Multiplexer",
                                                          storeDirectory: stores.appendingPathComponent(store))
            do {
                try keychain.write(StoredSession(session: try signedIn.savedSession(), store: store))
            } catch {
                // a session this device cannot keep must not stay on the server.
                try? await signedIn.signOut()
                throw error
            }
            tellChanges(signedIn)
            account = Task { signedIn }
            return ["ok": true, "problem": "", "detail": ""]
        } catch {
            try? FileManager.default.removeItem(at: stores)
            let problem: String
            switch error as? SignInError {
            case .wrongPassword?: problem = "wrong-password"
            case .serverNotFound?: problem = "server-not-found"
            case .serverNotSupported?: problem = "server-not-supported"
            case .rateLimited?: problem = "rate-limited"
            case .other?, nil: problem = "other"
            }
            return ["ok": false, "problem": problem, "detail": String(describing: error)]
        }
    }

    @MainActor private func signedIn() async throws -> MatrixAccount {
        if let account { return try await account.value }
        guard let stored = try stored() else { throw ExactNativeRefusal("signed out") }
        let restoring = Task { try await MatrixAccount.restore(stored.session, storeDirectory: stores.appendingPathComponent(stored.store)) }
        account = restoring
        do {
            let restored = try await restoring.value
            tellChanges(restored)
            return restored
        } catch {
            account = nil
            throw error
        }
    }

    /// Read receipts go out, except in a drive on an account that is not a test user: a drive
    /// on Rami's real account must never mark a chat read (AGENTS.md, the safety rule), and
    /// with the WhatsApp bridge a receipt also marks the chat read in WhatsApp. A chat's
    /// actions (mute, archive, ...) follow the same rule.
    private func sendsReadReceipts(_ account: MatrixAccount) throws -> Bool {
        if !context.agent { return true }
        return try account.userId.hasPrefix("@test")
    }

    /// Edits or deletes your own message, forwards a message to other chats, or forgets the
    /// frequent emojis. A drive does these, and reacts, only as a test user (`sendsReadReceipts`).
    @MainActor private func messageAction(_ request: [String: Any]) async throws {
        let account = try await signedIn()
        guard try sendsReadReceipts(account) else { throw ExactNativeRefusal("a drive changes only a test user's messages") }
        let roomId = request["roomId"] as? String ?? "", messageId = request["messageId"] as? String ?? ""
        switch request["op"] as? String {
        case "edit": try await account.edit(roomId: roomId, messageId: messageId, text: request["text"] as? String ?? "")
        case "deleteMessage": try await account.delete(roomId: roomId, messageId: messageId)
        case "forward":
            for target in request["to"] as? [String] ?? [] { try await account.forward(roomId: roomId, messageId: messageId, to: target) }
        default: try await account.resetFrequentEmojis()
        }
    }

    /// A photo message's thumbnail as an `app:/` path once it is here (see `cached`); until then
    /// the one it showed before, if any.
    @MainActor private func thumbnail(_ account: MatrixAccount, roomId: String, message: Message) -> String {
        let key = "\(roomId)/\(message.id)"
        let path = cached(message.image?.thumbnailName ?? "", then: .room(roomId)) {
            _ = try await account.imageFile(roomId: roomId, messageId: message.id, full: false, directory: self.media)
        }
        if path.isEmpty { return message.image == nil ? "" : shownThumbnails[key] ?? "" }
        shownThumbnails[key] = path
        return path
    }

    /// Puts a picked photo or file, which app.ts prepared under `app:/tmp`, in the room's send queue.
    @MainActor private func sendMedia(_ request: [String: Any]) async throws -> Bool {
        func int(_ value: Any?) -> Int { (value as? NSNumber)?.intValue ?? 0 }
        guard let file = appFile(request["path"] as? String ?? "") else { throw ExactNativeRefusal("sendMedia takes an app:/tmp path") }
        let small = request["thumbnail"] as? [String: Any]
        let thumbnail = small.flatMap { t in appFile(t["path"] as? String ?? "").map {
            Attachment.Thumbnail(file: $0, mimetype: t["mimetype"] as? String ?? "image/jpeg", size: int(t["size"]),
                                 width: int(t["width"]), height: int(t["height"]))
        } }
        let attachment = Attachment(file: file, name: request["name"] as? String, mimetype: request["mimetype"] as? String ?? "application/octet-stream",
                                    size: int(request["size"]),
                                    kind: request["photo"] as? Bool == true ? .photo(width: int(request["width"]), height: int(request["height"])) : .file,
                                    thumbnail: thumbnail)
        let caption = request["caption"] as? String ?? "", replyTo = request["replyTo"] as? String ?? ""
        let roomId = request["roomId"] as? String ?? ""
        let id = try await signedIn().sendAttachment(roomId: roomId, attachment: attachment,
                                                     caption: caption.isEmpty ? nil : caption, replyTo: replyTo.isEmpty ? nil : replyTo)
        // the photo shows in the chat from its own thumbnail at once, before the send queue's copy is read.
        if let id, attachment.kind != .file, let shown = (small?["path"] as? String) ?? (request["path"] as? String) {
            shownThumbnails["\(roomId)/\(id)"] = shown
            changed(.room(roomId))
        }
        return true
    }

    /// The file an `app:/tmp/…`, `app:/cache/…` or `app:/data/…` path names in this module's folders.
    private func appFile(_ path: String) -> URL? {
        let roots = [("app:/tmp/", context.temporary), ("app:/cache/", context.cache), ("app:/data/", context.data)]
        guard let (prefix, root) = roots.first(where: { path.hasPrefix($0.0) }) else { return nil }
        let rest = path.dropFirst(prefix.count).split(separator: "/").map(String.init)
        guard !rest.isEmpty, !rest.contains(where: { $0 == "." || $0 == ".." }) else { return nil }
        return rest.reduce(root) { $0.appendingPathComponent($1) }
    }

    /// A sender's picture as an `app:/` path once it is here (see `cached`).
    @MainActor private func senderPicture(_ account: MatrixAccount, roomId: String, message: Message) -> String {
        let url = message.senderPicture
        return cached(message.senderPictureName, then: .room(roomId)) {
            _ = try await account.pictureFile(url: url, directory: self.media)
        }
    }

    /// A downloaded picture's `app:/` path once its file is here. Until then "": `fetch`
    /// starts (once), and when it ends app.ts is told `change`, so it asks again.
    @MainActor private func cached(_ name: String, then change: MatrixChange, fetch: @escaping () async throws -> Void) -> String {
        guard !name.isEmpty else { return "" }
        if FileManager.default.fileExists(atPath: media.appendingPathComponent(name).path) { return "app:/cache/matrix-media/\(name)" }
        guard !failedDownloads.contains(name), downloading.insert(name).inserted else { return "" }
        Task { @MainActor in
            do {
                try await fetch()
                changed(change)
            } catch {
                failedDownloads.insert(name)
            }
            downloading.remove(name)
        }
        return ""
    }

    /// Passes the account's changes to app.ts, as the topics its sources watch:
    /// `rooms`, and `thread:<room id>` for an open chat.
    private func tellChanges(_ account: MatrixAccount) {
        account.onChange { [weak self] change in
            Task { @MainActor in self?.changed(change) }
        }
    }

    private func changed(_ change: MatrixChange) {
        if changedTopics.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                guard let self else { return }
                let topics = changedTopics
                changedTopics = []
                topics.forEach(context.changed)
            }
        }
        switch change {
        case .rooms: changedTopics.insert("rooms")
        case .room(let roomId): changedTopics.insert("thread:\(roomId)")
        }
    }

    /// Asks the server to forget this device, then forgets the session here. If the server
    /// could not be reached, the session waits to be signed out there later.
    @MainActor private func signOut() async throws {
        let stored = try keychain.read()
        var forgotten = false
        if let signedIn = try? await signedIn() { forgotten = (try? await signedIn.signOut()) != nil }
        account = nil
        if !forgotten, let stored { try pending.write(stored) }
        try keychain.delete()
        try? FileManager.default.removeItem(at: stores)
        try? FileManager.default.removeItem(at: media)
        try? FileManager.default.removeItem(at: files)
        shownThumbnails = [:]
        if !forgotten { signOutPending() }
    }
}
let exactModule: ExactModule.Type = Matrix.self
