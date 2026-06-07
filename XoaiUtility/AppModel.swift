//
//  AppModel.swift
//  XoaiUtility
//
//  App-level state: which tool is active, the history list (persisted like the
//  prototype's localStorage), and the "seed" used to reload a history entry.
//

import SwiftUI
import Combine

enum ToolID: String, CaseIterable, Identifiable, Codable {
    case json, url, base64, jwt
    var id: String { rawValue }

    var name: String {
        switch self {
        case .json:   return "JSON Formatter"
        case .url:    return "URL Encode / Decode"
        case .base64: return "Base64"
        case .jwt:    return "JWT Decode"
        }
    }

    var desc: String {
        switch self {
        case .json:   return "Format, làm đẹp & xem cây"
        case .url:    return "Mã hóa & giải mã URL"
        case .base64: return "Encode & decode UTF-8"
        case .jwt:    return "Đọc header, payload, claims"
        }
    }

    /// Short mono glyph shown in the sidebar / history badges.
    var glyph: String {
        switch self {
        case .json:   return "{ }"
        case .url:    return "%"
        case .base64: return "64"
        case .jwt:    return "jwt"
        }
    }

    /// First word of the name, used as the history badge label.
    var shortName: String { String(name.split(separator: " ").first ?? "") }
}

struct HistoryEntry: Identifiable, Codable, Equatable {
    var id = UUID()
    let tool: ToolID
    let label: String
    let value: String
    let ts: Date
}

/// Carries a value to push into the active tool's input. `n` is bumped on each
/// load so tools can re-apply even when the value is unchanged.
struct Seed: Equatable {
    let value: String
    let n: Int
}

final class AppModel: ObservableObject {
    @Published var active: ToolID = .json
    @Published var showHistory: Bool = true
    @Published private(set) var history: [HistoryEntry] = []
    @Published var seed: Seed?

    private let historyKey = "devkit-history"
    private let maxHistory = 40
    private var seedCounter = 0

    init() { loadHistory() }

    // MARK: Tool switching

    func select(_ tool: ToolID) {
        active = tool
        seed = nil
    }

    func loadEntry(_ e: HistoryEntry) {
        active = e.tool
        seedCounter += 1
        seed = Seed(value: e.value, n: seedCounter)
    }

    // MARK: History

    func pushHistory(tool: ToolID, label: String, value: String) {
        if let first = history.first, first.value == value, first.tool == tool { return }
        history.insert(HistoryEntry(tool: tool, label: label, value: value, ts: Date()), at: 0)
        if history.count > maxHistory { history.removeLast(history.count - maxHistory) }
        persist()
    }

    func clearHistory() {
        history.removeAll()
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: historyKey)
        }
    }

    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: historyKey),
              let decoded = try? JSONDecoder().decode([HistoryEntry].self, from: data)
        else { return }
        history = decoded
    }
}
