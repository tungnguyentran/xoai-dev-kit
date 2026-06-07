//
//  Previews.swift
//  XoaiUtility
//
//  Preview helpers for the DevKit shell and individual tools.
//

import SwiftUI

private func previewModel(_ tool: ToolID) -> AppModel {
    let m = AppModel()
    m.active = tool
    m.showHistory = false
    return m
}

private func previewTheme(_ mode: AppearanceMode) -> ThemeManager {
    let t = ThemeManager()
    t.mode = mode
    return t
}

private let bigJSON: String = {
    let obj = #"{"m":"c69cdedcb13a4e1d8dbdc1d730967476:ef0a051822cc434690ba59c11752a4f0:1777762200","t":1777762200,"i":false,"r":false,"e":43,"w":true,"a":{"uid":"c69cdedcb13a4e1d8dbdc1d730967476","un":"58ForeverSIC","e":19454.04,"v":20,"lo":[{"id":"SS_Haku_Meng_7Star_Bronze","t":45999,"tb":0,"s":7,"at":4},{"id":"SS_JohnCena_Last_6Star_Gold","t":38989,"tb":0,"s":6,"at":4}],"mv":0,"me":386,"r":439,"en":0}}"#
    return "[" + Array(repeating: obj, count: 15).joined(separator: ",") + "]"
}()

#Preview("JSON big input — Dark") {
    JsonTool()
        .padding(14)
        .frame(width: 840, height: 680)
        .background(ThemeTokens.dark.bg)
        .environmentObject(previewTheme(.dark))
        .environmentObject({
            let m = AppModel(); m.active = .json; m.showHistory = false
            m.seed = Seed(value: bigJSON, n: 1); return m
        }())
        .environmentObject(LocalizationManager())
}

#Preview("Shell — Light") {
    RootView()
        .environmentObject(previewTheme(.light))
        .environmentObject({ let m = AppModel(); m.active = .json; return m }())
        .environmentObject(LocalizationManager())
        .frame(width: 1040, height: 680)
}

#Preview("JWT — Dark") {
    JwtTool()
        .padding(14)
        .frame(width: 760, height: 680)
        .background(ThemeTokens.dark.bg)
        .environmentObject(previewTheme(.dark))
        .environmentObject(previewModel(.jwt))
        .environmentObject(LocalizationManager())
}

#Preview("URL — Dark") {
    UrlTool()
        .padding(14)
        .frame(width: 760, height: 680)
        .background(ThemeTokens.dark.bg)
        .environmentObject(previewTheme(.dark))
        .environmentObject(previewModel(.url))
        .environmentObject(LocalizationManager())
}

#Preview("Base64 — Dark") {
    Base64Tool()
        .padding(14)
        .frame(width: 760, height: 680)
        .background(ThemeTokens.dark.bg)
        .environmentObject(previewTheme(.dark))
        .environmentObject(previewModel(.base64))
        .environmentObject(LocalizationManager())
}
