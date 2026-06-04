import Foundation
import Combine
import WebKit

@MainActor
final class WebTab: ObservableObject, Identifiable {
    let id: UUID
    let webView: WKWebView

    @Published var title: String = ""
    @Published var currentURL: URL?
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var isLoading = false

    static let defaultStartURL = URL(string: "https://supabase.com/dashboard")!

    init(account: Account) {
        self.id = account.id

        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore(forIdentifier: account.dataStoreID)
        config.preferences.javaScriptCanOpenWindowsAutomatically = true

        self.webView = WKWebView(frame: .zero, configuration: config)
        self.webView.allowsBackForwardNavigationGestures = true
        self.webView.customUserAgent = Self.desktopUserAgent

        webView.publisher(for: \.title).map { $0 ?? "" }.assign(to: &$title)
        webView.publisher(for: \.url).assign(to: &$currentURL)
        webView.publisher(for: \.canGoBack).assign(to: &$canGoBack)
        webView.publisher(for: \.canGoForward).assign(to: &$canGoForward)
        webView.publisher(for: \.isLoading).assign(to: &$isLoading)

        let startURL = account.lastURL ?? Self.defaultStartURL
        webView.load(URLRequest(url: startURL))
    }

    func goBack() { if webView.canGoBack { webView.goBack() } }
    func goForward() { if webView.canGoForward { webView.goForward() } }
    func reload() { webView.reload() }
    func stopLoading() { webView.stopLoading() }

    func load(urlString: String) {
        var s = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return }
        if !s.contains("://") { s = "https://" + s }
        if let url = URL(string: s) {
            webView.load(URLRequest(url: url))
        }
    }

    func goToDashboard() {
        webView.load(URLRequest(url: Self.defaultStartURL))
    }

    private static let desktopUserAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
}
