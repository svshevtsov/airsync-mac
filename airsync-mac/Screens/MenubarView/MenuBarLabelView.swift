//
//  MenuBarLabelView.swift
//  AirSync
//
//  Created by Sameera Sandakelum on 2025-08-12.
//

import SwiftUI

struct MenuBarLabelView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.openWindow) var openWindow
    @AppStorage("hasPairedDeviceOnce") private var hasPairedDeviceOnce: Bool = false
    @State private var didTriggerFirstLaunchOpen = false

    var body: some View {
        HStack {
            Image(systemName: appState.device != nil
                  ? (appState.notifications.isEmpty
                     ? "iphone.gen3"
                     : "iphone.gen3.radiowaves.left.and.right")
                  : "iphone.slash")
        }
        .onAppear {
            // Open main window on first launch (onboarding not completed)
            if !hasPairedDeviceOnce && !didTriggerFirstLaunchOpen {
                didTriggerFirstLaunchOpen = true
                // Slight delay to ensure everything is set up
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    openWindow(id: "main")
                }
            }
        }
    }
}



#Preview {
    MenuBarLabelView()
}
