//
//  HistoryPanel.swift
//  XoaiUtility
//
//  Right-side history of valid conversions. Click an entry to reload it.
//

import SwiftUI

struct HistoryPanel: View {
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var loc: LocalizationManager

    private var t: ThemeTokens { theme.t }

    var body: some View {
        VStack(spacing: 0) {
            header
            if model.history.isEmpty {
                Text("\(loc.s.historyEmpty1)\n\(loc.s.historyEmpty2)")
                    .font(DK.ui(12))
                    .foregroundStyle(t.textFaint)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(20)
            } else {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(model.history) { entry in
                            HistoryRow(entry: entry) { model.loadEntry(entry) }
                        }
                    }
                    .padding(8)
                }
            }
        }
        .frame(width: 260)
        .background(t.bgSide)
        .overlay(Rectangle().frame(width: 1).foregroundStyle(t.border), alignment: .leading)
    }

    private var header: some View {
        HStack {
            Text(loc.s.historyTitle.uppercased())
                .font(DK.ui(11.5, weight: .semibold))
                .tracking(0.46)
                .foregroundStyle(t.textDim)
            Spacer()
            if !model.history.isEmpty {
                Btn(title: loc.s.historyClear) { model.clearHistory() }
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, 10)
        .frame(height: 44)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(t.borderSoft), alignment: .bottom)
    }
}

private struct HistoryRow: View {
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var loc: LocalizationManager
    let entry: HistoryEntry
    let action: () -> Void

    @State private var hovering = false
    private var t: ThemeTokens { theme.t }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Glyph(text: entry.tool.glyph, size: 13)
                        .foregroundStyle(t.textDim)
                        .frame(width: 18, height: 18)
                        .background(t.field, in: RoundedRectangle(cornerRadius: 5))
                        .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(t.borderSoft, lineWidth: 1))
                    Text(entry.tool.displayShortName(loc.s))
                        .font(DK.ui(11, weight: .semibold))
                        .foregroundStyle(t.textDim)
                    Spacer(minLength: 0)
                    Text(Self.relative(entry.ts, loc.s))
                        .font(DK.ui(10))
                        .foregroundStyle(t.textFaint)
                }
                Text(entry.label)
                    .font(DK.mono(11.5))
                    .foregroundStyle(t.text)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(t.panel, in: RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9)
                .strokeBorder(hovering ? t.accentLine : t.borderSoft, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }

    static func relative(_ ts: Date, _ s: Strings) -> String {
        let secs = Date().timeIntervalSince(ts)
        if secs < 60 { return s.timeNow }
        if secs < 3600 { return s.timeMin(Int(secs / 60)) }
        if secs < 86400 { return s.timeHour(Int(secs / 3600)) }
        return s.timeDay(Int(secs / 86400))
    }
}
