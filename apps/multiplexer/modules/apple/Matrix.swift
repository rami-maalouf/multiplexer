import Foundation

/// Answers app.ts's asks with MatrixCore (the core-*.swift files beside this one).
/// The session is in the Keychain; the account's store is a folder in the app's data.
final class Matrix: ExactModule {
    // the agent's data is a fresh scratch tree, so it keeps its session apart from the app's.
    lazy var keychain = SessionKeychain(service: "com.ramimaalouf.multiplexer.session" + (context.agent ? ".agent" : ""))
    /// A session the server must still forget. Until it does, its device stays on the account.
    private lazy var pending = SessionKeychain(service: keychain.service, slot: "sign-out")
    private var signingOutPending = false
    private var stores: URL { context.data.appendingPathComponent("matrix", isDirectory: true) }
    /// The signed-in account, made once and shared by every ask; nil when signed out or not restored yet.
    private var account: Task<MatrixAccount, Error>?
    /// Topics that changed and app.ts has not heard of yet: a burst of changes becomes one ask.
    private var changedTopics: Set<String> = []
    /// Downloaded pictures, as `app:/cache/matrix-media/<name>` in the view.
    var media: URL { context.cache.appendingPathComponent("matrix-media", isDirectory: true) }
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
                    // a community (a space's id) narrows it instead of a network.
                    let started = Date(), account = try await signedIn()
                    let network = request["network"] as? String ?? "", chosen = request["community"] as? String ?? ""
                    let filter = RoomFilter(rawValue: request["filter"] as? String ?? "") ?? .all
                    // Reminders is not a list a chat is in: it shows the chats with a reminder, from every list.
                    let all = request["list"] as? String == "reminders"
                        ? try await account.reminderList(filter: filter)
                        : try await account.inbox(filter: filter, list: ChatList(rawValue: request["list"] as? String ?? "") ?? .inbox)
                    let communities = await account.communities(among: all.chats)
                    let community = communities.first { $0.id == chosen }
                    let inbox = community != nil ? all.on(community: community) : all.on(network: network.isEmpty ? nil : network)
                    let rooms = inbox.chats
                    print("matrix: rooms answered \(rooms.count) chats in \(Int(Date().timeIntervalSince(started) * 1000)) ms")
                    reply.send(["rooms": rooms.map { roomRecord($0, listed: inbox.listed.contains($0.id), account, topic: "rooms") },
                       "pinned": inbox.pinned.map(\.id), "unread": inbox.unreadChats,
                       "archiveUnread": inbox.unreadChats(in: .archive), "lowPriorityUnread": inbox.unreadChats(in: .lowPriority),
                       "reminders": rooms.filter { !$0.isHidden && $0.foldedInto == nil && $0.reminderAt != nil }.count,
                       "networks": inbox.networks.map { ["network": $0.network, "unread": $0.unread] },
                       "communities": inbox.counts(of: communities).map { c in
                           ["id": c.id, "name": c.name, "unread": c.unread,
                            "avatar": cached(c.avatarName, topic: "rooms") { _ = try await account.avatarFile(roomId: c.id, directory: self.media) }] }])
                case "pin", "unpin":
                    // a merged chat pins or unpins each of its rooms.
                    let chatId = request["roomId"] as? String ?? "", account = try await signedIn()
                    for roomId in await account.roomsOf(chatId) {
                        if request["op"] as? String == "pin" { try await account.pin(roomId: roomId) } else { try await account.unpin(roomId: roomId) }
                    }
                    reply.send(["ok": true])
                case "merge", "unmerge":
                    // Merge Chats (MatrixCore's Merges.swift): kept in the account's data.
                    let account = try await signedIn()
                    guard try sendsReadReceipts(account) else { throw ExactNativeRefusal("a drive changes only a test user's chats") }
                    if request["op"] as? String == "merge" {
                        let id = try await account.merge(rooms: request["rooms"] as? [String] ?? [], name: request["name"] as? String ?? "",
                                                         defaultRoom: request["defaultRoom"] as? String ?? "")
                        reply.send(["ok": true, "id": id])
                    } else {
                        try await account.unmerge(request["id"] as? String ?? "")
                        reply.send(["ok": true, "id": ""])
                    }
                case "chat", "chats":
                    // a chat's long-press actions, or select chats' on several (matrixcore's chatactions.swift).
                    // a merged chat's action acts on each of its rooms; its reminder is on the room it opens.
                    let account = try await signedIn()
                    guard try sendsReadReceipts(account) else { throw ExactNativeRefusal("a drive changes only a test user's chats") }
                    let action = request["action"] as? String ?? "", roomId = request["roomId"] as? String ?? ""
                    switch action {
                    case "clearReminder" where request["op"] as? String == "chat":
                        for id in await account.roomsOf(roomId) { try await account.clearReminder(roomId: id) }
                    case "remind" where request["op"] as? String == "chat":
                        // Remind Me: `when` is "tomorrow", "monday" or a picked time without a zone, as Send Later's.
                        guard let when = ScheduledMessage.date(for: request["when"] as? String ?? ""), when > Date().addingTimeInterval(5) else {
                            reply.send(["ok": false, "at": 0, "problem": "past"])
                            return
                        }
                        let target = try await account.rooms().first { $0.id == roomId }?.opensRoom ?? roomId
                        try await account.setReminder(roomId: target, at: when)
                        reply.send(["ok": true, "at": (when.timeIntervalSince1970 * 1000).rounded(), "problem": ""])
                        return
                    default:
                        guard let change = MatrixAccount.ChatChange(rawValue: action) else {
                            throw ExactNativeRefusal("a chat's actions: \(MatrixAccount.ChatChange.allCases.map(\.rawValue).joined(separator: ", ")), and for one chat remind and clearReminder")
                        }
                        let chosen = request["op"] as? String == "chats" ? request["roomIds"] as? [String] ?? [] : [roomId]
                        var rooms: [String] = []
                        for id in chosen { rooms += await account.roomsOf(id) }
                        if rooms.count == 1 { try await account.change(roomId: rooms[0], change) } else { try await account.change(roomIds: rooms, change) }
                    }
                    reply.send(["ok": true])
                case "spaceChoices":
                    let account = try await signedIn(), roomId = request["roomId"] as? String ?? ""
                    let spaces = try await account.editableCommunities(for: roomId)
                    let children = await account.roomsOf(roomId)
                    reply.send(["spaces": spaces.map { space in
                        ["id": space.id, "name": space.name,
                         "added": !children.isEmpty && children.allSatisfy { space.rooms.contains($0) }]
                    }])
                case "createSpace", "addToSpace":
                    let account = try await signedIn()
                    guard try sendsReadReceipts(account) else { throw ExactNativeRefusal("a drive changes only a test user's chats") }
                    if request["op"] as? String == "createSpace" {
                        let path = request["path"] as? String ?? ""
                        let id = try await account.createSpace(name: request["name"] as? String ?? "",
                            picture: path.isEmpty ? nil : appFile(path), mimetype: request["mimetype"] as? String ?? "image/jpeg")
                        reply.send(["id": id])
                    } else {
                        try await account.addToSpace(roomId: request["roomId"] as? String ?? "", spaceId: request["spaceId"] as? String ?? "")
                        reply.send(["ok": true])
                    }
                case "requests":
                    // the chats this account is invited to (MatrixCore's Requests.swift), newest first.
                    let account = try await signedIn()
                    let requests = try await account.requests()
                    reply.send(["requests": requests.map { r in
                        ["id": r.id, "name": r.name, "isDirect": r.isDirect, "inviterId": r.inviterId, "inviterName": r.inviterName,
                         "avatar": cached(r.avatarName, topic: "rooms") { _ = try await account.avatarFile(roomId: r.id, directory: self.media) }] }])
                case "answerRequest":
                    // Accept joins the chat; Decline refuses the invite. A drive answers only a test user's.
                    let roomId = request["roomId"] as? String ?? "", account = try await signedIn()
                    guard try sendsReadReceipts(account) else { throw ExactNativeRefusal("a drive changes only a test user's chats") }
                    if request["accept"] as? Bool == true { try await account.accept(request: roomId) } else { try await account.decline(request: roomId) }
                    reply.send(["ok": true])
                case "canSendLater", "sendLater", "scheduled", "scheduledAction", "reschedule":
                    // Send Later (MatrixCore's ScheduledMessages.swift): messages that wait on the server.
                    reply.send(try await sendLater(request["op"] as? String ?? "", request))
                case "search":
                    // what the search screen shows (MatrixCore's Search.swift): a kind's messages, the
                    // recent chats before any word, or chats by name, messages and links.
                    reply.send(try await search(request))
                case "showMessage":
                    // a found message's chat pages back to it; its id there, or "" when it is further back.
                    let id = try await signedIn().showMessage(roomId: request["roomId"] as? String ?? "", eventId: request["eventId"] as? String ?? "")
                    reply.send(["id": id ?? ""])
                case "messages":
                    let roomId = request["roomId"] as? String ?? "", account = try await signedIn()
                    // where the "New" line goes: the first message after this account's read receipt.
                    // first, as it may page the chat back to it: the messages then hold it.
                    let firstUnread = (try? await account.firstUnread(roomId: roomId)) ?? nil
                    let messages = try await account.messages(roomId: roomId, limit: request["limit"] as? Int ?? 20)
                    let atStart = try await account.isAtStart(roomId: roomId)
                    reply.send(["atStart": atStart, "firstUnread": firstUnread ?? "", "messages": messages.map {
                        ["id": $0.id, "event": $0.eventId, "sender": $0.sender, "senderName": $0.senderName, "body": $0.body,
                         "time": Double($0.timestamp), "isOwn": $0.isOwn, "state": $0.sendState.rawValue,
                         "waitingForKey": $0.waitingForKey, "isEdited": $0.isEdited,
                         "isDeleted": $0.isDeleted, "isEditable": $0.isEditable,
                         "isImage": $0.image != nil, "image": thumbnail(account, roomId: roomId, message: $0),
                         "imageWidth": $0.image?.width ?? 0, "imageHeight": $0.image?.height ?? 0,
                         "senderPicture": senderPicture(account, roomId: roomId, message: $0),
                         "reply": $0.reply.map { ["senderName": $0.senderName, "body": $0.body, "isOwn": $0.isOwn] } ?? [:],
                         "reactions": $0.reactions.map { ["key": $0.key, "count": $0.count, "isMine": $0.isMine] },
                         "file": $0.file.map { ["name": $0.name, "size": $0.size, "mimetype": $0.mimetype] } ?? [:],
                         "progress": $0.uploadProgress ?? -1, "isSticker": $0.isSticker,
                         "video": $0.video.map { ["width": $0.width, "height": $0.height, "duration": $0.duration] } ?? [:],
                         "poster": poster(account, roomId: roomId, message: $0),
                         "audio": $0.audio.map { ["isVoice": $0.isVoice, "duration": $0.duration, "waveform": $0.waveform, "key": $0.fileName] } ?? [:],
                         "readers": $0.readBy.map { ["name": $0.name, "time": Double($0.timestamp ?? 0)] }]
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
                case "video":
                    // a video message's video, downloaded once to play.
                    let file = try await signedIn().videoFile(roomId: request["roomId"] as? String ?? "",
                                                              messageId: request["messageId"] as? String ?? "", directory: media)
                    reply.send(["path": "app:/cache/matrix-media/\(file.lastPathComponent)"])
                case "audio":
                    // a voice message's sound, downloaded once to play.
                    let file = try await signedIn().audioFile(roomId: request["roomId"] as? String ?? "",
                                                              messageId: request["messageId"] as? String ?? "", directory: media)
                    reply.send(["path": "app:/cache/matrix-media/\(file.lastPathComponent)"])
                case "prepareVoice", "sendVoice":
                    // a recording made ready (Ogg Opus, its length and waveform), then sent as a voice message.
                    reply.send(try await voice(request))
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
                case "recovery":
                    // Settings: on, off, or key (this device needs the account's recovery key).
                    let account = try await signedIn()
                    let status = await account.recoveryStatus()
                    reply.send(["status": status == .enabled ? "on" : status == .disabled ? "off" : status == .incomplete ? "key" : ""])
                case "recover":
                    // the recovery key opens the account's backup; a drive does it only as a test user.
                    let account = try await signedIn()
                    guard try sendsReadReceipts(account) else { throw ExactNativeRefusal("a drive unlocks recovery only as a test user") }
                    do {
                        try await account.recover(recoveryKey: request["key"] as? String ?? "")
                        reply.send(["ok": true, "problem": ""])
                    } catch RecoveryKeyError.wrongKey {
                        reply.send(["ok": false, "problem": "wrongKey"])
                    } catch {
                        print("matrix: recovery failed: \(error)")
                        reply.send(["ok": false, "problem": "failed"])
                    }
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
                case "profile":
                    // the account's name and picture for Settings, and the app's version.
                    let account = try await signedIn(), profile = try await account.ownProfile()
                    reply.send(["userId": profile.userId, "name": profile.displayName,
                                "avatar": cached(profile.avatarName, then: .profile) {
                                    _ = try await account.pictureFile(url: profile.avatarUrl, directory: self.media)
                                },
                                "version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""])
                case "bookmarks", "bookmark", "removeBookmark":
                    // saved messages (Bookmarks.swift).
                    reply.send(try await bookmarks(request))
                case "chatInfo", "chatMembers", "chatMedia", "rename", "customName", "invite", "setPicture", "expiry", "setExpiry":
                    // a chat's info page (Info.swift).
                    reply.send(try await info(request))
                case "registerPush":
                    // with the notification permission: the push token to the server (PushRegistration.swift).
                    reply.send(["registered": try await registerPush()])
                case "signOut":
                    try await signOut()
                    reply.send(["ok": true])
                default:
                    reply.fail("matrix answers registerPush, signIn, rooms, search, showMessage, pin, unpin, chat, messages, markRead, draft, saveDraft, older, photo, recovery, recover, video, audio, prepareVoice, sendVoice, send, sendMedia, file, maxUploadSize, react, edit, deleteMessage, forward, media, emojis, resetEmojis, retry, discard, profile, bookmarks, bookmark, removeBookmark, chatInfo, chatMembers, chatMedia, rename, customName, invite, setPicture and signOut")
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
        let store = UUID().uuidString, searchKey = SearchIndex.newKey()
        do {
            let signedIn = try await MatrixAccount.signIn(homeserver: server, user: user, password: password,
                                                          deviceName: context.agent ? "Multiplexer test" : "Multiplexer",
                                                          storeDirectory: stores.appendingPathComponent(store), searchIndexKey: searchKey,
                                                          sessionStorage: sessionStorage)
            do {
                try keychain.write(StoredSession(session: try signedIn.savedSession(), store: store, searchKey: searchKey))
            } catch {
                // a session this device cannot keep must not stay on the server.
                try? await signedIn.signOut()
                throw error
            }
            tellChanges(signedIn)
            logSearchIndex(signedIn)
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

    @MainActor func signedIn() async throws -> MatrixAccount {
        if let account { return try await account.value }
        guard var stored = try stored() else { throw ExactNativeRefusal("signed out") }
        // a session kept before the search index gets its key now; its index starts empty.
        if stored.searchKey == nil {
            stored.searchKey = SearchIndex.newKey()
            try keychain.write(stored)
        }
        let restoring = Task { [stored] in
            try await MatrixAccount.restore(stored.session, storeDirectory: stores.appendingPathComponent(stored.store), searchIndexKey: stored.searchKey,
                                            sessionStorage: sessionStorage)
        }
        account = restoring
        do {
            let restored = try await restoring.value
            tellChanges(restored)
            logSearchIndex(restored)
            return restored
        } catch {
            account = nil
            throw error
        }
    }

    /// The session as the sdk keeps it for the notification extension too: the Keychain item,
    /// whose session a refreshed token replaces.
    private var sessionStorage: SessionStorage {
        let keychain = self.keychain
        return SessionStorage(load: { try? keychain.read()?.session }, save: { session in
            guard var stored = try? keychain.read() else { return }
            stored.session = session
            try? keychain.write(stored)
        })
    }

    /// Read receipts go out, except in a drive on an account that is not a test user: a drive
    /// on Rami's real account must never mark a chat read (AGENTS.md, the safety rule), and
    /// with the WhatsApp bridge a receipt also marks the chat read in WhatsApp. A chat's
    /// actions (mute, archive, ...) follow the same rule.
    func sendsReadReceipts(_ account: MatrixAccount) throws -> Bool {
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

    /// A chat as app.ts takes it; `listed`: the list shows it. Its picture, once downloaded,
    /// tells `topic`.
    @MainActor private func roomRecord(_ room: RoomSummary, listed: Bool, _ account: MatrixAccount, topic: String) -> [String: Any] {
        ["id": room.id, "name": room.name, "roomName": room.roomName, "isDirect": room.isDirect, "lastMessage": room.lastMessage,
         "lastSender": room.lastSenderName, "lastIsOwn": room.lastIsOwn, "lastTime": Double(room.lastTimestamp),
         "unread": room.unreadCount, "network": room.network, "markedUnread": room.isMarkedUnread,
         "oneToOne": room.isOneToOne, "listed": listed,
         "muted": room.isMuted, "mentions": room.unreadMentions, "lowPriority": room.isLowPriority,
         "archived": room.isArchived, "reminder": Double(room.reminderAt ?? 0),
         // Merge Chats: every network, the room a merged chat opens, its merge (a folded room's too) and its rooms.
         "networks": room.networks, "open": room.opensRoom, "merge": room.mergeId ?? "",
         "mergeRooms": room.mergeRooms.map { ["id": $0.id, "network": $0.network] },
         "avatar": cached(room.avatarName, topic: topic) { _ = try await account.avatarFile(roomId: room.id, directory: self.media) }]
    }

    /// Send Later. `when` is "tomorrow", "monday" or a picked time without a zone
    /// ("2026-11-04T09:30"), read in the iPhone's calendar and zone. A refusal answers `problem`:
    /// "encrypted", "past" (a time not ahead), "far" (past the server's maximum), "gone" (it went
    /// or was cancelled), or "failed".
    @MainActor private func sendLater(_ op: String, _ request: [String: Any]) async throws -> [String: Any] {
        let account = try await signedIn()
        let roomId = request["roomId"] as? String ?? "", id = request["id"] as? String ?? ""
        func at(_ when: Date) -> Double { (when.timeIntervalSince1970 * 1000).rounded() }
        do {
            switch op {
            case "canSendLater":
                return ["room": roomId, "can": (try? await account.canSendLater(roomId: roomId)) ?? false]
            case "sendLater", "reschedule":
                guard let when = ScheduledMessage.date(for: request["when"] as? String ?? "") else { return ["id": "", "at": 0, "problem": "past"] }
                guard when > Date().addingTimeInterval(5) else { return ["id": "", "at": 0, "problem": "past"] }
                let made = op == "sendLater"
                    ? try await account.sendLater(roomId: roomId, text: request["text"] as? String ?? "",
                                                  replyTo: (request["replyTo"] as? String).flatMap { $0.isEmpty ? nil : $0 }, at: when)
                    : try await account.reschedule(id: id, at: when)
                changed(.scheduled)
                return ["id": made, "at": at(when), "problem": ""]
            case "scheduledAction":
                if request["action"] as? String == "send" { try await account.sendScheduledNow(id: id) } else { try await account.cancelScheduled(id: id) }
                changed(.scheduled)
                return ["ok": true]
            default:
                let waiting = try await account.scheduledMessages()
                let byId = Dictionary(try await account.rooms().map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
                return ["messages": waiting.map { m -> [String: Any] in
                    let chat = byId[m.roomId]
                    return ["id": m.id, "room": m.roomId, "chatName": chat?.name ?? m.roomId, "network": chat?.network ?? "matrix",
                            "avatar": chat.map { c in cached(c.avatarName, topic: "scheduled") { _ = try await account.avatarFile(roomId: c.id, directory: self.media) } } ?? "",
                            "body": m.body, "at": Double(m.sendAt), "isReply": m.replyTo != nil]
                }]
            }
        } catch let error as MatrixCoreError {
            let problem: String
            switch error {
            case .scheduleEncrypted: problem = "encrypted"
            case .scheduleGone: problem = "gone"
            case .scheduleRefused(let why): problem = why.contains("DELAY_TOO_LARGE") || why.contains("too large") ? "far" : (why.contains("past") ? "past" : "failed")
            default: throw error
            }
            print("matrix: send later refused (\(problem)): \(error)")
            return op == "scheduledAction" ? ["ok": false, "problem": problem] : ["id": "", "at": 0, "problem": problem]
        }
    }

    /// What the search screen shows for a query (`query`), a kind (`kind`: images, videos, links,
    /// files, audio or "") and the chats opened last (`recent`, newest first). With `room`, the
    /// search in that chat: its messages, and its kinds by their type.
    @MainActor private func search(_ request: [String: Any]) async throws -> [String: Any] {
        let started = Date(), account = try await signedIn()
        let query = request["query"] as? String ?? "", room = request["room"] as? String ?? ""
        let kind = SearchKind(rawValue: request["kind"] as? String ?? "")
        let typed = !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        var chats: [RoomSummary] = [], messages: [FoundMessage] = [], links: [FoundMessage] = []
        if !room.isEmpty {
            if let kind {
                messages = try await account.chatKind(kind, query, roomId: room)
            } else if typed {
                let found = try await account.search(query, in: room)
                (messages, links) = (found.messages, found.links)
            }
        } else if let kind {
            messages = try await account.search(kind: kind, query)
        } else if !typed {
            chats = try await account.chats(request["recent"] as? [String] ?? [])
        } else {
            let found = try await account.search(query)
            (chats, messages, links) = (found.chats, found.messages, found.links)
        }
        print("matrix: search answered \(chats.count) chats, \(messages.count) messages and \(links.count) links in \(Int(Date().timeIntervalSince(started) * 1000)) ms")
        func hit(_ m: FoundMessage) -> [String: Any] {
            ["room": m.chat.id, "chatName": m.chat.name, "isDirect": m.chat.isDirect, "network": m.chat.network,
             "avatar": cached(m.chat.avatarName, topic: "search") { _ = try await account.avatarFile(roomId: m.chat.id, directory: self.media) },
             "event": m.eventId, "senderName": m.senderName, "isOwn": m.isOwn, "body": m.body, "time": Double(m.timestamp),
             "kind": m.kind.rawValue, "links": m.links,
             "picture": cached(m.image?.thumbnailName ?? m.video?.posterName ?? "", topic: "search") {
                 _ = try await account.searchPicture(eventId: m.eventId, directory: self.media) },
             "width": m.image?.width ?? m.video?.width ?? 0, "height": m.image?.height ?? m.video?.height ?? 0,
             "seconds": Int((Double(m.video?.duration ?? m.audio?.duration ?? 0) / 1000).rounded(m.audio == nil ? .down : .toNearestOrAwayFromZero)),
             "isVoice": m.audio?.isVoice ?? false, "fileName": m.file?.name ?? "", "fileSize": m.file?.size ?? 0,
             "senderPicture": cached(m.senderPictureName, topic: "search") {
                 _ = try await account.pictureFile(url: m.senderPicture, directory: self.media) }]
        }
        return ["chats": chats.map { roomRecord($0, listed: true, account, topic: "search") },
                "messages": messages.map(hit), "links": links.map(hit)]
    }

    /// Logs the search index's size and its backfill's time, for a large account's numbers: each
    /// minute while the backfill runs, then once when it is done.
    private func logSearchIndex(_ account: MatrixAccount) {
        func mb(_ bytes: UInt64?) -> String { bytes.map { String(format: "%.1f MB", Double($0) / 1_000_000) } ?? "unknown" }
        Task { [weak account] in
            for _ in 0..<120 {
                try? await Task.sleep(nanoseconds: 60_000_000_000)
                guard let account else { return }
                let status = await account.searchIndexStatus()
                print("matrix: search index \(mb(status.indexBytes)), event cache \(mb(status.eventCacheBytes)), backfill \(status.backfillDone ? "done" : "running") after \(Int(status.backfillSeconds)) s")
                if status.backfillDone { return }
            }
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

    /// A video message's poster as an `app:/` path once it is here (see `cached`); "" for none.
    @MainActor private func poster(_ account: MatrixAccount, roomId: String, message: Message) -> String {
        guard let video = message.video else { return "" }
        return cached(video.posterName, then: .room(roomId)) {
            _ = try await account.videoPoster(roomId: roomId, messageId: message.id, directory: self.media)
        }
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

    /// A recording (`app:/tmp/voice/…`) as the voice message that goes (`prepareVoice`): the Ogg Opus
    /// file's `app:/tmp` path, its length in milliseconds, its size and waveform; or that message put
    /// in the room's send queue (`sendVoice`). A drive sends one only as a test user, as it reacts.
    @MainActor private func voice(_ request: [String: Any]) async throws -> [String: Any] {
        guard let file = appFile(request["path"] as? String ?? "") else { throw ExactNativeRefusal("\(request["op"] ?? "") takes an app:/tmp path") }
        if request["op"] as? String == "prepareVoice" {
            let notes = context.temporary.appendingPathComponent("voice-notes", isDirectory: true)
            let note = try await VoiceNote.prepare(recording: file, directory: notes)
            let folder = note.file.deletingLastPathComponent().lastPathComponent
            return ["path": "app:/tmp/voice-notes/\(folder)/\(note.file.lastPathComponent)", "duration": note.duration,
                    "size": note.size, "waveform": note.waveform]
        }
        let account = try await signedIn()
        guard try sendsReadReceipts(account) else { throw ExactNativeRefusal("a drive sends a voice message only as a test user") }
        let note = VoiceNote(file: file, duration: (request["duration"] as? NSNumber)?.intValue ?? 0,
                             size: (request["size"] as? NSNumber)?.intValue ?? 0,
                             waveform: (request["waveform"] as? [NSNumber])?.map(\.doubleValue) ?? [])
        let replyTo = request["replyTo"] as? String ?? ""
        try await account.sendVoice(roomId: request["roomId"] as? String ?? "", note: note, replyTo: replyTo.isEmpty ? nil : replyTo)
        return ["ok": true]
    }

    /// The file an `app:/tmp/…`, `app:/cache/…` or `app:/data/…` path names in this module's folders.
    func appFile(_ path: String) -> URL? {
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
    @MainActor func cached(_ name: String, then change: MatrixChange, fetch: @escaping () async throws -> Void) -> String {
        cached(name, topic: topic(change), fetch: fetch)
    }

    /// The same, telling app.ts's sources that watch `topic` (`rooms`, `thread:<room id>`, `search`, `info:<room id>`).
    @MainActor func cached(_ name: String, topic: String, fetch: @escaping () async throws -> Void) -> String {
        guard !name.isEmpty else { return "" }
        if FileManager.default.fileExists(atPath: media.appendingPathComponent(name).path) { return "app:/cache/matrix-media/\(name)" }
        guard !failedDownloads.contains(name), downloading.insert(name).inserted else { return "" }
        Task { @MainActor in
            do {
                try await fetch()
                changed(topic: topic)
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
        changed(topic: topic(change))
    }

    private func changed(topic: String) {
        if changedTopics.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                guard let self else { return }
                let topics = changedTopics
                changedTopics = []
                topics.forEach(context.changed)
            }
        }
        changedTopics.insert(topic)
    }

    private func topic(_ change: MatrixChange) -> String {
        switch change {
        case .rooms: return "rooms"
        case .room(let roomId): return "thread:\(roomId)"
        case .profile: return "profile"
        case .info(let roomId): return "info:\(roomId)"
        case .scheduled: return "scheduled"
        case .bookmarks: return "bookmarks"
        case .search: return "search"
        }
    }

    /// Asks the server to forget this device, then forgets the session here. If the server
    /// could not be reached, the session waits to be signed out there later.
    @MainActor private func signOut() async throws {
        let stored = try keychain.read()
        var forgotten = false
        if let signedIn = try? await signedIn() {
            await deletePusher(signedIn, stored)
            forgotten = (try? await signedIn.signOut()) != nil
        }
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
