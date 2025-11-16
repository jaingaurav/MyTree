//
//  FamilyTreeView.swift
//  MyTree
//
//  Main family tree visualization view using MVVM architecture.
//  State management delegated to FamilyTreeViewModel.
//

import SwiftUI

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

struct FamilyTreeView: View {
    // MARK: - View Model

    @StateObject var viewModel: FamilyTreeViewModel

    // MARK: - Constants

    let connectionColor = Color.primary.opacity(0.6)
    let highlightedConnectionColor = Color.blue
    let circleRadius: CGFloat = 40 // Half of the 80px circle size

    // MARK: - Environment

    @Environment(\.initialDegreeOfSeparation)
    var initialDegreeOfSeparation

    @Environment(\.initialVisibleMemberIds)
    var initialVisibleMemberIds

    // MARK: - Initialization

    init(treeData: FamilyTreeData, myContact: FamilyMember?) {
        _viewModel = StateObject(wrappedValue: FamilyTreeViewModel(
            treeData: treeData,
            myContact: myContact
        ))
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            mainContent(geometry: geometry)
        }
    }

    // MARK: - Main Content

    @ViewBuilder
    private func mainContent(geometry: GeometryProxy) -> some View {
        treeVisualization(geometry: geometry)
            .gesture(magnificationGesture)
            .gesture(dragGesture)
            .onAppear {
                handleOnAppear(geometry: geometry)
                setupKeyboardMonitoring()
            }
            .onDisappear {
                teardownKeyboardMonitoring()
            }
            .onChange(of: viewModel.members) { _ in handleMembersChange(geometry: geometry) }
            .onChange(of: viewModel.myContact) { _ in handleMyContactChange(geometry: geometry) }
            .onChange(of: viewModel.degreeOfSeparation) { _ in handleDegreeChange(geometry: geometry) }
            .onChange(of: viewModel.layoutConfig.spouseSpacing) { _ in handleSpacingChange(geometry: geometry) }
            .onChange(of: viewModel.layoutConfig.baseSpacing) { _ in handleSpacingChange(geometry: geometry) }
            .onChange(of: geometry.size) { _ in handleGeometryChange(geometry: geometry) }
            .onChange(of: viewModel.visibleMemberIds) { _ in handleVisibleMembersChange(geometry: geometry) }
    }

    // MARK: - Tree Visualization

    @ViewBuilder
    private func treeVisualization(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            // Top toolbar
            ToolbarView(
                showSidebar: $viewModel.showSidebar,
                showSettings: $viewModel.showSettings,
                selectedLanguage: $viewModel.selectedLanguage,
                degreeOfSeparation: $viewModel.degreeOfSeparation
            )

            // Main content area
            HStack(spacing: 0) {
                if viewModel.showSidebar {
                    sidebarView
                }

                ZStack(alignment: .topLeading) {
                    backgroundView
                    canvasView

                    ForEach(Array(viewModel.nodePositions.enumerated()), id: \.offset) { _, nodePos in
                        renderNode(nodePos, geometry: geometry)
                    }

                    if viewModel.showingDetail,
                       let selected = viewModel.selectedMember,
                       let position = viewModel.selectedNodePosition {
                        ContactPopover(
                            member: selected,
                            position: position.cgPoint
                        ) {
                            viewModel.clearSelection()
                        }
                    }
                }

                if viewModel.showSettings {
                    SettingsPanelView(
                        spouseSpacing: Binding(
                            get: { viewModel.layoutConfig.spouseSpacing },
                            set: { viewModel.updateSpacing(spouse: $0, general: viewModel.layoutConfig.baseSpacing) }
                        ),
                        generalSpacing: Binding(
                            get: { viewModel.layoutConfig.baseSpacing },
                            set: { viewModel.updateSpacing(spouse: viewModel.layoutConfig.spouseSpacing, general: $0) }
                        ),
                        animationSpeedMs: $viewModel.animationSpeedMs,
                        debugMode: $viewModel.debugMode,
                        currentStep: viewModel.currentDebugStep,
                        totalSteps: viewModel.totalDebugSteps,
                        stepDescription: viewModel.debugStepDescription,
                        changesSummary: viewModel.debugChangesSummary
                    )
                }
            }
        }
    }

    // MARK: - Node Rendering

    @ViewBuilder
    private func renderNode(_ nodePos: NodePosition, geometry: GeometryProxy) -> some View {
        let sidebarWidth: CGFloat = viewModel.showSidebar ? 480 : 0
        let settingsWidth: CGFloat = viewModel.showSettings ? 280 : 0
        let toolbarHeight: CGFloat = 44
        let zStackWidth = geometry.size.width - sidebarWidth - settingsWidth
        let zStackHeight = geometry.size.height - toolbarHeight
        let posX = nodePos.x * viewModel.scale + viewModel.offset.width + zStackWidth / 2
        let posY = nodePos.y * viewModel.scale + viewModel.offset.height + zStackHeight / 2 + toolbarHeight
        let isVisible = viewModel.visibleNodeIds.contains(nodePos.member.id)

        ContactNodeView(
            member: nodePos.member,
            isSelected: viewModel.selectedMember?.id == nodePos.member.id,
            isHighlighted: viewModel.highlightedPath.contains(nodePos.member.id),
            relationshipInfo: nodePos.relationshipInfo,
            language: viewModel.selectedLanguage
        )
        .opacity(isVisible ? 1.0 : 0.0)
        .scaleEffect(isVisible ? 1.0 : 0.0)
        .position(x: posX, y: posY)
        .onTapGesture(count: 2) {
            handleDoubleTap(nodePos, at: CGPoint(x: posX, y: posY), geometry: geometry)
        }
        .onTapGesture(count: 1) {
            handleSingleTap(nodePos, at: CGPoint(x: posX, y: posY), geometry: geometry)
        }
    }

    // MARK: - Tap Handlers

    private func handleDoubleTap(_ nodePos: NodePosition, at position: CGPoint, geometry: GeometryProxy) {
        viewModel.clearHighlighting()
        viewModel.selectedMember = nodePos.member
        viewModel.selectedNodePosition = ScreenCoordinate(x: position.x, y: position.y)
        viewModel.highlightPathToRoot(from: nodePos.member.id)
        viewModel.showingDetail = true
        centerOnNode(nodePos, in: geometry)
    }

    private func handleSingleTap(_ nodePos: NodePosition, at position: CGPoint, geometry: GeometryProxy) {
        if viewModel.selectedMember?.id == nodePos.member.id {
            // Clicking same node - toggle off
            viewModel.clearSelection()
        } else {
            // Select and highlight new node
            viewModel.clearHighlighting()
            viewModel.selectedMember = nodePos.member
            viewModel.selectedNodePosition = ScreenCoordinate(x: position.x, y: position.y)
            viewModel.highlightPathToRoot(from: nodePos.member.id)
            viewModel.showingDetail = false
            centerOnNode(nodePos, in: geometry)
        }
    }
}

// MARK: - Environment Keys

private struct InitialDegreeOfSeparationKey: EnvironmentKey {
    static let defaultValue: Int? = nil
}

private struct InitialVisibleMemberIdsKey: EnvironmentKey {
    static let defaultValue: Set<String>? = nil
}

extension EnvironmentValues {
    var initialDegreeOfSeparation: Int? {
        get { self[InitialDegreeOfSeparationKey.self] }
        set { self[InitialDegreeOfSeparationKey.self] = newValue }
    }

    var initialVisibleMemberIds: Set<String>? {
        get { self[InitialVisibleMemberIdsKey.self] }
        set { self[InitialVisibleMemberIdsKey.self] = newValue }
    }
}
