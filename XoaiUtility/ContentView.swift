//
//  ContentView.swift
//  XoaiUtility
//
//  Created by Tung Nguyen Tran on 7/6/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var theme = ThemeManager()
    @StateObject private var model = AppModel()
    @StateObject private var loc = LocalizationManager()

    var body: some View {
        RootView()
            .environmentObject(theme)
            .environmentObject(model)
            .environmentObject(loc)
    }
}

#Preview {
    ContentView()
}
