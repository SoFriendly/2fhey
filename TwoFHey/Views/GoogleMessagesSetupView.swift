//
//  GoogleMessagesSetupView.swift
//  2FHey
//

import SwiftUI

struct GoogleMessagesSetupView: View {
    @StateObject private var setupService = GoogleMessagesSetupService.shared
    let onComplete: () -> Void
    let onBack: () -> Void

    // Check if app is already installed
    private var isAppAlreadyInstalled: Bool {
        setupService.isAppInstalled
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                Image("logo")
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 60)

                Text("Setup Google Messages")
                    .font(.system(size: 24, weight: .bold))

                Text(isAppAlreadyInstalled
                    ? "Google Messages is already installed"
                    : "We'll install the Google Messages desktop app and help you connect your phone")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 30)
            .padding(.bottom, 25)

            Divider()

            // Content based on setup state
            VStack(spacing: 20) {
                if isAppAlreadyInstalled && setupService.currentStep == .notStarted {
                    alreadyInstalledView
                } else {
                    switch setupService.currentStep {
                    case .notStarted:
                        notStartedView
                case .downloading(let progress):
                        downloadingView(progress: progress)
                    case .mounting, .copying, .unmounting, .generatingCertificate:
                        installingView
                    case .launchingApp:
                        launchingView
                    case .completed:
                        completedView
                    case .failed(let error):
                        failedView(error: error)
                    }
                }
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 25)

            Spacer()

            // Footer
            HStack {
                if case .notStarted = setupService.currentStep {
                    Button(action: onBack) {
                        Text("Back")
                            .frame(minWidth: 80)
                    }
                    .buttonStyle(.bordered)
                } else if case .failed = setupService.currentStep {
                    Button(action: onBack) {
                        Text("Back")
                            .frame(minWidth: 80)
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()

                if case .completed = setupService.currentStep {
                    Button(action: onComplete) {
                        Text("Done")
                            .frame(minWidth: 100)
                    }
                    .buttonStyle(.borderedProminent)
                } else if isAppAlreadyInstalled && setupService.currentStep == .notStarted {
                    Button(action: onComplete) {
                        Text("Continue")
                            .frame(minWidth: 100)
                    }
                    .buttonStyle(.borderedProminent)
                } else if case .notStarted = setupService.currentStep {
                    Button(action: {
                        Task {
                            await setupService.startSetup()
                        }
                    }) {
                        Text("Install Google Messages")
                            .frame(minWidth: 150)
                    }
                    .buttonStyle(.borderedProminent)
                } else if case .failed = setupService.currentStep {
                    Button(action: {
                        setupService.currentStep = .notStarted
                    }) {
                        Text("Try Again")
                            .frame(minWidth: 100)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 20)
        }
        .frame(minWidth: 600, minHeight: 580)
    }

    private var alreadyInstalledView: some View {
        VStack(spacing: 25) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 80, height: 80)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.green)
            }

            Text("Google Messages is ready!")
                .font(.system(size: 20, weight: .semibold))

            Text("The app is already installed on your Mac. Click Continue to start monitoring for verification codes.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button(action: {
                setupService.launchGoogleMessagesApp()
            }) {
                HStack {
                    Image(systemName: "arrow.up.forward.app")
                    Text("Open Google Messages")
                }
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 20)
    }

    private var notStartedView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("What will happen:")
                .font(.system(size: 18, weight: .semibold))

            Text("This installs a special version of Google Messages for Desktop that allows 2FHey to detect incoming verification codes.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .padding(.bottom, 4)

            SetupStepRow(
                number: 1,
                title: "Download Google Messages App",
                description: "We'll download the 2FHey-compatible desktop app"
            )

            SetupStepRow(
                number: 2,
                title: "Install to Applications",
                description: "The app will be installed to your Applications folder"
            )

            SetupStepRow(
                number: 3,
                title: "Pair with your phone",
                description: "Scan a QR code with your Android phone to connect"
            )

            SetupStepRow(
                number: 4,
                title: "Receive verification codes",
                description: "2FHey will automatically detect and copy codes"
            )
        }
    }

    private func downloadingView(progress: Double) -> some View {
        VStack(spacing: 20) {
            ProgressView(value: progress)
                .progressViewStyle(.linear)

            HStack {
                Image(systemName: "arrow.down.circle")
                    .foregroundColor(.accentColor)
                Text("Downloading Google Messages...")
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(progress * 100))%")
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 40)
    }

    private var installingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Installing Google Messages...")
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 40)
    }

    private var launchingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Launching Google Messages...")
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 40)
    }

    private var completedView: some View {
        VStack(spacing: 25) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 80, height: 80)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.green)
            }

            Text("Google Messages Installed!")
                .font(.system(size: 20, weight: .semibold))

            VStack(spacing: 10) {
                Text("Next Steps:")
                    .font(.system(size: 14, weight: .medium))

                Text("1. The Google Messages app should now be open\n2. Scan the QR code with your Android phone\n3. 2FHey will automatically detect verification codes")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: {
                setupService.launchGoogleMessagesApp()
            }) {
                HStack {
                    Image(systemName: "arrow.up.forward.app")
                    Text("Open Google Messages")
                }
            }
            .buttonStyle(.bordered)
        }
    }

    private func failedView(error: String) -> some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.15))
                    .frame(width: 80, height: 80)

                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.red)
            }

            Text("Installation Failed")
                .font(.system(size: 20, weight: .semibold))

            Text(error)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 20)
    }
}

struct SetupStepRow: View {
    let number: Int
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 32, height: 32)

                Text("\(number)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.accentColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))

                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct GoogleMessagesSetupView_Previews: PreviewProvider {
    static var previews: some View {
        GoogleMessagesSetupView(
            onComplete: {},
            onBack: {}
        )
    }
}
