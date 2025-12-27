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

    @State private var history: [NotificationHistory] = []
    @State private var searchText = ""
    @State private var selectedPackageFilter: String? = nil
    @State private var isLoading = false
    @State private var showingClearConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            // Search and filter bar
            searchFilterBar
                .padding()

            // History list
            if isLoading {
                ProgressView(L("history.loading"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if history.isEmpty {
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
        .listStyle(.sidebar)
    }

    // MARK: - Actions

    private func loadHistory() async {
        isLoading = true

        var query = NotificationHistoryManager.HistoryQuery(limit: 200)
        query.searchText = searchText.isEmpty ? nil : searchText
        query.packageFilter = selectedPackageFilter

        let results = await historyManager.fetchHistory(query: query)

        await MainActor.run {
            history = results
            isLoading = false
        }
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
