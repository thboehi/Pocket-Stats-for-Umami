import SwiftUI

/// The websites of the account in front, pinned ones first.
struct WatchWebsiteList: View {
    @Environment(WatchModel.self) private var model

    var body: some View {
        List {
            if let message = model.errorMessage, model.websites.isEmpty {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            }
            ForEach(model.websites) { website in
                NavigationLink(value: website) {
                    WatchWebsiteRow(website: website, snapshot: model.snapshots[website.id])
                }
            }
            if model.accounts.count > 1 {
                NavigationLink {
                    WatchAccountList()
                } label: {
                    Label("Accounts", systemImage: "person.2")
                        .font(.footnote)
                }
            }
        }
        .navigationTitle(Text(model.account?.title ?? "Pocket Stats"))
        .navigationDestination(for: Website.self) { website in
            WatchWebsiteDetail(website: website)
        }
        .refreshable { await model.load(force: true) }
        // Reloads when the iPhone sends another account, or the reader picks one.
        .task(id: model.account?.id) { await model.load() }
    }
}

struct WatchWebsiteRow: View {
    let website: Website
    let snapshot: WebsiteSnapshot?

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(website.name)
                .font(.footnote.weight(.semibold))
                .lineLimit(1)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(snapshot?.headline ?? "—")
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: snapshot?.value ?? 0))
                Spacer(minLength: 0)
                if let snapshot, snapshot.change != nil {
                    ChangePill(change: snapshot.change, higherIsBetter: snapshot.metric.higherIsBetter,
                               minWidth: 0, font: .system(size: 11, weight: .semibold, design: .rounded))
                }
            }
            .redacted(reason: snapshot == nil ? .placeholder : [])
        }
        .padding(.vertical, 2)
    }
}
