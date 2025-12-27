//
//  HistoryNotificationCard.swift
//  airsync-mac
//
//  Card view for displaying archived notifications in history
//

import SwiftUI

struct HistoryNotificationCard: View {
    let historyItem: NotificationHistory
    let onRefresh: (() -> Void)?

    init(historyItem: NotificationHistory, onRefresh: (() -> Void)? = nil) {
        self.historyItem = historyItem
        self.onRefresh = onRefresh
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                // App icon
                appIconView
                    .frame(width: 25, height: 25)
                    .cornerRadius(6)

                VStack(alignment: .leading, spacing: 4) {
                    // App name and title
                    Text("\(historyItem.app)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(historyItem.title)
                        .font(.headline)
                        .lineLimit(2)

                    // Body
                    if !historyItem.body.isEmpty {
                        Text(historyItem.body)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                    }

                    // Metadata row
                    HStack(spacing: 8) {
                        // Timestamp
                        Label(
                            relativeTimeString(from: historyItem.receivedAt),
                            systemImage: "clock"
                        )
                        .font(.caption)
                        .foregroundColor(.secondary)

                        // Device name
                        if let deviceName = historyItem.deviceName {
                            Label(deviceName, systemImage: "iphone")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        // Hidden badge
                        if historyItem.isHidden {
                            Label(L("history.badge.hidden"), systemImage: "eye.slash")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contextMenu {
            // Hide/Unhide option
            if historyItem.isHidden {
                Button {
                    Task {
                        await NotificationHistoryManager.shared.unhideNotification(nid: historyItem.nid)
                        onRefresh?()
                    }
                } label: {
                    Label("Unhide Notification", systemImage: "eye")
                }
            } else {
                Button {
                    Task {
                        await NotificationHistoryManager.shared.hideNotification(nid: historyItem.nid)
                        onRefresh?()
                    }
                } label: {
                    Label("Hide Notification", systemImage: "eye.slash")
                }
            }

            Divider()

            // Copy notification text
            Button {
                let notificationText = """
                \(historyItem.app): \(historyItem.title)
                \(historyItem.body)
                """
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(notificationText, forType: .string)
            } label: {
                Label("Copy Notification Text", systemImage: "doc.on.doc")
            }

            Divider()

            // Show metadata
            Section {
                Text("App Bundle: \(historyItem.package)")
                Text("Time: \(formattedTimestamp)")
                if let deviceName = historyItem.deviceName {
                    Text("Device: \(deviceName)")
                }
                if let deviceIP = historyItem.deviceIP {
                    Text("IP: \(deviceIP)")
                }
            }
        }
    }

    @ViewBuilder
    private var appIconView: some View {
        if let path = AppState.shared.androidApps[historyItem.package]?.iconUrl,
           let nsImage = NSImage(contentsOfFile: path) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            Image(systemName: "app.badge")
                .resizable()
                .foregroundColor(.secondary)
                .padding(4)
        }
    }

    private func relativeTimeString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: historyItem.receivedAt)
    }
}

// Preview removed - requires database-backed NotificationHistory instance
