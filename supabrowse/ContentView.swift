import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: AccountStore

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
        } detail: {
            Group {
                if let selectedTabID = store.selectedTabID,
                   let tab = store.webTab(for: selectedTabID) {
                    BrowserView(tab: tab)
                        .id(tab.id)
                } else {
                    HomeView()
                }
            }
            .frame(minWidth: 720, minHeight: 480)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AccountStore())
}
