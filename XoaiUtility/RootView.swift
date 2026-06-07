//
//  RootView.swift
//  XoaiUtility
//
//  DevKit app shell: sidebar | (header + active tool + history panel).
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var loc: LocalizationManager

    private var t: ThemeTokens { theme.t }

    var body: some View {
        HStack(spacing: 0) {
            Sidebar()
            main
        }
        .frame(minWidth: 920, minHeight: 600)
        .background(t.bg)
        .environment(\.locale, loc.locale)
        .preferredColorScheme(theme.colorScheme)
    }

    private var main: some View {
        VStack(spacing: 0) {
            header
            HStack(spacing: 0) {
                toolContent
                    .padding(14)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .id(model.active)
                if model.showHistory {
                    HistoryPanel()
                }
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.active.name).font(DK.ui(15, weight: .semibold)).foregroundStyle(t.text)
                Text(model.active.desc).font(DK.ui(11.5)).foregroundStyle(t.textFaint)
            }
            Spacer()
            Btn(icon: DKIcon.history, title: "Lịch sử",
                kind: model.showHistory ? .soft : .ghost, active: model.showHistory) {
                model.showHistory.toggle()
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(t.border), alignment: .bottom)
    }

    @ViewBuilder
    private var toolContent: some View {
        switch model.active {
        case .json:   JsonTool()
        case .url:    UrlTool()
        case .base64: Base64Tool()
        case .jwt:    JwtTool()
        }
    }
}

/// Input pane on top, output pane below (the design's io layout).
struct ToolFrame<Input: View, Output: View>: View {
    @ViewBuilder var input: () -> Input
    @ViewBuilder var output: () -> Output
    var body: some View {
        VStack(spacing: 10) {
            input()
            output()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
