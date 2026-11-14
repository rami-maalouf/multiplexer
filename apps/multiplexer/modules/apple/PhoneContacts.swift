import Contacts
import Foundation

// only the opt-in bit is persisted. contact values live in memory and never enter account data.
@MainActor final class PhoneContacts {
    private let store = CNContactStore()
    private var book: [BookContact]?
    private var dirty = true
    private var revision = 0
    private var observers: [NSObjectProtocol] = []
    private let key = "phone-contacts-enabled"
    var changed: (() -> Void)?

    init() {
        observers.append(NotificationCenter.default.addObserver(forName: .CNContactStoreDidChange, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.invalidate() }
        })
    }
    deinit { observers.forEach(NotificationCenter.default.removeObserver) }
    func invalidate() { revision += 1; dirty = true; changed?() }
    private var allowed: Bool {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        if #available(iOS 18, macOS 15, *), status == .limited { return true }
        return status == .authorized
    }
    func update(_ enabled: Bool?) async throws {
        if let enabled {
            revision += 1
            if enabled && CNContactStore.authorizationStatus(for: .contacts) == .notDetermined {
                _ = try await store.requestAccess(for: .contacts)
            }
            UserDefaults.standard.set(enabled && allowed, forKey: key)
            dirty = true
        }
        guard UserDefaults.standard.bool(forKey: key), allowed else { book = nil; return }
        guard dirty else { return }
        let readingRevision = revision
        book = nil
        let values = try await Task.detached {
            var values: [BookContact] = []
            let request = CNContactFetchRequest(keysToFetch: [CNContactIdentifierKey as CNKeyDescriptor,
                CNContactFormatter.descriptorForRequiredKeys(for: .fullName), CNContactPhoneNumbersKey as CNKeyDescriptor])
            try CNContactStore().enumerateContacts(with: request) { contact, _ in
                let phones = contact.phoneNumbers.map { $0.value.stringValue }
                let name = CNContactFormatter.string(from: contact, style: .fullName) ?? phones.first ?? ""
                if !name.isEmpty { values.append(BookContact(id: contact.identifier, name: name, phones: phones)) }
            }
            return values
        }.value
        guard revision == readingRevision else { return }
        book = values
        dirty = false
    }
    private weak var applied: MatrixAccount?
    private var appliedBook: [BookContact]?
    func apply(_ account: MatrixAccount) {
        if applied !== account || appliedBook != book {
            account.setAddressBook(book)
            applied = account
            appliedBook = book
        }
    }
    var record: [String: Any] {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        let denied = status == .denied || status == .restricted
        var limited = false
        if #available(iOS 18, macOS 15, *) { limited = status == .limited }
        return ["on": book != nil, "denied": denied, "limited": limited, "count": book?.count ?? 0]
    }
}
