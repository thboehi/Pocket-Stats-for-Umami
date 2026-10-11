import SwiftUI

/// Only shown when the iPhone sent more than one server.
struct WatchAccountList: View {
    @Environment(WatchModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List(model.accounts) { account in
            Button {
                model.select(account)
                dismiss()
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(account.title)
                            .font(.footnote.weight(.semibold))
                            .lineLimit(1)
                        if let subtitle = account.subtitle {
                            Text(subtitle)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 4)
                    if account.id == model.account?.id {
                        Image(systemName: "checkmark")
                            .font(.caption)
                            .foregroundStyle(Color.accentColor)
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .navigationTitle("Accounts")
    }
}
