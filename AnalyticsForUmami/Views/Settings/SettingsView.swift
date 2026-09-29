import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "–"
        let build = info?["CFBundleVersion"] as? String ?? "–"
        return "\(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 10) {
                        AppBadge(size: 64)
                        VStack(spacing: 2) {
                            Text("Pocket Stats for Umami")
                                .font(.title3.bold())
                            Text("Version \(appVersion)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .combine)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16))
                }

                Section("About") {
                    if let url = AppLinks.writeReview {
                        Link(destination: url) {
                            Label("Rate the app", systemImage: "star")
                        }
                    }
                    Link(destination: AppLinks.privacyPolicy) {
                        Label("Privacy policy", systemImage: "hand.raised")
                    }
                    Link(destination: AppLinks.support) {
                        Label("Help & support", systemImage: "questionmark.circle")
                    }
                }

                Section("Developer") {
                    Link(destination: AppLinks.developer) {
                        LabeledContent {
                            Text(verbatim: "thbo.ch")
                        } label: {
                            Label {
                                Text(verbatim: "Thomas Boehi")
                            } icon: {
                                Image(systemName: "person.crop.circle")
                            }
                        }
                    }
                    Link(destination: AppLinks.studio) {
                        LabeledContent {
                            Text(verbatim: "nckl.ch")
                        } label: {
                            Label {
                                Text(verbatim: "nickel.")
                            } icon: {
                                Image(systemName: "building.2")
                            }
                        }
                    }
                }

                Section("Umami") {
                    Link(destination: URL(string: "https://umami.is/docs")!) {
                        Label("Umami documentation", systemImage: "book")
                    }
                    Link(destination: URL(string: "https://github.com/umami-software/umami")!) {
                        Label("Umami on GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                }

                Section {
                } footer: {
                    Text("Pocket Stats for Umami is an independent app, not affiliated with Umami Software, Inc. It connects directly to your server and does not collect any data.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

/// External links shown in Settings. The developer links carry UTM parameters
/// so visits from the app show up as such in Umami.
enum AppLinks {
    /// Apple ID of the app in App Store Connect (App Information › Apple ID).
    /// The "Rate the app" row stays hidden until it is set.
    static let appStoreID: String? = nil

    static var writeReview: URL? {
        appStoreID.flatMap { URL(string: "https://apps.apple.com/app/id\($0)?action=write-review") }
    }

    static let privacyPolicy = URL(string: "https://thbo.ch/pocket-stats/privacy")!
    static let support = URL(string: "https://thbo.ch/pocket-stats/support")!
    static let developer = tracked("https://thbo.ch/")
    static let studio = tracked("https://nckl.ch/")

    private static func tracked(_ address: String) -> URL {
        var components = URLComponents(string: address)!
        components.queryItems = [
            URLQueryItem(name: "utm_source", value: "pocket-stats-ios"),
            URLQueryItem(name: "utm_medium", value: "app"),
            URLQueryItem(name: "utm_campaign", value: "about"),
        ]
        return components.url!
    }
}
