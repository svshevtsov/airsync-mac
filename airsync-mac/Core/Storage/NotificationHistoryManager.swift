//
//  NotificationHistoryManager.swift
//  airsync-mac
//
//  Manages notification history persistence with SQLite via GRDB
//

import Foundation
import GRDB
internal import Combine

/// Manages notification history persistence with SQLite via GRDB
@MainActor
final class NotificationHistoryManager: ObservableObject {
    static let shared = NotificationHistoryManager()

    // Database connection
    private var dbQueue: DatabaseQueue?

    // Published state for SwiftUI
    @Published var recentHistory: [NotificationHistory] = []
    @Published var isLoading = false
    @Published var error: String?

    // Query configuration
    struct HistoryQuery {
        var limit: Int = 100
        var offset: Int = 0
        var packageFilter: String? = nil
        var searchText: String? = nil
        var includeHidden: Bool = false
        var startDate: Date? = nil
        var endDate: Date? = nil
    }

    private init() {
        setupDatabase()
    }

    // MARK: - Database Setup

    private func setupDatabase() {
        do {
            let dbURL = databaseURL()
            print("[history] Database path: \(dbURL.path)")

            // Create database queue
            dbQueue = try DatabaseQueue(path: dbURL.path)

            // Run migrations
            if let queue = dbQueue {
                try DatabaseMigrations.migrate(queue)
            }

            print("[history] Database initialized successfully")

        } catch {
            print("[history] Failed to initialize database: \(error)")
            self.error = "Database initialization failed: \(error.localizedDescription)"
        }
    }

    private func databaseURL() -> URL {
        let baseURL = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("airsync-mac")
            .appendingPathComponent("Database")

        // Create directory if needed
        if !FileManager.default.fileExists(atPath: baseURL.path) {
            try? FileManager.default.createDirectory(
                at: baseURL,
                withIntermediateDirectories: true
            )
        }

        return baseURL.appendingPathComponent("notifications.sqlite")
    }

    // MARK: - CRUD Operations

    /// Archive a notification to history
    func archiveNotification(_ notification: Notification) async {
        guard let db = dbQueue else { return }

        do {
            let deviceName = AppState.shared.device?.name
            let deviceIP = AppState.shared.device?.ipAddress

            let history = try NotificationHistory(
                from: notification,
                deviceName: deviceName,
                deviceIP: deviceIP
            )

            try await db.write { db in
                try history.insert(db)
            }

            print("[history] Archived notification: \(notification.nid)")

        } catch {
            print("[history] Failed to archive notification: \(error)")
        }
    }

    /// Mark notification as hidden (soft delete)
    func hideNotification(nid: String) async {
        guard let db = dbQueue else { return }

        do {
            try await db.write { db in
                try db.execute(
                    sql: """
                    UPDATE notification_history
                    SET isHidden = 1, hiddenAt = ?
                    WHERE nid = ?
                    """,
                    arguments: [Date(), nid]
                )
            }

            print("[history] Marked notification as hidden: \(nid)")

        } catch {
            print("[history] Failed to hide notification: \(error)")
        }
    }

    /// Unhide a notification (restore from hidden state)
    func unhideNotification(nid: String) async {
        guard let db = dbQueue else { return }

        do {
            try await db.write { db in
                try db.execute(
                    sql: """
                    UPDATE notification_history
                    SET isHidden = 0, hiddenAt = NULL
                    WHERE nid = ?
                    """,
                    arguments: [nid]
                )
            }

            print("[history] Unhid notification: \(nid)")

        } catch {
            print("[history] Failed to unhide notification: \(error)")
        }
    }

    /// Fetch notification history with filters
    func fetchHistory(query: HistoryQuery = HistoryQuery()) async -> [NotificationHistory] {
        guard let db = dbQueue else { return [] }

        do {
            let results = try await db.read { db -> [NotificationHistory] in
                var sql = "SELECT * FROM notification_history WHERE 1=1"
                var arguments: [DatabaseValueConvertible] = []

                // Apply filters
                if !query.includeHidden {
                    sql += " AND isHidden = 0"
                }

                if let package = query.packageFilter {
                    sql += " AND package = ?"
                    arguments.append(package)
                }

                if let search = query.searchText, !search.isEmpty {
                    sql += " AND (title LIKE ? OR body LIKE ? OR app LIKE ?)"
                    let pattern = "%\(search)%"
                    arguments.append(contentsOf: [pattern, pattern, pattern])
                }

                if let start = query.startDate {
                    sql += " AND receivedAt >= ?"
                    arguments.append(start)
                }

                if let end = query.endDate {
                    sql += " AND receivedAt <= ?"
                    arguments.append(end)
                }

                // Order by most recent first
                sql += " ORDER BY receivedAt DESC"

                // Pagination
                sql += " LIMIT ? OFFSET ?"
                arguments.append(query.limit)
                arguments.append(query.offset)

                return try NotificationHistory.fetchAll(db, sql: sql, arguments: StatementArguments(arguments))
            }

            return results

        } catch {
            print("[history] Failed to fetch history: \(error)")
            return []
        }
    }

    /// Get total count of notifications
    func getCount(includeHidden: Bool = false) async -> Int {
        guard let db = dbQueue else { return 0 }

        do {
            return try await db.read { db in
                var sql = "SELECT COUNT(*) FROM notification_history"
                if !includeHidden {
                    sql += " WHERE isHidden = 0"
                }
                return try Int.fetchOne(db, sql: sql) ?? 0
            }
        } catch {
            print("[history] Failed to get count: \(error)")
            return 0
        }
    }

    /// Get grouped counts by package
    func getPackageCounts() async -> [String: Int] {
        guard let db = dbQueue else { return [:] }

        do {
            return try await db.read { db in
                let rows = try Row.fetchAll(db, sql: """
                    SELECT package, COUNT(*) as count
                    FROM notification_history
                    WHERE isHidden = 0
                    GROUP BY package
                    ORDER BY count DESC
                """)

                var counts: [String: Int] = [:]
                for row in rows {
                    let package = row["package"] as String
                    let count = row["count"] as Int
                    counts[package] = count
                }
                return counts
            }
        } catch {
            print("[history] Failed to get package counts: \(error)")
            return [:]
        }
    }

    /// Delete all history (for testing/reset purposes)
    func clearAllHistory() async {
        guard let db = dbQueue else { return }

        do {
            try await db.write { db in
                try db.execute(sql: "DELETE FROM notification_history")
            }
            print("[history] Cleared all notification history")
        } catch {
            print("[history] Failed to clear history: \(error)")
        }
    }
}
