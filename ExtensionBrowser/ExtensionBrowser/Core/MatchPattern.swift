//
//  MatchPattern.swift
//  ExtensionBrowser
//
//  Bộ kiểm tra URL khớp với Chrome Match Pattern (<all_urls>, *://*.domain.com/*, v.v.)
//

import Foundation

public struct MatchPattern {
    private let regex: NSRegularExpression?

    public init(pattern: String) {
        if pattern == "<all_urls>" {
            self.regex = try? NSRegularExpression(pattern: "^https?://.*$", options: [.caseInsensitive])
            return
        }

        // Chrome pattern format: <scheme>://<host>/<path>
        // Ví dụ: *://*.soundcloud.com/* hoặc https://soundcloud.com/*
        let escaped = MatchPattern.convertPatternToRegex(pattern)
        self.regex = try? NSRegularExpression(pattern: escaped, options: [.caseInsensitive])
    }

    private static func convertPatternToRegex(_ pattern: String) -> String {
        // Tách scheme, host, path
        guard let schemeEnd = pattern.range(of: "://") else {
            // Fallback: thay * bằng .*
            let safe = NSRegularExpression.escapedPattern(for: pattern).replacingOccurrences(of: "\\*", with: ".*")
            return "^\(safe)$"
        }

        let schemePart = String(pattern[..<schemeEnd.lowerBound])
        let afterScheme = String(pattern[schemeEnd.upperBound...])

        var hostPart = afterScheme
        var pathPart = "*"

        if let firstSlash = afterScheme.firstIndex(of: "/") {
            hostPart = String(afterScheme[..<firstSlash])
            pathPart = String(afterScheme[firstSlash...])
        }

        // 1. Xử lý scheme
        let regexScheme: String
        if schemePart == "*" {
            regexScheme = "https?"
        } else {
            regexScheme = NSRegularExpression.escapedPattern(for: schemePart)
        }

        // 2. Xử lý host
        let regexHost: String
        if hostPart == "*" {
            regexHost = "[^/]+"
        } else if hostPart.hasPrefix("*.") {
            let baseHost = String(hostPart.dropFirst(2))
            let escapedBase = NSRegularExpression.escapedPattern(for: baseHost)
            regexHost = "(?:[^/]+\\.)?\(escapedBase)"
        } else {
            regexHost = NSRegularExpression.escapedPattern(for: hostPart)
        }

        // 3. Xử lý path
        let escapedPath = NSRegularExpression.escapedPattern(for: pathPart)
            .replacingOccurrences(of: "\\*", with: ".*")

        return "^\(regexScheme)://\(regexHost)\(escapedPath)$"
    }

    public func matches(url: URL) -> Bool {
        guard let regex = self.regex else { return false }
        let urlString = url.absoluteString
        let range = NSRange(location: 0, length: urlString.utf16.count)
        return regex.firstMatch(in: urlString, options: [], range: range) != nil
    }

    public static func matchesAny(patterns: [String], url: URL) -> Bool {
        for p in patterns {
            let matcher = MatchPattern(pattern: p)
            if matcher.matches(url: url) {
                return true
            }
        }
        return false
    }
}
