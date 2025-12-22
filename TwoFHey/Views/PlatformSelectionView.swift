//
//  PlatformSelectionView.swift
//  2FHey
//

import SwiftUI

struct PlatformSelectionView: View {
    @Binding var selectedPlatform: MessagingPlatform
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                Image("logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 60)

                Text("Choose Your Messaging Platform")
                    .font(.system(size: 24, weight: .bold))

                Text("2FHey can monitor one messaging platform at a time for verification codes.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 30)
            .padding(.bottom, 25)

            Divider()

            // Platform Options
            VStack(spacing: 15) {
                PlatformOptionCard(
                    title: "iMessage",
                    description: "Monitor your Mac's Messages app for verification codes",
                    icon: "message.fill",
                    isSelected: selectedPlatform == .iMessage,
                    action: { selectedPlatform = .iMessage }
                )

                PlatformOptionCard(
                    title: "Google Messages",
                    description: "Monitor Google Messages for Web for verification codes",
                    icon: "bubble.left.and.bubble.right.fill",
                    isSelected: selectedPlatform == .googleMessages,
                    action: { selectedPlatform = .googleMessages }
                )
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 25)

            Spacer()

            // Continue Button
            HStack {
                Spacer()

                Button(action: onContinue) {
                    Text("Continue")
                        .frame(minWidth: 100)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 20)
        }
        .frame(minWidth: 600, minHeight: 500)
    }
}

struct PlatformOptionCard: View {
    let title: String
    let description: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 15) {
                // Icon
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.gray.opacity(0.1))
                        .frame(width: 50, height: 50)

                    Image(systemName: icon)
                        .font(.system(size: 22))
                        .foregroundColor(isSelected ? .accentColor : .gray)
                }

                // Text
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)

                    Text(description)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                // Selection Indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: 2)
                        .frame(width: 24, height: 24)

                    if isSelected {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 14, height: 14)
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

struct PlatformSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        PlatformSelectionView(
            selectedPlatform: .constant(.iMessage),
            onContinue: {}
        )
    }
}
