import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var store: AccountStore

    @State private var renamingAccount: Account?
    @State private var deletingAccount: Account?

    var body: some View {
        VStack(spacing: 0) {
            Button {
                store.goHome()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle")
                    Text("New Tab")
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .keyboardShortcut("t", modifiers: .command)

            Divider()

            List(selection: $store.selectedTabID) {
                ForEach(store.openWebTabs) { tab in
                    TabRow(
                        tab: tab,
                        onRename: { renamingAccount = account(for: tab.id) },
                        onDelete: { deletingAccount = account(for: tab.id) }
                    )
                    .tag(Optional(tab.id))
                }
            }
            .listStyle(.sidebar)
        }
        .sheet(item: $renamingAccount) { account in
            RenameAccountSheet(account: account) { newName in
                store.renameAccount(account.id, to: newName)
            }
        }
        .alert(
            "Delete \"\(deletingAccount?.name ?? "")\"?",
            isPresented: deletingBinding,
            presenting: deletingAccount
        ) { account in
            Button("Delete", role: .destructive) {
                store.deleteAccount(account.id)
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("Cookies and session for this account will be removed. This cannot be undone.")
        }
    }

    private func account(for id: UUID) -> Account? {
        store.accounts.first(where: { $0.id == id })
    }

    private var deletingBinding: Binding<Bool> {
        Binding(
            get: { deletingAccount != nil },
            set: { if !$0 { deletingAccount = nil } }
        )
    }
}

private struct TabRow: View {
    @ObservedObject var tab: WebTab
    @EnvironmentObject var store: AccountStore
    let onRename: () -> Void
    let onDelete: () -> Void

    private var accountName: String {
        store.accounts.first(where: { $0.id == tab.id })?.name ?? "Tab"
    }

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(LinearGradient(
                    colors: [.green, .teal],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 18, height: 18)
                .overlay(
                    Text(initials(accountName))
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                )

            VStack(alignment: .leading, spacing: 1) {
                Text(accountName)
                    .font(.body)
                    .lineLimit(1)
                if !tab.title.isEmpty {
                    Text(tab.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4)

            Button {
                store.closeTab(tab.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.borderless)
            .help("Close tab")
        }
        .padding(.vertical, 2)
        .contextMenu {
            Button("Close Tab") { store.closeTab(tab.id) }
            Button("Rename…") { onRename() }
            Divider()
            Button("Delete Account", role: .destructive) { onDelete() }
        }
    }

    private func initials(_ name: String) -> String {
        let parts = name.split(separator: " ").prefix(2)
        let s = parts.map { String($0.prefix(1)) }.joined()
        return s.isEmpty ? String(name.prefix(1)).uppercased() : s.uppercased()
    }
}
