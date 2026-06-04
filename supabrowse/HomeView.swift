import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: AccountStore
    @State private var showingAddSheet = false
    @State private var renamingAccount: Account?
    @State private var deletingAccount: Account?

    private let columns = [GridItem(.adaptive(minimum: 170, maximum: 220), spacing: 16)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header

                if store.accounts.isEmpty {
                    EmptyState { showingAddSheet = true }
                        .frame(maxWidth: .infinity, minHeight: 320)
                } else {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(store.accounts) { account in
                            AccountTile(account: account)
                                .onTapGesture { store.openTab(account: account) }
                                .contextMenu {
                                    Button("Open") { store.openTab(account: account) }
                                    Button("Rename…") { renamingAccount = account }
                                    Divider()
                                    Button("Delete", role: .destructive) {
                                        deletingAccount = account
                                    }
                                }
                        }
                        AddTile { showingAddSheet = true }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(32)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $showingAddSheet) {
            AddAccountSheet { name in
                let account = store.addAccount(name: name)
                store.openTab(account: account)
            }
        }
        .sheet(item: $renamingAccount) { account in
            RenameAccountSheet(account: account) { newName in
                store.renameAccount(account.id, to: newName)
            }
        }
        .alert(
            "Delete \"\(deletingAccount?.name ?? "")\"?",
            isPresented: Binding(
                get: { deletingAccount != nil },
                set: { if !$0 { deletingAccount = nil } }
            ),
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

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("supabrowse")
                    .font(.largeTitle).bold()
                Text("Pick an account to open, or add a new one.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

private struct AccountTile: View {
    let account: Account

    var body: some View {
        VStack(spacing: 12) {
            Circle()
                .fill(LinearGradient(
                    colors: [.green, .teal],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 56, height: 56)
                .overlay(
                    Text(initials(account.name))
                        .font(.title2).bold()
                        .foregroundStyle(.white)
                )
            Text(account.name)
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(maxWidth: .infinity, minHeight: 150)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.2))
        )
        .contentShape(Rectangle())
    }

    private func initials(_ name: String) -> String {
        let parts = name.split(separator: " ").prefix(2)
        let s = parts.map { String($0.prefix(1)) }.joined()
        return s.isEmpty ? String(name.prefix(2)).uppercased() : s.uppercased()
    }
}

private struct AddTile: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("Add Account")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 150)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.4))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        Color.secondary.opacity(0.35),
                        style: StrokeStyle(lineWidth: 1.5, dash: [6])
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

private struct EmptyState: View {
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            Text("No accounts yet")
                .font(.title2)
            Text("Add your first Supabase account to get started.")
                .font(.body)
                .foregroundStyle(.secondary)
            Button(action: onAdd) {
                Label("Add Account", systemImage: "plus")
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct AddAccountSheet: View {
    let onCommit: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Account").font(.title2).bold()
            Text("Each account has its own isolated cookies and session.")
                .font(.callout)
                .foregroundStyle(.secondary)
            TextField("e.g. Work, Personal, Client X", text: $name)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .onSubmit { commit() }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Add") { commit() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(trimmedName.isEmpty)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(minWidth: 380)
        .onAppear { focused = true }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func commit() {
        guard !trimmedName.isEmpty else { return }
        onCommit(trimmedName)
        dismiss()
    }
}
