import SwiftUI

struct RenameAccountSheet: View {
    let account: Account
    let onCommit: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @FocusState private var focused: Bool

    init(account: Account, onCommit: @escaping (String) -> Void) {
        self.account = account
        self.onCommit = onCommit
        self._name = State(initialValue: account.name)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Rename Account").font(.title2).bold()
            TextField("Account name", text: $name)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .onSubmit { commit() }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { commit() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(trimmed.isEmpty || trimmed == account.name)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(minWidth: 380)
        .onAppear { focused = true }
    }

    private var trimmed: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func commit() {
        guard !trimmed.isEmpty else { return }
        onCommit(trimmed)
        dismiss()
    }
}
