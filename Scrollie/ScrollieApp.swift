//
//  ScrollieApp.swift
//  Scrollie
//
//  Menu bar app that slows down the scroll wheel of a mouse
//  (built for the Logitech MX Master 3S) below the system minimum.
//

import SwiftUI

@main
struct ScrollieApp: App {
    @State private var controller = ScrollController.shared

    init() {
        ScrollController.shared.start()
    }

    var body: some Scene {
        MenuBarExtra {
            ScrollMenuContent()
        } label: {
            Image(systemName: controller.isActive ? "computermouse.fill" : "computermouse")
        }
        .menuBarExtraStyle(.window)
    }
}
