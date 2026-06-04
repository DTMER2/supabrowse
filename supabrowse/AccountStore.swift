import Foundation
import Combine
import WebKit
import AppKit

@MainActor
final class AccountStore: ObservableObject {
    @Published private(set) var accounts: [Account] = []
    @Published private(set) var openTabIDs: [UUID] = []
    @Published var selectedTabID: UUID?

    private var webTabs: [UUID: WebTab] = [:]
    private var urlCancellables: [UUID: AnyCancellable] = [:]
    private var saveCancellable: AnyCancellable?

    init() {
        loadFromDisk()

        saveCancellable = Publishers.MergeMany(
            $accounts.map { _ in () }.eraseToAnyPublisher(),
            $openTabIDs.map { _ in () }.eraseToAnyPublisher(),
            $selectedTabID.map { _ in () }.eraseToAnyPublisher()
        )
        .dropFirst()
        .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
        .sink { [weak self] in self?.saveToDisk() }

        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.saveToDisk() }
        }
    }

    // MARK: - Tabs

    var openWebTabs: [WebTab] {
        openTabIDs.compactMap { webTabs[$0] }
    }

    func webTab(for accountID: UUID) -> WebTab? {
        webTabs[accountID]
    }

    func openTab(account: Account) {
        if webTabs[account.id] == nil {
            instantiateTab(for: account)
        }
        if !openTabIDs.contains(account.id) {
            openTabIDs.append(account.id)
        }
        selectedTabID = account.id
    }

    func closeTab(_ accountID: UUID) {
        if let tab = webTabs.removeValue(forKey: accountID) {
            tab.stopLoading()
        }
        urlCancellables.removeValue(forKey: accountID)
        openTabIDs.removeAll { $0 == accountID }
        if selectedTabID == accountID {
            selectedTabID = openTabIDs.last
        }
    }

    func goHome() {
        selectedTabID = nil
    }

    // MARK: - Accounts

    @discardableResult
    func addAccount(name: String) -> Account {
        let account = Account(name: name)
        accounts.append(account)
        return account
    }

    func renameAccount(_ id: UUID, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty,
              let idx = accounts.firstIndex(where: { $0.id == id }) else { return }
        accounts[idx].name = trimmed
    }

    func deleteAccount(_ id: UUID) {
        closeTab(id)
        let dataStoreID = accounts.first(where: { $0.id == id })?.dataStoreID
        accounts.removeAll { $0.id == id }
        if let dsID = dataStoreID {
            Task {
                try? await WKWebsiteDataStore.remove(forIdentifier: dsID)
            }
        }
    }

    // MARK: - Private

    private func instantiateTab(for account: Account) {
        let tab = WebTab(account: account)
        webTabs[account.id] = tab
        urlCancellables[account.id] = tab.$currentURL
            .compactMap { $0 }
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self] url in
                self?.updateLastURL(accountID: account.id, url: url)
            }
    }

    private func updateLastURL(accountID: UUID, url: URL) {
        guard let idx = accounts.firstIndex(where: { $0.id == accountID }) else { return }
        if accounts[idx].lastURL != url {
            accounts[idx].lastURL = url
        }
    }

    // MARK: - Persistence

    private struct PersistedState: Codable {
        var accounts: [Account]
        var openTabIDs: [UUID]
        var selectedTabID: UUID?
    }

    private var storeURL: URL {
        let fm = FileManager.default
        let base = (try? fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? fm.temporaryDirectory
        let dir = base.appendingPathComponent("supabrowse", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("state.json")
    }

    private func saveToDisk() {
        let state = PersistedState(
            accounts: accounts,
            openTabIDs: openTabIDs,
            selectedTabID: selectedTabID
        )
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(state)
            try data.write(to: storeURL, options: .atomic)
        } catch {
            print("supabrowse: save failed - \(error)")
        }
    }

    private func loadFromDisk() {
        guard let data = try? Data(contentsOf: storeURL),
              let state = try? JSONDecoder().decode(PersistedState.self, from: data)
        else { return }

        accounts = state.accounts

        for accountID in state.openTabIDs {
            guard let account = accounts.first(where: { $0.id == accountID }) else { continue }
            instantiateTab(for: account)
        }
        openTabIDs = state.openTabIDs.filter { webTabs[$0] != nil }

        if let sel = state.selectedTabID, openTabIDs.contains(sel) {
            selectedTabID = sel
        } else {
            selectedTabID = openTabIDs.last
        }
    }
}
