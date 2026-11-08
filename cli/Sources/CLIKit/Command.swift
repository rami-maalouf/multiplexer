import Foundation

public struct UsageError: Error, CustomStringConvertible {
    public let description: String
    public init(_ text: String) { description = text }
}

public struct Command {
    public let name: String
    public var positionals: [String] = []
    public var options: [String: String] = [:]
    public var flags: Set<String> = []
    public var limit: Int { Int(options["--limit"] ?? "20")! }
    public var dryRun: Bool { flags.contains("--dry-run") }
    public var date: Date? {
        guard let value = options["--at"] else { return nil }
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions.insert(.withFractionalSeconds)
        return formatter.date(from: value)
    }

    public init(_ args: [String], now: Date = Date()) throws {
        name = args.first ?? "help"
        let counts: [String: Int] = ["login": 1, "whoami": 0, "chats": 0, "logout": 0, "read": 1,
            "search": 1, "watch": 0, "recover": 0, "send": 2, "react": 3, "mark-read": 1, "later": 2,
            "help": 0, "--help": 0, "-h": 0]
        guard let count = counts[name] else { throw UsageError("unknown command: \(name)") }
        let valued: Set<String>
        let switches: Set<String>
        switch name {
        case "login": valued = []; switches = ["--password-stdin"]
        case "chats": valued = ["--limit"]; switches = ["--json"]
        case "read": valued = ["--limit"]; switches = []
        case "search": valued = ["--limit", "--chat"]; switches = []
        case "watch": valued = ["--chat", "--limit"]; switches = []
        case "recover": valued = []; switches = ["--key-stdin"]
        case "send", "react", "mark-read": valued = []; switches = ["--dry-run"]
        case "later": valued = ["--at"]; switches = ["--dry-run"]
        default: valued = []; switches = []
        }
        var i = 1, literal = false
        while i < args.count {
            let arg = args[i]
            if !literal, arg == "--" { literal = true; i += 1; continue }
            if !literal, arg.hasPrefix("--") {
                guard options[arg] == nil, !flags.contains(arg) else { throw UsageError("duplicate option: \(arg)") }
                if switches.contains(arg) { flags.insert(arg) }
                else if valued.contains(arg) {
                    i += 1
                    guard i < args.count, !args[i].hasPrefix("--") else { throw UsageError("\(arg) needs a value") }
                    options[arg] = args[i]
                } else { throw UsageError("unknown option: \(arg)") }
            } else { positionals.append(arg) }
            i += 1
        }
        guard positionals.count == count, positionals.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw UsageError("\(name) needs \(count) nonempty argument(s)")
        }
        if let value = options["--limit"] {
            guard let n = Int(value), (1...1000).contains(n) else { throw UsageError("--limit must be 1 to 1000") }
        }
        if name == "later" {
            guard let date, date > now else { throw UsageError("--at needs a future ISO 8601 timestamp with timezone") }
        }
        if name == "login", !flags.contains("--password-stdin") { throw UsageError("add --password-stdin") }
        if name == "recover", !flags.contains("--key-stdin") { throw UsageError("add --key-stdin") }
        if name == "login" {
            let parts = positionals[0].split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2, parts[0].hasPrefix("@"), parts[0].count > 1, !parts[1].isEmpty else {
                throw UsageError("use a full Matrix user id")
            }
        }
        if name == "react", !positionals[1].hasPrefix("$") { throw UsageError("react needs the message's event id ($...)") }
    }
}

public struct WritePolicy: Decodable {
    public let version: Int
    public let accounts: [String: [String]]
    public func allows(user: String, room: String) -> Bool { version == 1 && (accounts[user]?.contains(room) ?? false) }
}
