//
//  symbolicStateRecallApp.swift
//  symbolicStateRecall
//
//  Created by Asim Sayed on 16/03/26.
//

import SwiftUI

@main
struct symbolicStateRecallApp: App {
    @NSApplicationDelegateAdaptor(AppCoordinator.self) var coordinator

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(coordinator)
        }
    }
}
