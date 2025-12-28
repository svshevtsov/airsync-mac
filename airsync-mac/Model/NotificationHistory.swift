//
//  NotificationHistory.swift
//  airsync-mac
//
//  Created for notification history feature
//

import Foundation
import GRDB

/// Persisted notification record for history
struct NotificationHistory: Codable, Identifiable, FetchableRecord, PersistableRecord {
    var id: Int64?  // Database auto-increment ID
    let nid: String  // Network ID from Android (unique per notification)
    let title: String
    let body: String
    let app: String  // Display name
    let package: String  // Android package name
    let actions: Data  // JSON-encoded [NotificationAction]

    // Timestamps
    let receivedAt: Date  // When notification was received on Mac
    let syncedAt: Date    // When it was synced to database

    // Metadata
    let deviceName: String?  // Which Android device sent it
    let deviceIP: String?    // Device IP at time of notification

    // Soft delete flag
    var isHidden: Bool  // User dismissed/hid the notification
    var hiddenAt: Date?  // When it was hidden

    // GRDB table name
    static let databaseTableName = "notification_history"

    // Convenience initializer from active Notification
    init(from notification: Notification, deviceName: String?, deviceIP: String?) throws {
        self.id = nil
        self.nid = notification.nid
        self.title = notification.title
        self.body = notification.body
        self.app = notification.app
        self.package = notification.package

        // Encode actions as JSON
        let encoder = JSONEncoder()
        self.actions = try encoder.encode(notification.actions)

        self.receivedAt = Date()
        self.syncedAt = Date()
        self.deviceName = deviceName
        self.deviceIP = deviceIP
        self.isHidden = false
        self.hiddenAt = nil
    }

    // Convert back to Notification for UI display
    func toNotification() -> Notification? {
        guard let actionsArray = try? JSONDecoder().decode([NotificationAction].self, from: actions) else {
            return nil
        }

        return Notification(
            title: title,
            body: body,
            app: app,
            nid: nid,
            package: package,
            actions: actionsArray
        )
    }
}
