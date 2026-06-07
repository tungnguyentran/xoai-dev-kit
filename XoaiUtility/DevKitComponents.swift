//
//  DevKitComponents.swift
//  XoaiUtility
//
//  Shared DevKit UI: buttons, segmented control, panes, code area, banners.
//  Ported from the design handoff's ui.jsx. Icons use SF Symbols (native macOS
//  equivalents of the prototype's hand-drawn SVGs).
//

import SwiftUI
import AppKit

// MARK: - Icons

enum DKIcon {
    static let copy    = "doc.on.doc"
    static let check   = "checkmark"
    static let clear   = "trash"
    static let paste   = "doc.on.clipboard"
    static let swap    = "arrow.left.arrow.right"
    static let sun     = "sun.max"
    static let moon    = "moon"
    static let history = "clock.arrow.circlepath"
    static let chevron = "chevron.right"
    static let errorTri = "exclamationmark.triangle.fill"
}

/// Small mono glyph badge (sidebar/history icons).
struct Glyph: View {
    let text: String
    var size: CGFloat = 19
    var body: some View {
        Text(text)
            .font(DK.mono(size <= 19 ? 10 : 11, weight: .semibold))
            .tracking(-0.2)
            .frame(width: size, height: size)
    }
}

// MARK: - Clipboard helpers

enum Clip {
    static func copy(_ s: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(s, forType: .string)
    }
    static func paste() -> String {
        NSPasteboard.general.string(forType: .string) ?? ""
    }
}

// MARK: - Button

enum BtnKind { case ghost, solid, soft }

struct Btn: View {
    @EnvironmentObject var theme: ThemeManager
    var icon: String? = nil
    var title: String? = nil
    var kind: BtnKind = .ghost
    var active: Bool = false
    var mono: Bool = false
    var disabled: Bool = false
    var help: String? = nil
    var action: () -> Void

    @State private var hovering = false

    private var t: ThemeTokens { theme.t }

    private var fg: Color {
        if active { return t.accent }
        switch kind {
        case .ghost: return hovering ? t.text : t.textDim
        case .solid: return t.accentInk
        case .soft:  return t.text
        }
    }
    private var bg: Color {
        if active { return t.accentSoft }
        switch kind {
        case .ghost: return hovering ? t.panel2 : .clear
        case .solid: return t.accent
        case .soft:  return t.panel2
        }
    }
    private var stroke: Color {
        switch kind {
        case .soft: return hovering ? t.textFaint : t.border
        default:    return .clear
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon { Image(systemName: icon).font(.system(size: 12.5, weight: .medium)) }
                if let title {
                    Text(title)
                        .font(mono ? DK.mono(12) : DK.ui(12.5, weight: kind == .solid ? .semibold : .medium))
                }
            }
            .foregroundStyle(fg)
            .padding(.horizontal, title == nil ? 7 : 11)
            .frame(height: 28)
            .background(bg, in: RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(stroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .help(help ?? title ?? "")
        .opacity(disabled ? 0.4 : 1)
        .disabled(disabled)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
    }
}

// MARK: - Segmented control

struct Segmented<Value: Hashable>: View {
    @EnvironmentObject var theme: ThemeManager
    let options: [(value: Value, label: String)]
    @Binding var selection: Value

    private var t: ThemeTokens { theme.t }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.value) { opt in
                let on = opt.value == selection
                Button { selection = opt.value } label: {
                    Text(opt.label)
                        .font(DK.ui(12, weight: on ? .semibold : .medium))
                        .foregroundStyle(on ? t.text : t.textDim)
                        .padding(.horizontal, 12)
                        .frame(height: 24)
                        .background(on ? t.panel : .clear, in: RoundedRectangle(cornerRadius: 6))
                        .shadow(color: .black.opacity(on ? 0.18 : 0), radius: 1, y: 1)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(t.field, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(t.borderSoft, lineWidth: 1))
    }
}

// MARK: - Copy button

struct CopyBtn: View {
    @EnvironmentObject var theme: ThemeManager
    var label: String = "Copy"
    var small: Bool = false
    var getText: () -> String

    @State private var done = false
    private var t: ThemeTokens { theme.t }

    private func tap() {
        Clip.copy(getText())
        done = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { done = false }
    }

    var body: some View {
        if small {
            Button(action: tap) {
                HStack(spacing: 4) {
                    Image(systemName: done ? DKIcon.check : DKIcon.copy).font(.system(size: 11))
                    Text(done ? "Đã chép" : label).font(DK.ui(11, weight: .medium))
                }
                .foregroundStyle(done ? t.accent : t.textDim)
                .padding(.horizontal, 7)
                .frame(height: 22)
                .background(t.panel2, in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(t.borderSoft, lineWidth: 1))
            }
            .buttonStyle(.plain)
        } else {
            Btn(icon: done ? DKIcon.check : DKIcon.copy, title: done ? "Đã chép" : label,
                kind: .soft, action: tap)
        }
    }
}

// MARK: - Count bar

struct CountBar<Extra: View>: View {
    @EnvironmentObject var theme: ThemeManager
    let text: String
    @ViewBuilder var extra: () -> Extra

    var body: some View {
        let lines = text.isEmpty ? 0 : text.components(separatedBy: "\n").count
        let chars = text.count
        let bytes = text.utf8.count
        HStack(spacing: 14) {
            Text("\(lines) dòng")
            Text("\(chars) ký tự")
            Text("\(bytes) B")
            extra()
        }
        .font(DK.mono(11))
        .foregroundStyle(theme.t.textFaint)
    }
}

extension CountBar where Extra == EmptyView {
    init(text: String) { self.init(text: text) { EmptyView() } }
}

// MARK: - Pane

struct Pane<Content: View>: View {
    @EnvironmentObject var theme: ThemeManager
    var label: String
    var labelColor: Color? = nil
    var grow: Bool = false
    var right: AnyView? = nil
    var footer: AnyView? = nil
    @ViewBuilder var content: () -> Content

    private var t: ThemeTokens { theme.t }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(label.uppercased())
                    .font(DK.ui(11.5, weight: .semibold))
                    .tracking(0.46)
                    .foregroundStyle(labelColor ?? t.textDim)
                Spacer()
                if let right { HStack(spacing: 4) { right } }
            }
            .padding(.leading, 14)
            .padding(.trailing, 8)
            .frame(height: 38)
            .background(t.panel2)
            .overlay(Rectangle().frame(height: 1).foregroundStyle(t.borderSoft), alignment: .bottom)

            // Body
            content()
                .frame(maxWidth: .infinity, maxHeight: grow ? .infinity : nil, alignment: .topLeading)

            // Footer
            if let footer {
                HStack { footer }
                    .padding(.horizontal, 14)
                    .frame(height: 30)
                    .frame(maxWidth: .infinity)
                    .background(t.panel2)
                    .overlay(Rectangle().frame(height: 1).foregroundStyle(t.borderSoft), alignment: .top)
            }
        }
        .frame(maxHeight: grow ? .infinity : nil)
        .background(t.panel)
        .clipShape(RoundedRectangle(cornerRadius: DK.rLg))
        .overlay(RoundedRectangle(cornerRadius: DK.rLg).strokeBorder(t.border, lineWidth: 1))
        .shadow(color: .black.opacity(t.shadowOpacity), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Code area (mono editor)

struct CodeArea: View {
    @EnvironmentObject var theme: ThemeManager
    @Binding var text: String
    var placeholder: String = ""
    var readOnly: Bool = false
    var focus: FocusState<Bool>.Binding? = nil

    private var t: ThemeTokens { theme.t }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .font(DK.mono(13))
                    .foregroundStyle(t.textFaint)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .allowsHitTesting(false)
            }
            editor
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.clear)
    }

    @ViewBuilder
    private var editor: some View {
        let base = TextEditor(text: $text)
            .font(DK.mono(13))
            .foregroundStyle(t.text)
            .tint(t.accent)
            .scrollContentBackground(.hidden)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .disabled(readOnly)
            .lineSpacing(3)
        if let focus {
            base.focused(focus)
        } else {
            base
        }
    }
}

// MARK: - Banner

struct Banner: View {
    @EnvironmentObject var theme: ThemeManager
    var isError: Bool = true
    let message: String

    private var t: ThemeTokens { theme.t }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: isError ? DKIcon.errorTri : DKIcon.check)
                .font(.system(size: 12))
                .padding(.top, 1)
            Text(message)
                .font(DK.mono(12))
                .lineSpacing(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(isError ? t.danger : t.accent)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isError ? t.dangerSoft : t.accentSoft)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(t.borderSoft), alignment: .top)
    }
}

// MARK: - Empty hint

struct EmptyHint: View {
    @EnvironmentObject var theme: ThemeManager
    let hint: String
    var body: some View {
        Text(hint)
            .font(DK.ui(12.5))
            .foregroundStyle(theme.t.textFaint)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(24)
    }
}

// MARK: - Mono select (indent / scope dropdowns)

struct MonoPicker<Value: Hashable>: View {
    @EnvironmentObject var theme: ThemeManager
    let options: [(value: Value, label: String)]
    @Binding var selection: Value

    private var t: ThemeTokens { theme.t }

    var body: some View {
        Picker("", selection: $selection) {
            ForEach(options, id: \.value) { Text($0.label).tag($0.value) }
        }
        .labelsHidden()
        .font(DK.mono(12))
        .tint(t.textDim)
        .frame(height: 28)
    }
}

// MARK: - Output text (selectable mono)

/// Selectable monospace output text matching the prototype's `pre`.
/// Backed by NSTextView for performance on large output.
struct OutputText: View {
    @EnvironmentObject var theme: ThemeManager
    let text: String
    var body: some View {
        CodeTextView(attributed: plainAttributed(text, color: theme.t.text, theme.t))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
