//
//  AppLog.swift
//  XoaiUtility
//
//  Diagnostic logging: errors are emitted to Apple's unified logging
//  (os.Logger — visible in Xcode console & Console.app, filterable by tool
//  category) and kept in a small in-memory ring buffer for inspection.
//
//  Logging is driven from a discrete change event (the `logErrors` view
//  modifier below), never from the tools' computed parse properties — those
//  re-run on every render and would spam the log.
//

import SwiftUI
import Combine
import OSLog

enum LogLevel: String {
    case error
    // Extensible: info, warning, … when needed.
}

struct LogEntry: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let level: LogLevel
    let category: String   // tool name, or "general"
    let message: String
}

@MainActor
final class AppLog: ObservableObject {
    static let shared = AppLog()

    /// Recent entries, oldest first. Capped at `maxEntries` (oldest evicted).
    @Published private(set) var entries: [LogEntry] = []

    private let maxEntries: Int
    private let subsystem = Bundle.main.bundleIdentifier ?? "nguyentrantung.XoaiUtility"
    private var loggers: [String: Logger] = [:]   // cached os.Logger per category

    init(maxEntries: Int = 200) {
        self.maxEntries = maxEntries
    }

    /// Primary entry point used by the tools. `tool == nil` → "general".
    func error(_ message: String, tool: ToolID?) {
        record(level: .error, category: tool?.name ?? "general", message: message)
    }

    /// General-purpose recorder; basis for future levels.
    func record(level: LogLevel, category: String, message: String) {
        logger(for: category).log(level: level.osType, "\(message, privacy: .public)")

        entries.append(LogEntry(date: Date(), level: level, category: category, message: message))
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
    }

    private func logger(for category: String) -> Logger {
        if let existing = loggers[category] { return existing }
        let made = Logger(subsystem: subsystem, category: category)
        loggers[category] = made
        return made
    }
}

private extension LogLevel {
    var osType: OSLogType {
        switch self {
        case .error: return .error
        }
    }
}

extension View {
    /// Logs each new error message for `tool`. SwiftUI's `onChange` fires only
    /// when the value actually changes, so identical errors during unrelated
    /// re-renders are not re-logged (free deduplication).
    func logErrors(_ tool: ToolID, message: String?) -> some View {
        onChange(of: message) { _, new in
            if let new { AppLog.shared.error(new, tool: tool) }
        }
    }
}
