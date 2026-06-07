//
//  Sidebar.swift
//  XoaiUtility
//
//  Left navigation: brand, tool list, theme toggle.
//

import SwiftUI

struct Sidebar: View {
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var loc: LocalizationManager

    private var t: ThemeTokens { theme.t }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            brand
            sectionLabel
            nav
            Spacer(minLength: 0)
            bottomBar
        }
        .frame(width: 232)
        .background(t.bgSide)
        .overlay(Rectangle().frame(width: 1).foregroundStyle(t.border), alignment: .trailing)
    }

    private var brand: some View {
        HStack(spacing: 10) {
            MangoMark(size: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text("DevKit").font(DK.ui(14, weight: .bold)).foregroundStyle(t.text)
                Text("by xoai").font(DK.mono(10.5)).foregroundStyle(t.textFaint)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private var sectionLabel: some View {
        Text(loc.s.navTools.uppercased())
            .font(DK.ui(10.5, weight: .semibold))
            .tracking(0.63)
            .foregroundStyle(t.textFaint)
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 4)
    }

    private var nav: some View {
        VStack(spacing: 1) {
            ForEach(ToolID.allCases) { tool in
                ToolRow(tool: tool, active: model.active == tool) { model.select(tool) }
            }
        }
        .padding(.horizontal, 8)
    }

    private var bottomBar: some View {
        VStack(spacing: 8) {
            langRow
            themeRow
        }
        .padding(12)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(t.borderSoft), alignment: .top)
    }

    private var langRow: some View {
        HStack(spacing: 3) {
            langButton(.vi, label: "VI")
            langButton(.en, label: "EN")
        }
        .padding(3)
        .background(t.field, in: RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(t.borderSoft, lineWidth: 1))
    }

    private func langButton(_ l: Lang, label: String) -> some View {
        let on = loc.lang == l
        return Button { loc.lang = l } label: {
            Text(label)
                .font(DK.mono(12, weight: on ? .semibold : .medium))
                .foregroundStyle(on ? t.toggleSelText : t.textDim)
                .frame(maxWidth: .infinity)
                .frame(height: 28)
                .background(on ? t.toggleSelFill : .clear, in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(on ? t.toggleSelStroke : .clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .help(loc.s.langLabel)
    }

    private var themeRow: some View {
        HStack(spacing: 3) {
            toggleButton(.dark, icon: DKIcon.moon, label: loc.s.themeDark)
            toggleButton(.light, icon: DKIcon.sun, label: loc.s.themeLight)
        }
        .padding(3)
        .background(t.field, in: RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(t.borderSoft, lineWidth: 1))
    }

    private func toggleButton(_ m: AppearanceMode, icon: String, label: String) -> some View {
        let on = theme.mode == m
        return Button { theme.mode = m } label: {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 12))
                Text(label).font(DK.ui(12, weight: on ? .semibold : .medium))
            }
            .foregroundStyle(on ? t.toggleSelText : t.textDim)
            .frame(maxWidth: .infinity)
            .frame(height: 28)
            .background(on ? t.toggleSelFill : .clear, in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6)
                .strokeBorder(on ? t.toggleSelStroke : .clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

private struct ToolRow: View {
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var loc: LocalizationManager
    let tool: ToolID
    let active: Bool
    let action: () -> Void

    @State private var hovering = false
    private var t: ThemeTokens { theme.t }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Glyph(text: tool.glyph)
                    .foregroundStyle(active ? t.accent : t.textDim)
                    .frame(width: 28, height: 28)
                    .background(active ? t.accentSoft : t.field, in: RoundedRectangle(cornerRadius: 7))
                    .overlay(RoundedRectangle(cornerRadius: 7)
                        .strokeBorder(active ? t.accentLine : t.borderSoft, lineWidth: 1))
                VStack(alignment: .leading, spacing: 1) {
                    Text(tool.displayName(loc.s))
                        .font(DK.ui(12.5, weight: active ? .semibold : .medium))
                        .foregroundStyle(active ? t.text : t.textDim)
                    Text(tool.displayDesc(loc.s))
                        .font(DK.ui(10.5))
                        .foregroundStyle(t.textFaint)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 8)
            .background(rowBackground, in: RoundedRectangle(cornerRadius: 8))
            .shadow(color: .black.opacity(active ? t.shadowOpacity : 0), radius: 8, y: 2)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }

    private var rowBackground: Color {
        if active { return t.panel }
        return hovering ? t.panel2 : .clear
    }
}
