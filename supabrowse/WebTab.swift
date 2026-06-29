import Foundation
import Combine
import WebKit
import AppKit

@MainActor
final class WebTab: ObservableObject, Identifiable {
    let id: UUID
    let webView: WKWebView
    private let uiDelegate = BrowserUIDelegate()

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
        self.webView.uiDelegate = uiDelegate

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

@MainActor
private final class BrowserUIDelegate: NSObject, WKUIDelegate, NSWindowDelegate {
    /// window.open で開いたポップアップ。ARC で解放されないよう強参照で保持する。
    private var popupWindows: [NSWindow: WKWebView] = [:]

    // MARK: - ファイル選択（Finder）

    func webView(
        _ webView: WKWebView,
        runOpenPanelWith parameters: WKOpenPanelParameters,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping ([URL]?) -> Void
    ) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = parameters.allowsDirectories
        panel.allowsMultipleSelection = parameters.allowsMultipleSelection
        panel.canCreateDirectories = false

        if let window = webView.window {
            panel.beginSheetModal(for: window) { response in
                completionHandler(response == .OK ? panel.urls : nil)
            }
        } else {
            panel.begin { response in
                completionHandler(response == .OK ? panel.urls : nil)
            }
        }
    }

    // MARK: - 新規ウィンドウ（window.open / target="_blank"）

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        // 渡された configuration を使うことで、セッション（Cookie 等）を親と共有する。
        let width = windowFeatures.width?.doubleValue ?? 1000
        let height = windowFeatures.height?.doubleValue ?? 700
        let rect = NSRect(x: 0, y: 0, width: width, height: height)

        let popup = WKWebView(frame: rect, configuration: configuration)
        popup.uiDelegate = self
        popup.customUserAgent = webView.customUserAgent
        popup.allowsBackForwardNavigationGestures = true

        let window = NSWindow(
            contentRect: rect,
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentView = popup
        window.center()
        window.makeKeyAndOrderFront(nil)

        popupWindows[window] = popup

        // URL を持つ通常の遷移は自分で読み込む（戻り値の WebView を返した時点で
        // WebKit が読み込むケースもあるが、明示しておくと _blank リンクも確実に開く）。
        if navigationAction.targetFrame == nil, navigationAction.request.url != nil {
            popup.load(navigationAction.request)
        }
        return popup
    }

    func webViewDidClose(_ webView: WKWebView) {
        guard let entry = popupWindows.first(where: { $0.value === webView }) else { return }
        entry.key.close()
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        popupWindows.removeValue(forKey: window)
    }

    // MARK: - JavaScript ダイアログ（alert / confirm / prompt）

    func webView(
        _ webView: WKWebView,
        runJavaScriptAlertPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping () -> Void
    ) {
        let alert = NSAlert()
        alert.messageText = message
        alert.addButton(withTitle: "OK")
        present(alert, on: webView) { _ in completionHandler() }
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptConfirmPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (Bool) -> Void
    ) {
        let alert = NSAlert()
        alert.messageText = message
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        present(alert, on: webView) { response in
            completionHandler(response == .alertFirstButtonReturn)
        }
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptTextInputPanelWithPrompt prompt: String,
        defaultText: String?,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (String?) -> Void
    ) {
        let alert = NSAlert()
        alert.messageText = prompt
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        input.stringValue = defaultText ?? ""
        alert.accessoryView = input

        present(alert, on: webView) { response in
            completionHandler(response == .alertFirstButtonReturn ? input.stringValue : nil)
        }
    }

    private func present(
        _ alert: NSAlert,
        on webView: WKWebView,
        handler: @escaping (NSApplication.ModalResponse) -> Void
    ) {
        if let window = webView.window {
            alert.beginSheetModal(for: window, completionHandler: handler)
        } else {
            handler(alert.runModal())
        }
    }
}
