import SwiftUI

@main
struct supabrowseApp: App {
    @StateObject private var store = AccountStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
