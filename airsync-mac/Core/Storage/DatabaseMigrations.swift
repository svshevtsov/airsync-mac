//
//  DatabaseMigrations.swift
//  airsync-mac
//
//  Database schema migrations for notification history
//

import Foundation
import GRDB

enum DatabaseMigrations {
    // Migration version tracking
    static let currentVersion = 1

    // Apply all migrations to a database writer (DatabaseQueue or DatabasePool)
    static func migrate(_ dbWriter: some DatabaseWriter) throws {
        var migrator = DatabaseMigrator()

        // Version 1: Initial notification history schema
        migrator.registerMigration("v1_create_notification_history") { db in
            try db.create(table: "notification_history") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("nid", .text).notNull().indexed()
                t.column("title", .text).notNull()
                t.column("body", .text).notNull()
                t.column("app", .text).notNull()
                t.column("package", .text).notNull().indexed()
                t.column("actions", .blob).notNull()
                t.column("receivedAt", .datetime).notNull().indexed()
                t.column("syncedAt", .datetime).notNull()
                t.column("deviceName", .text)
                t.column("deviceIP", .text)
                t.column("isHidden", .boolean).notNull().defaults(to: false).indexed()
                t.column("hiddenAt", .datetime)
            }

            // Create composite index for common query pattern
            try db.create(index: "idx_notification_history_hidden_received",
                         on: "notification_history",
                         columns: ["isHidden", "receivedAt"])

            print("[migrations] Created notification_history table with indexes")
        }

        // Future migrations will be added here
        // Example:
        // migrator.registerMigration("v2_add_new_column") { db in
        //     try db.alter(table: "notification_history") { t in
        //         t.add(column: "newColumn", .text)
        //     }
        // }

        try migrator.migrate(dbWriter)
    }
}
