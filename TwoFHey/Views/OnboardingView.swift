//
//  OnboardingView.swift
//  2FHey
//

import SwiftUI

enum OnboardingStep {
    case platformSelection
    case iMessagePermissions
    case googleMessagesSetup
}

struct OnboardingView: View {
    @StateObject private var viewModel = OnboardingViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            switch viewModel.currentStep {
            case .platformSelection:
                PlatformSelectionView(
                    selectedPlatform: $viewModel.selectedPlatform,
                    onContinue: {
                        viewModel.proceedFromPlatformSelection()
                    }
                )
            case .iMessagePermissions:
                IMessagePermissionsView(viewModel: viewModel)
            case .googleMessagesSetup:
                GoogleMessagesSetupView(
                    onComplete: {
                        AppStateManager.shared.hasSetup = true
                        AppStateManager.shared.messagingPlatform = .googleMessages
                        NSApplication.shared.keyWindow?.close()
                    },
                    onBack: {
                        viewModel.currentStep = .platformSelection
                    }
                )
            }
        }
        .onAppear {
            viewModel.startMonitoring()
        }
        .onDisappear {
            viewModel.stopMonitoring()
        }
    }
}

struct IMessagePermissionsView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                Image("logo")
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 60)

                Text("Welcome to 2FHey")
                    .font(.system(size: 24, weight: .bold))

                Text("Automatically copy verification codes from iMessage")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 30)
            .padding(.bottom, 25)

            Divider()

            // Permissions Section
            VStack(alignment: .leading, spacing: 20) {
                Text("Required Permissions")
                    .font(.system(size: 18, weight: .semibold))
                    .padding(.bottom, 5)

                // Accessibility Permission
                PermissionRow(
                    icon: "hand.raised.fill",
                    title: "Accessibility",
                    description: "Required for auto-paste and keyboard shortcuts",
                    status: viewModel.hasAccessibility ? .granted : .needed,
                    action: {
                        PermissionsService.acquireAccessibilityPrivileges()
                    }
                )

                // Full Disk Access Permission
                PermissionRow(
                    icon: "externaldrive.fill",
                    title: "Full Disk Access",
                    description: "Required to read verification codes from Messages",
                    status: viewModel.hasFullDiskAccess ? .granted : .needed,
                    action: {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
                    }
                )
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 25)

            Spacer()

            // Status and Action
            HStack {
                Button(action: {
                    viewModel.currentStep = .platformSelection
                }) {
                    Text("Back")
                        .frame(minWidth: 80)
                }
                .buttonStyle(.bordered)

                Spacer()

                if viewModel.allPermissionsGranted {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("All permissions granted")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("Grant permissions above to continue")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: {
                    if viewModel.allPermissionsGranted {
                        AppStateManager.shared.hasSetup = true
                        AppStateManager.shared.messagingPlatform = .iMessage
                    }
                    NSApplication.shared.keyWindow?.close()
                }) {
                    Text(viewModel.allPermissionsGranted ? "Done" : "Close")
                        .frame(minWidth: 80)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 20)
        }
        .frame(minWidth: 600, minHeight: 580)
    }
}

struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String
    let status: PermissionStatus
    let action: () -> Void

    var body: some View {
        HStack(spacing: 15) {
            // Icon
            ZStack {
                Circle()
                    .fill(status == .granted ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(status == .granted ? .green : .orange)
            }

            // Text
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))

                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            // Status/Action
            if status == .granted {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Granted")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
            } else {
                Button("Grant Access") {
                    action()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(15)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

enum PermissionStatus {
    case granted
    case needed
}

class OnboardingViewModel: ObservableObject {
    @Published var currentStep: OnboardingStep = .platformSelection
    @Published var selectedPlatform: MessagingPlatform = .iMessage
    @Published var hasAccessibility: Bool = false
    @Published var hasFullDiskAccess: Bool = false

    private var timer: Timer?

    var allPermissionsGranted: Bool {
        hasAccessibility && hasFullDiskAccess
    }

    init() {
        // Check if user already has a platform selected
        if AppStateManager.shared.hasSetup {
            selectedPlatform = AppStateManager.shared.messagingPlatform
        }
        checkPermissions()
    }

    func proceedFromPlatformSelection() {
        switch selectedPlatform {
        case .iMessage:
            currentStep = .iMessagePermissions
        case .googleMessages:
            currentStep = .googleMessagesSetup
        }
    }

    func startMonitoring() {
        checkPermissions()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkPermissions()
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func checkPermissions() {
        hasAccessibility = AppStateManager.shared.hasAccessibilityPermission()
        hasFullDiskAccess = AppStateManager.shared.hasFullDiscAccess() == .authorized
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView()
    }
}
