//
//  P2PTestApp.swift
//  P2PTest
//
//  Created by Nikita Mounier on 09/08/2022.
//

import SwiftUI

@main
struct P2PTestApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView(
                store: .init(
                    initialState: .init(),
                    reducer: p2pReducer,
                    environment: .init(beacon: .live, multipeer: .live, orientation: .live, proximitySensor: .live)
                )
            )
        }
    }
}
