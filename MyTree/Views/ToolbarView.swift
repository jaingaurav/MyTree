//
//  ToolbarView.swift
//  MyTree
//
//  Top toolbar with main controls and settings toggle
//

import SwiftUI

struct ToolbarView: View {
    @Binding var showSidebar: Bool
    @Binding var showSettings: Bool
    @Binding var selectedLanguage: Language
    @Binding var degreeOfSeparation: Int

    var body: some View {
        HStack(spacing: 16) {
            // Sidebar toggle (standard Mac sidebar icon)
            Button(action: { showSidebar.toggle() }, label: {
                Image(systemName: showSidebar ? "sidebar.left" : "sidebar.left")
                    .font(.system(size: 16))
                    .foregroundColor(.primary)
            })
            .buttonStyle(.plain)
            .help("Toggle Sidebar")

            Divider()
                .frame(height: 20)

            // Language selector
            Picker("Language", selection: $selectedLanguage) {
                ForEach(Language.allCases, id: \.self) { language in
                    Text(language.rawValue).tag(language)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 150)

            Divider()
                .frame(height: 20)

            // Degree of separation control
            HStack(spacing: 8) {
                Text("Degrees:")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                Text("\(degreeOfSeparation)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(width: 20)

                Slider(
                    value: Binding(
                        get: { Double(degreeOfSeparation) },
                        set: { degreeOfSeparation = Int($0) }
                    ),
                    in: 0...5,
                    step: 1
                )
                .frame(width: 120)

                Text("5")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Settings gear icon
            Button(action: { showSettings.toggle() }, label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 16))
                    .foregroundColor(.primary)
            })
            .buttonStyle(.plain)
            .help("Toggle Settings")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.controlBackground)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.gray.opacity(0.2)),
            alignment: .bottom
        )
    }
}
