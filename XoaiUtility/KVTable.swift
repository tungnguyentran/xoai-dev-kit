//
//  KVTable.swift
//  XoaiUtility
//
//  Two-column key/value table for the URL decode tool's table view.
//

import SwiftUI

struct KVTable: View {
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var loc: LocalizationManager
    let pairs: [FormPair]

    private var t: ThemeTokens { theme.t }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Column header row
                row(key: loc.s.tableKey, value: loc.s.tableValue, header: true)
                ForEach(pairs) { pair in
                    Divider().background(t.borderSoft)
                    row(key: pair.key, value: pair.value, header: false)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func row(key: String, value: String, header: Bool) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Text(key)
                .font(DK.mono(12, weight: header ? .semibold : .regular))
                .foregroundStyle(header ? t.textDim : t.accent)
                .textSelection(.enabled)
                .frame(width: 170, alignment: .topLeading)
                .padding(.vertical, 8)
                .padding(.horizontal, 14)
            Rectangle().frame(width: 1).foregroundStyle(t.borderSoft)
            Text(value)
                .font(DK.mono(12, weight: header ? .semibold : .regular))
                .foregroundStyle(header ? t.textDim : t.text)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(.vertical, 8)
                .padding(.horizontal, 14)
        }
        .background(header ? t.panel2 : Color.clear)
    }
}
