//
//  SettingsPanelView.swift
//  MyTree
//
//  Right-side settings panel for spacing and animation controls
//

import SwiftUI

struct SettingsPanelView: View {
    @Binding var spouseSpacing: CGFloat
    @Binding var generalSpacing: CGFloat
    @Binding var animationSpeedMs: Double
    @Binding var debugMode: Bool
    let currentStep: Int
    let totalSteps: Int
    let stepDescription: String
    let changesSummary: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(.headline)
                Spacer()
            }
            .padding()

            Divider()

            // Settings content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SpacingControl(
                        spouseSpacing: $spouseSpacing,
                        generalSpacing: $generalSpacing
                    )

                    AnimationSpeedControl(animationSpeedMs: $animationSpeedMs)

                    DebugControl(
                        debugMode: $debugMode,
                        currentStep: currentStep,
                        totalSteps: totalSteps,
                        stepDescription: stepDescription,
                        changesSummary: changesSummary
                    )
                }
                .padding()
            }
        }
        .frame(width: 280)
        .background(Color.controlBackground)
    }
}
