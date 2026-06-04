import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: AccountStore

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
        } detail: {
            ZStack {
                ForEach(store.openWebTabs) { tab in
                    BrowserView(tab: tab)
                        .opacity(store.selectedTabID == tab.id ? 1 : 0)
                        .allowsHitTesting(store.selectedTabID == tab.id)
                }
                if store.selectedTabID == nil {
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
