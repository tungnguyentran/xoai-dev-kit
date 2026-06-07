//
//  MangoMark.swift
//  XoaiUtility
//
//  The "Mango" brand mark (design handoff option 5 from "DevKit Logo v2
//  (personal)"): a mango body, green leaf + stem, and a terminal chevron `>`.
//  Authored in a 0–100 coordinate space verbatim from the design's MangoMark
//  SVG and scaled to `size`. Colors are oklch, matching the rest of the design
//  system (see `Color(oklch:…)` in Theme.swift).
//

import SwiftUI

struct MangoMark: View {
    var size: CGFloat = 30

    // Brand colors (oklch), from the design's MangoMark.
    private let leafColor = Color(oklch: 0.80, 0.16, 152)
    private let stemColor = Color(oklch: 0.56, 0.12, 152)
    private let bodyColor = Color(oklch: 0.78, 0.155, 64)
    private let chevronColor = Color(oklch: 0.31, 0.055, 56)

    var body: some View {
        Canvas { ctx, sz in
            ctx.scaleBy(x: sz.width / 100, y: sz.height / 100)

            // leaf — ellipse rotated -40° about (65, 21)
            var leaf = Path(ellipseIn: CGRect(x: 65 - 13, y: 21 - 6.4, width: 26, height: 12.8))
            leaf = leaf.applying(rotation(deg: -40, about: CGPoint(x: 65, y: 21)))
            ctx.fill(leaf, with: .color(leafColor))

            // stem
            var stem = Path()
            stem.move(to: CGPoint(x: 55, y: 30))
            stem.addCurve(to: CGPoint(x: 63, y: 20),
                          control1: CGPoint(x: 57, y: 25), control2: CGPoint(x: 60, y: 22))
            ctx.stroke(stem, with: .color(stemColor),
                       style: StrokeStyle(lineWidth: 3.2, lineCap: .round))

            // body
            var body = Path()
            body.move(to: CGPoint(x: 59, y: 26))
            body.addCurve(to: CGPoint(x: 20, y: 56), control1: CGPoint(x: 40, y: 23), control2: CGPoint(x: 22, y: 37))
            body.addCurve(to: CGPoint(x: 52, y: 89), control1: CGPoint(x: 18, y: 75), control2: CGPoint(x: 34, y: 89))
            body.addCurve(to: CGPoint(x: 82, y: 55), control1: CGPoint(x: 71, y: 89), control2: CGPoint(x: 85, y: 74))
            body.addCurve(to: CGPoint(x: 59, y: 26), control1: CGPoint(x: 79, y: 39), control2: CGPoint(x: 72, y: 28))
            body.closeSubpath()
            ctx.fill(body, with: .color(bodyColor))

            // terminal chevron `>`
            var chevron = Path()
            chevron.move(to: CGPoint(x: 44, y: 48))
            chevron.addLine(to: CGPoint(x: 55, y: 58))
            chevron.addLine(to: CGPoint(x: 44, y: 68))
            ctx.stroke(chevron, with: .color(chevronColor),
                       style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    /// Rotation by `deg` degrees about point `p` (y-down, matching SVG).
    private func rotation(deg: Double, about p: CGPoint) -> CGAffineTransform {
        CGAffineTransform(translationX: p.x, y: p.y)
            .rotated(by: deg * .pi / 180)
            .translatedBy(x: -p.x, y: -p.y)
    }
}

#Preview {
    HStack(spacing: 20) {
        MangoMark(size: 30)
        MangoMark(size: 64)
        MangoMark(size: 96)
    }
    .padding()
    .background(Color(oklch: 0.205, 0.008, 160))
}
