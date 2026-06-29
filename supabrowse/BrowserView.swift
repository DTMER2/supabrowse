import SwiftUI

struct BrowserView: View {
    @ObservedObject var tab: WebTab

    @State private var urlText: String = ""
    @State private var isEditingURL = false

    var body: some View {
        VStack(spacing: 0) {
            BrowserToolbar(
                tab: tab,
                urlText: $urlText,
                isEditing: $isEditingURL
            )
            Divider()
            WebViewRepresentable(webView: tab.webView)
        }
        .onAppear {
            syncURL()
            focusWebView()
        }
        .onChange(of: tab.currentURL) { _, _ in
            if !isEditingURL { syncURL() }
        }
    }

    private func syncURL() {
        urlText = tab.currentURL?.absoluteString ?? ""
    }

    /// 起動・タブ切り替え時に URL フォームへ自動でフォーカスが当たるのを防ぐため、
    /// ウィンドウのファーストレスポンダを WebView に移す。
    private func focusWebView() {
        DispatchQueue.main.async {
            guard let window = tab.webView.window else { return }
            window.makeFirstResponder(tab.webView)
        }
    }
}

private struct BrowserToolbar: View {
    @ObservedObject var tab: WebTab
    @Binding var urlText: String
    @Binding var isEditing: Bool
    @FocusState private var urlFieldFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Button { tab.goBack() } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(!tab.canGoBack)
            .keyboardShortcut("[", modifiers: .command)
            .help("Back")

            Button { tab.goForward() } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(!tab.canGoForward)
            .keyboardShortcut("]", modifiers: .command)
            .help("Forward")

            Button {
                tab.isLoading ? tab.stopLoading() : tab.reload()
            } label: {
                Image(systemName: tab.isLoading ? "xmark" : "arrow.clockwise")
            }
            .keyboardShortcut("r", modifiers: .command)
            .help(tab.isLoading ? "Stop" : "Reload")

            Button { tab.goToDashboard() } label: {
                Image(systemName: "house")
            }
            .help("Supabase dashboard")

            TextField("URL", text: $urlText, onEditingChanged: { isEditing = $0 })
                .textFieldStyle(.roundedBorder)
                .focused($urlFieldFocused)
                .onSubmit {
                    tab.load(urlString: urlText)
                }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .onAppear {
            // 起動・タブ切り替え時に URL フォームへ自動でフォーカスが当たるのを防ぐ。
            urlFieldFocused = false
        }
    }
}
