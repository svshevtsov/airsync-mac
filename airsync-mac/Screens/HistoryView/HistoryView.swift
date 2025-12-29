//
//  HistoryView.swift
//  airsync-mac
//
//  Notification history view with search and filtering
//

import SwiftUI

struct HistoryView: View {
    @StateObject private var historyManager = NotificationHistoryManager.shared
    @ObservedObject private var appState = AppState.shared

    @AppStorage("notificationStacks") private var notificationStacks = true
    @State private var expandedGroupIds: Set<String> = []
    @State private var history: [NotificationHistory] = []
    @State private var searchText = ""
    @State private var selectedPackageFilter: String? = nil
    @State private var showingClearConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            // Search and filter bar
            searchFilterBar
                .padding()

            // History list
            if history.isEmpty {
                emptyStateView
            } else {
                historyList
            }
        }
        .task {
            await loadHistory()
        }
        .onChange(of: searchText) { _, _ in
            Task { await loadHistory() }
        }
        .onChange(of: selectedPackageFilter) { _, _ in
            Task { await loadHistory() }
        }
    }

    // MARK: - Subviews

    private var searchFilterBar: some View {
        VStack(spacing: 8) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField(L("history.search.placeholder"), text: $searchText)
                    .textFieldStyle(.plain)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(.ultraThinMaterial)
            .cornerRadius(8)

            // Package filter
            if !appState.androidApps.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(
                            label: L("history.filter.all"),
                            isSelected: selectedPackageFilter == nil,
                            action: { selectedPackageFilter = nil }
                        )

                        ForEach(Array(appState.androidApps.values).sorted(by: { $0.name < $1.name }), id: \.packageName) { app in
                            FilterChip(
                                label: app.name,
                                isSelected: selectedPackageFilter == app.packageName,
                                action: {
                                    selectedPackageFilter = app.packageName
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .frame(height: 32)
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text(L("history.empty.title"))
                .font(.title2)
                .fontWeight(.semibold)

            Text(searchText.isEmpty
                 ? L("history.empty.message")
                 : L("history.empty.search"))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var historyList: some View {
        ZStack {
            // stacked view on top when notificationStacks == true
            stackedList
                .opacity(notificationStacks ? 1 : 0)
                .allowsHitTesting(notificationStacks)     // only interact when visible
                .accessibilityHidden(!notificationStacks)
                .animation(.easeInOut(duration: 0.5), value: notificationStacks)

            // flat view on top when notificationStacks == false
            flatList
                .opacity(notificationStacks ? 0 : 1)
                .allowsHitTesting(!notificationStacks)
                .accessibilityHidden(notificationStacks)
                .animation(.easeInOut(duration: 0.5), value: notificationStacks)
        }
    }

    // MARK: - Flat List
    private var flatList: some View {
        List(history, id: \.id) { item in
            HistoryNotificationCard(historyItem: item, onRefresh: {
                Task {
                    await loadHistory()
                }
            })
            .applyGlassViewIfAvailable()
            .listRowSeparator(.hidden)
            .padding(.vertical, 4)
        }
        .scrollContentBackground(.hidden)
        .background(.clear)
        .transition(.blurReplace)
        .listStyle(.sidebar)
    }

    // MARK: - Stacked List
    private var stackedList: some View {
        List {
            ForEach(groupedHistory, id: \.id) { group in
                let isExpanded = expandedGroupIds.contains(group.id)

                let visibleItems: [NotificationHistory] = {
                    if isExpanded {
                        return group.items
                    } else {
                        return group.items.first.map { [$0] } ?? []
                    }
                }()

                ForEach(visibleItems) { item in
                    HistoryNotificationCard(historyItem: item, onRefresh: {
                        Task {
                            await loadHistory()
                        }
                    })
                    .applyGlassViewIfAvailable()
                    .padding(.vertical, 4)
                }

                if group.items.count > 1 {
                    Button {
                        withAnimation(.spring) {
                            if isExpanded {
                                expandedGroupIds.remove(group.id)
                            } else {
                                expandedGroupIds.insert(group.id)
                            }
                        }
                    } label: {
                        Label(
                            isExpanded ? "Show Less" : "Show \(group.items.count - 1) More",
                            systemImage: isExpanded ? "chevron.up" : "chevron.down"
                        )
                        .font(.caption)
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(.clear)
        .transition(.blurReplace)
        .listStyle(.sidebar)
    }

    // MARK: - Helpers
    private var groupedHistory: [HistoryGroup] {
        var groups: [HistoryGroup] = []
        var currentGroup: HistoryGroup?

        var index = 0
        for item in history {
            if let group = currentGroup, group.package == item.package {
                // Add to existing group
                currentGroup?.items.append(item)
            } else {
                // Start a new group
                if let group = currentGroup {
                    groups.append(group)
                    index += 1
                }
                currentGroup = HistoryGroup(index: index, package: item.package, items: [item])
            }
        }

        // Don't forget to append the last group
        if let group = currentGroup {
            groups.append(group)
        }

        return groups
    }

    // MARK: - Actions

    private func loadHistory() async {
        var query = NotificationHistoryManager.HistoryQuery(limit: 200)
        query.searchText = searchText.isEmpty ? nil : searchText
        query.packageFilter = selectedPackageFilter

        let results = await historyManager.fetchHistory(query: query)

        await MainActor.run {
            history = results
        }
    }
}

// MARK: - Helper Structs

struct HistoryGroup: Identifiable {
    let index: Int
    let package: String
    var items: [NotificationHistory]

    var id: String {
        "\(package)_\(index)"
    }
}

// MARK: - Filter Chip Component

struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.2))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HistoryView()
}
