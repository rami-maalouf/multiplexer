import Foundation

public enum SessionStoreLocation: String, Codable, Sendable {
    case data, group
}

/// resolves a session's store before any sdk client opens it. a missing entitlement is never
/// proof that a store is gone, including after a move interrupted before its keychain write.
public struct SessionStore {
    public enum Resolution: Equatable {
        case available(StoredSession, URL)
        case unavailable
        case missing
    }

    public enum Problem: Error {
        case conflictingStores, notDirectory
    }

    private let data: URL
    private let group: URL?
    private let agent: Bool

    public init(dataDirectory: URL, groupContainer: URL?, agent: Bool) {
        data = dataDirectory
        group = agent ? nil : groupContainer
        self.agent = agent
    }

    public var newStoreLocation: SessionStoreLocation { group == nil ? .data : .group }

    public func directory(store: String, location: SessionStoreLocation) -> URL? {
        switch location {
        case .data: return MatrixPush.sharedStore(in: data, store: store)
        case .group: return group.map { MatrixPush.sharedStore(in: $0, store: store) }
        }
    }

    /// moves the whole directory, including crypto and search, then persists its location.
    /// if that write fails or the process stops, the old metadata and same destination uuid
    /// let the next launch finish the write without making an empty crypto store.
    public func prepare(_ stored: StoredSession, persist: (StoredSession) throws -> Void) throws -> Resolution {
        let location = stored.storeLocation ?? .data
        guard let current = directory(store: stored.store, location: location) else { return .unavailable }
        let exists = try containsStore(current)
        if location == .group { return exists ? .available(stored, current) : .missing }
        guard let destination = directory(store: stored.store, location: .group) else {
            // a non-agent store may already have moved while its metadata still says data.
            return exists ? .available(stored, current) : (agent ? .missing : .unavailable)
        }
        let moved = try containsStore(destination)
        guard exists || moved else { return .missing }
        guard !(exists && moved) else { throw Problem.conflictingStores }
        if exists {
            try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.moveItem(at: current, to: destination)
        }
        var shared = stored
        shared.storeLocation = .group
        try persist(shared)
        return .available(shared, destination)
    }

    private func containsStore(_ url: URL) throws -> Bool {
        do {
            guard try url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true else { throw Problem.notDirectory }
            return true
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile || error.code == .fileNoSuchFile {
            return false
        }
    }
}
