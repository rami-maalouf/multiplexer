import Foundation

// a private group of chats. ids stay stable when a label is renamed.
public struct ChatLabel: Codable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var roomIds: [String]
}

public enum LabelError: Error, LocalizedError, Equatable {
    case emptyName, duplicateName, notFound

    public var errorDescription: String? {
        switch self {
        case .emptyName: return "Enter a name for the label."
        case .duplicateName: return "A label with that name already exists."
        case .notFound: return "That label was deleted on another device."
        }
    }
}

enum LabelStore {
    static let type = "com.ramimaalouf.multiplexer.labels"
    struct Content: Codable, Equatable, Sendable {
        var labels: [ChatLabel]
        var revision: String?
    }

    static func read(_ json: String?) -> Content {
        guard let data = json?.data(using: .utf8),
              let content = try? JSONDecoder().decode(Content.self, from: data) else { return Content(labels: [], revision: nil) }
        return content
    }

    static func json(_ content: Content) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return String(decoding: try encoder.encode(content), as: UTF8.self)
    }
}

// serial writes on this device and a short-lived override until its sync confirms a write.
final class LabelStates: @unchecked Sendable {
    private let lock = NSLock()
    private var written: (content: LabelStore.Content, older: Set<String>, at: Date)?
    private var changing: Task<Void, Error>?

    func labels(stored: LabelStore.Content) -> [ChatLabel] {
        lock.withLock {
            guard let written else { return stored.labels }
            if written.content == stored || !written.older.contains(stored.revision ?? "") || Date().timeIntervalSince(written.at) > 30 {
                self.written = nil
                return stored.labels
            }
            return written.content.labels
        }
    }

    func wrote(_ content: LabelStore.Content?, replacing revisions: [String] = []) {
        lock.withLock {
            guard let content else { written = nil; return }
            var older = written?.older ?? []
            if let revision = written?.content.revision { older.insert(revision) }
            older.formUnion(revisions)
            written = (content, older, Date())
        }
    }

    func serially(_ work: @escaping @Sendable () async throws -> Void) async throws {
        let task = lock.withLock {
            let before = changing
            let next = Task { _ = try? await before?.value; try await work() }
            changing = next
            return next
        }
        try await task.value
    }
}

extension MatrixAccount {
    public func labels() async -> [ChatLabel] {
        let stored = LabelStore.read((try? await client.accountData(eventType: LabelStore.type)) ?? nil)
        return labelStates.labels(stored: stored)
    }

    public func createLabel(name: String) async throws -> ChatLabel {
        let label = ChatLabel(id: UUID().uuidString, name: name.trimmingCharacters(in: .whitespacesAndNewlines), roomIds: [])
        try await changeLabels {
            try Self.checkLabelName(label.name, among: $0)
            $0.append(label)
        }
        return label
    }

    public func renameLabel(id: String, name: String) async throws {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        try await changeLabels { labels in
            guard let index = labels.firstIndex(where: { $0.id == id }) else { throw LabelError.notFound }
            try Self.checkLabelName(name, among: labels.filter { $0.id != id })
            labels[index].name = name
        }
    }

    // deleting a label never changes its chats, messages or list placement.
    public func deleteLabel(id: String) async throws {
        try await changeLabels { $0.removeAll { $0.id == id } }
    }

    public func setLabel(id: String, roomIds: [String], included: Bool) async throws {
        for roomId in Set(roomIds) { _ = try await room(roomId, timeout: 30) }
        try await changeLabels { labels in
            guard let index = labels.firstIndex(where: { $0.id == id }) else { throw LabelError.notFound }
            var rooms = Set(labels[index].roomIds)
            if included { rooms.formUnion(roomIds) } else { rooms.subtract(roomIds) }
            labels[index].roomIds = rooms.sorted()
        }
    }

    public func labelInbox(id: String, filter: RoomFilter = .all, network: String? = nil,
                           timeout: TimeInterval = 30) async throws -> Inbox {
        let all = try await rooms(timeout: timeout)
        let members = Set(await labels().first { $0.id == id }?.roomIds ?? [])
        return Inbox(chats: all, listed: Set(all.filter { !$0.isHidden && members.contains($0.id) && $0.passes(filter) }.map(\.id)),
                     pinned: []).on(network: network)
    }

    private static func checkLabelName(_ name: String, among labels: [ChatLabel]) throws {
        guard !name.isEmpty else { throw LabelError.emptyName }
        guard !labels.contains(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) else { throw LabelError.duplicateName }
    }

    private func changeLabels(_ change: @escaping @Sendable (inout [ChatLabel]) throws -> Void) async throws {
        try await startSync(timeout: 30)
        try await labelStates.serially {
            // read the server before a write so a recent edit on another device is preserved.
            let server = LabelStore.read(try await accountDataOnServer(LabelStore.type, session: self.savedSession()))
            let stored = LabelStore.read((try? await self.client.accountData(eventType: LabelStore.type)) ?? nil)
            var labels = server.labels
            let before = labels
            try change(&labels)
            guard labels != before else { return }
            let changed = LabelStore.Content(labels: labels, revision: UUID().uuidString)
            let content = try LabelStore.json(changed)
            self.labelStates.wrote(changed, replacing: [server.revision ?? "", stored.revision ?? ""])
            self.notify(.rooms)
            do { try await self.client.setAccountData(eventType: LabelStore.type, content: content) }
            catch {
                self.labelStates.wrote(nil)
                self.notify(.rooms)
                throw error
            }
        }
    }
}
