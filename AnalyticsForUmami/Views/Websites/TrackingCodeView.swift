import SwiftUI
import UIKit

struct TrackingCodeView: View {
    let website: Website

    @Environment(WebsitesModel.self) private var websites
    @Environment(\.dismiss) private var dismiss
    @State private var copiedItem: String?

    private var snippet: String {
        """
        <script defer src="\(websites.account.trackingScriptURL.absoluteString)" data-website-id="\(website.id)"></script>
        """
    }

    var body: some View {
        List {
            Section {
                Text(snippet)
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(.vertical, 4)
                copyButton("Copy tracking code", value: snippet)
            } header: {
                Text("Tracking code")
            } footer: {
                Text("Paste this code in the <head> section of every page of your website.")
            }

            Section("Website ID") {
                Text(website.id)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                copyButton("Copy ID", value: website.id)
            }

            if let shareID = website.shareId, websites.account.kind != .demo {
                Section {
                    let url = websites.account.kind == .cloud
                        ? Account.cloudWebURL.appending(path: "share").appending(path: shareID)
                        : websites.account.shareURL(for: shareID)
                    Link(destination: url) {
                        Text(url.absoluteString).lineLimit(1)
                    }
                    copyButton("Copy link", value: url.absoluteString)
                } header: {
                    Text("Public share link")
                } footer: {
                    Text("Anyone with this link can see the statistics of this website.")
                }
            }
        }
        .navigationTitle(website.name)
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.success, trigger: copiedItem) { _, new in new != nil }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
            ToolbarItem(placement: .primaryAction) {
                ShareLink(item: snippet)
            }
        }
    }

    private func copyButton(_ title: LocalizedStringKey, value: String) -> some View {
        Button {
            UIPasteboard.general.string = value
            copiedItem = value
            Task {
                try? await Task.sleep(for: .seconds(2))
                if copiedItem == value { copiedItem = nil }
            }
        } label: {
            if copiedItem == value {
                Label("Copied", systemImage: "checkmark")
            } else {
                Label(title, systemImage: "doc.on.doc")
            }
        }
    }
}
