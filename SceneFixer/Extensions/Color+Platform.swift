//
//  Color+Platform.swift
//  SceneFixer
//
//  Created by Jordan Koch on 2/3/26.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

extension Color {
    /// Platform-adaptive background color for cards and secondary surfaces
    static var platformBackground: Color {
        #if os(tvOS)
        return Color.gray.opacity(0.2)
        #elseif canImport(UIKit)
        return Color(UIColor.systemGray6)
        #else
        return Color.gray.opacity(0.15)
        #endif
    }

    /// Platform-adaptive secondary background
    static var platformSecondaryBackground: Color {
        #if os(tvOS)
        return Color.gray.opacity(0.15)
        #elseif canImport(UIKit)
        return Color(UIColor.secondarySystemBackground)
        #else
        return Color.gray.opacity(0.1)
        #endif
    }

    /// Platform-adaptive card background
    static var platformCardBackground: Color {
        #if os(tvOS)
        return Color.gray.opacity(0.25)
        #elseif canImport(UIKit)
        return Color(UIColor.systemGray5)
        #else
        return Color.gray.opacity(0.2)
        #endif
    }
}

// MARK: - Platform GroupBox Alternative

/// A cross-platform alternative to GroupBox that works on tvOS
struct PlatformGroupBox<Content: View>: View {
    let title: String
    let content: () -> Content

    init(_ title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        #if os(tvOS)
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)
            content()
        }
        .padding()
        .background(Color.platformCardBackground)
        .cornerRadius(12)
        #else
        GroupBox(title) {
            content()
        }
        #endif
    }
}
