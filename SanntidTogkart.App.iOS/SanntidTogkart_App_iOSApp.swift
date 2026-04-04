//
//  SanntidTogkart_App_iOSApp.swift
//  SanntidTogkart.App.iOS
//
//  Created by Harpreet Singh on 08/03/2026.
//

import SwiftUI
import UIKit

@main
struct SanntidTogkart_App_iOSApp: App {
    init() {
        configureTabBarAppearance()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    private func configureTabBarAppearance() {
        let itemColor = UIColor { traits in
            traits.userInterfaceStyle == .dark ? .white : .black
        }

        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.selectionIndicatorTintColor = .clear

        let textAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: itemColor
        ]

        appearance.stackedLayoutAppearance.normal.iconColor = itemColor
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = textAttributes
        appearance.stackedLayoutAppearance.selected.iconColor = itemColor
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = textAttributes

        appearance.inlineLayoutAppearance.normal.iconColor = itemColor
        appearance.inlineLayoutAppearance.normal.titleTextAttributes = textAttributes
        appearance.inlineLayoutAppearance.selected.iconColor = itemColor
        appearance.inlineLayoutAppearance.selected.titleTextAttributes = textAttributes

        appearance.compactInlineLayoutAppearance.normal.iconColor = itemColor
        appearance.compactInlineLayoutAppearance.normal.titleTextAttributes = textAttributes
        appearance.compactInlineLayoutAppearance.selected.iconColor = itemColor
        appearance.compactInlineLayoutAppearance.selected.titleTextAttributes = textAttributes

        let tabBarAppearance = UITabBar.appearance()
        tabBarAppearance.standardAppearance = appearance
        tabBarAppearance.scrollEdgeAppearance = appearance
        tabBarAppearance.tintColor = itemColor
        tabBarAppearance.unselectedItemTintColor = itemColor

        let tabBarItemAppearance = UITabBarItem.appearance()
        tabBarItemAppearance.setTitleTextAttributes(textAttributes, for: .normal)
        tabBarItemAppearance.setTitleTextAttributes(textAttributes, for: .selected)
    }
}
