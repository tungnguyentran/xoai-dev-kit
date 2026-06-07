//
//  Theme.swift
//  XoaiUtility
//
//  DevKit design system. Colors are authored in oklch (verbatim from the design
//  handoff's index.html) and converted to sRGB at runtime — see `Color(oklch:…)`.
//

import SwiftUI
import Combine

// MARK: - oklch → sRGB

extension Color {
    /// Build a SwiftUI Color from oklch components.
    /// - Parameters:
    ///   - l: perceptual lightness, 0...1
    ///   - c: chroma (≈0...0.4)
    ///   - h: hue in degrees
    ///   - a: alpha, 0...1
    init(oklch l: Double, _ c: Double, _ h: Double, _ a: Double = 1) {
        let hr = h * .pi / 180
        let aa = c * cos(hr)
        let bb = c * sin(hr)

        // oklab → LMS (cube-rooted)
        let l_ = l + 0.3963377774 * aa + 0.2158037573 * bb
        let m_ = l - 0.1055613458 * aa - 0.0638541728 * bb
        let s_ = l - 0.0894841775 * aa - 1.2914855480 * bb

        let lc = l_ * l_ * l_
        let mc = m_ * m_ * m_
        let sc = s_ * s_ * s_

        // LMS → linear sRGB
        let rl =  4.0767416621 * lc - 3.3077115913 * mc + 0.2309699292 * sc
        let gl = -1.2684380046 * lc + 2.6097574011 * mc - 0.3413193965 * sc
        let bl = -0.0041960863 * lc - 0.7034186147 * mc + 1.7076147010 * sc

        func gamma(_ x: Double) -> Double {
            let v = x <= 0.0031308 ? 12.92 * x : 1.055 * pow(x, 1 / 2.4) - 0.055
            return min(1, max(0, v))
        }

        self.init(.sRGB, red: gamma(rl), green: gamma(gl), blue: gamma(bl), opacity: a)
    }
}

// MARK: - Tokens

struct ThemeTokens {
    let bg, bgSide, panel, panel2, field: Color
    let border, borderSoft: Color
    let text, textDim, textFaint: Color
    let accent, accentInk, accentSoft, accentLine: Color
    let danger, dangerSoft, warn: Color
    let hlKey, hlStr, hlNum, hlBool, hlNull: Color
    /// Opacity used for the pane drop shadow (heavier in dark mode).
    let shadowOpacity: Double

    static let dark = ThemeTokens(
        bg:         Color(oklch: 0.175, 0.004, 160),
        bgSide:     Color(oklch: 0.205, 0.004, 160),
        panel:      Color(oklch: 0.215, 0.005, 160),
        panel2:     Color(oklch: 0.245, 0.005, 160),
        field:      Color(oklch: 0.155, 0.004, 160),
        border:     Color(oklch: 0.30,  0.006, 160),
        borderSoft: Color(oklch: 0.255, 0.005, 160),
        text:       Color(oklch: 0.945, 0.004, 160),
        textDim:    Color(oklch: 0.66,  0.007, 160),
        textFaint:  Color(oklch: 0.50,  0.006, 160),
        accent:     Color(oklch: 0.82,  0.16,  152),
        accentInk:  Color(oklch: 0.22,  0.05,  160),
        accentSoft: Color(oklch: 0.82,  0.16,  152, 0.14),
        accentLine: Color(oklch: 0.82,  0.16,  152, 0.40),
        danger:     Color(oklch: 0.72,  0.16,  25),
        dangerSoft: Color(oklch: 0.72,  0.16,  25, 0.13),
        warn:       Color(oklch: 0.82,  0.13,  80),
        hlKey:      Color(oklch: 0.80,  0.10,  230),
        hlStr:      Color(oklch: 0.82,  0.16,  152),
        hlNum:      Color(oklch: 0.83,  0.13,  65),
        hlBool:     Color(oklch: 0.78,  0.14,  320),
        hlNull:     Color(oklch: 0.58,  0.007, 160),
        shadowOpacity: 0.32
    )

    static let light = ThemeTokens(
        bg:         Color(oklch: 0.975, 0.003, 160),
        bgSide:     Color(oklch: 0.955, 0.004, 160),
        panel:      Color(oklch: 1,     0,     0),
        panel2:     Color(oklch: 0.985, 0.003, 160),
        field:      Color(oklch: 0.99,  0.002, 160),
        border:     Color(oklch: 0.89,  0.005, 160),
        borderSoft: Color(oklch: 0.925, 0.004, 160),
        text:       Color(oklch: 0.27,  0.012, 160),
        textDim:    Color(oklch: 0.50,  0.01,  160),
        textFaint:  Color(oklch: 0.64,  0.008, 160),
        accent:     Color(oklch: 0.58,  0.15,  152),
        accentInk:  Color(oklch: 0.99,  0.01,  160),
        accentSoft: Color(oklch: 0.58,  0.15,  152, 0.12),
        accentLine: Color(oklch: 0.58,  0.15,  152, 0.38),
        danger:     Color(oklch: 0.55,  0.20,  25),
        dangerSoft: Color(oklch: 0.55,  0.20,  25, 0.10),
        warn:       Color(oklch: 0.62,  0.14,  75),
        hlKey:      Color(oklch: 0.48,  0.13,  245),
        hlStr:      Color(oklch: 0.50,  0.14,  150),
        hlNum:      Color(oklch: 0.55,  0.15,  50),
        hlBool:     Color(oklch: 0.52,  0.18,  320),
        hlNull:     Color(oklch: 0.62,  0.008, 160),
        shadowOpacity: 0.08
    )
}

// MARK: - Manager

enum AppearanceMode: String {
    case dark, light
}

final class ThemeManager: ObservableObject {
    @AppStorage("devkit-theme") private var stored: String = AppearanceMode.dark.rawValue {
        didSet { objectWillChange.send() }
    }

    var mode: AppearanceMode {
        get { AppearanceMode(rawValue: stored) ?? .dark }
        set { stored = newValue.rawValue }
    }

    /// Current token set.
    var t: ThemeTokens { mode == .dark ? .dark : .light }

    /// Drives `.preferredColorScheme` so native controls match.
    var colorScheme: ColorScheme { mode == .dark ? .dark : .light }
}

// MARK: - Fonts / radii

enum DK {
    static let rSm: CGFloat = 6
    static let rMd: CGFloat = 9
    static let rLg: CGFloat = 13

    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
    static func ui(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
}
