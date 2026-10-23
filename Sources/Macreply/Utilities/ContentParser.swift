import Foundation

public enum ContentToken: Equatable, Sendable {
    case text(String)
    case mention(prefix: String, username: String, suffix: String)
    case replyRef(prefix: String, id: Int, suffix: String)
    case hashtag(prefix: String, tag: String, suffix: String)
    case link(prefix: String, url: String, display: String, suffix: String)
}

public enum ContentParser {
    private static let handleCharacters = Set("0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_")
    private static let alphanumericCharacters = Set("0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")
    private static let digitCharacters = Set("0123456789")

    /// Mirrors `app/filters.py:parser(text)` from Subreply to tokenize plain text into interactive elements.
    public static func tokenize(_ text: String) -> [ContentToken] {
        let normalized = text.replacingOccurrences(of: "\u{00A0}", with: " ")
        let words = normalized.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard !words.isEmpty else { return [] }

        var tokens: [ContentToken] = []
        for (index, rawWord) in words.enumerated() {
            if index > 0 {
                tokens.append(.text(" "))
            }
            let (startswith, core, endswith) = unwrapWord(rawWord)

            if core.hasPrefix("http://") || core.hasPrefix("https://") {
                let parts = core.components(separatedBy: "://")
                var address = parts.dropFirst().joined(separator: "://")
                if address.hasPrefix("www.") {
                    address.removeFirst(4)
                }
                if address.hasSuffix("/") {
                    address.removeLast()
                }
                if !address.isEmpty {
                    let display = address.count > 21 ? String(address.prefix(18)) + "..." : address
                    tokens.append(.link(prefix: startswith, url: core, display: display, suffix: endswith))
                    continue
                }
            } else if core.hasPrefix("@") {
                let handle = String(core.dropFirst())
                if !handle.isEmpty && handle.allSatisfy({ handleCharacters.contains($0) }) {
                    tokens.append(.mention(prefix: startswith, username: handle, suffix: endswith))
                    continue
                }
            } else if core.hasPrefix("#") {
                let handle = String(core.dropFirst())
                if !handle.isEmpty && handle.allSatisfy({ digitCharacters.contains($0) }), let replyID = Int(handle) {
                    tokens.append(.replyRef(prefix: startswith, id: replyID, suffix: endswith))
                    continue
                } else if !handle.isEmpty && handle.allSatisfy({ alphanumericCharacters.contains($0) }) {
                    tokens.append(.hashtag(prefix: startswith, tag: handle, suffix: endswith))
                    continue
                }
            }

            tokens.append(.text(rawWord))
        }
        return tokens
    }

    private static func unwrapWord(_ input: String) -> (startswith: String, word: String, endswith: String) {
        var word = input
        var endswith = ""
        var startswith = ""

        if word.hasSuffix("...") || word.hasSuffix("!!!") || word.hasSuffix("???") {
            endswith = String(word.suffix(3))
            word = String(word.dropLast(3))
        }
        if word.hasSuffix("..") || word.hasSuffix("!!") || word.hasSuffix("??") {
            endswith = String(word.suffix(2))
            word = String(word.dropLast(2))
        }
        if let last = word.last, [".", ",", "!", "?", ":", ";"].contains(last) {
            endswith = String(last)
            word = String(word.dropLast())
        }
        if let last = word.last, [")", "]", "}", "'", "\""].contains(last) {
            endswith = String(last) + endswith
            word = String(word.dropLast())
        }
        if let first = word.first, ["(", "[", "{", "'", "\""].contains(first) {
            startswith = String(first)
            word = String(word.dropFirst())
        }
        if word.hasSuffix("'s") {
            endswith = String(word.suffix(2)) + endswith
            word = String(word.dropLast(2))
        }
        return (startswith, word, endswith)
    }

    /// Mirrors `app/filters.py:age(birthday)` from Subreply.
    public static func age(from birthday: String, now: Date = Date()) -> Int? {
        let trimmed = birthday.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let parts = trimmed.split(separator: "-").compactMap { Int($0) }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        if parts.count >= 2 {
            let year = parts[0]
            let month = parts[1]
            let day = parts.count >= 3 ? parts[2] : 15
            var comps = DateComponents()
            comps.year = year
            comps.month = month
            comps.day = day
            guard let birthDate = calendar.date(from: comps) else { return nil }
            let days = calendar.dateComponents([.day], from: birthDate, to: now).day ?? 0
            return Int((Double(days) / 365.25).rounded())
        } else if let year = Int(trimmed) {
            let currentYear = calendar.component(.year, from: now)
            return currentYear - year
        }
        return nil
    }

    /// Mirrors `app/filters.py:timeago(seconds)` from Subreply.
    public static func timeAgo(since timestamp: Double, now: Double = Date().timeIntervalSince1970) -> String {
        guard timestamp > 0 else { return "" }
        let rawSeconds = max(0, now - timestamp)
        let milliseconds = Int((rawSeconds * 1000).rounded())
        let seconds = Int(rawSeconds.rounded())
        let days = seconds / (3600 * 24)
        let years = days / 365
        var remDays = days - 365 * years
        let weeks = remDays / 7
        remDays = remDays - 7 * weeks

        if years == 0 && days == 0 {
            if seconds == 0 {
                return "\(milliseconds)ms"
            }
            if seconds < 60 {
                return "\(seconds)s"
            }
            if seconds < 3600 {
                return "\(seconds / 60)m"
            }
            return "\(seconds / 3600)h"
        }
        if years == 0 {
            if weeks == 0 {
                return "\(days)d"
            }
            return "\(weeks)w"
        }
        if weeks == 0 && remDays == 0 {
            return "\(years)y"
        }
        if weeks == 0 {
            return "\(years)y, \(remDays)d"
        }
        return "\(years)y, \(weeks)w"
    }

    /// Extracts hostname from URL string, matching `app/filters.py:hostname`.
    public static func hostname(from urlString: String) -> String {
        guard let url = URL(string: urlString), let host = url.host else {
            return urlString
        }
        if host.hasPrefix("www.") {
            return String(host.dropFirst(4))
        }
        return host
    }
}
