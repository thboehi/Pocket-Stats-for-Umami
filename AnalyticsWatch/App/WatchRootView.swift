import Combine
import SwiftUI

/// The watch keeps its own copy of the accounts: an App Group is shared between
/// an app and its extensions on one device, never between the iPhone and the
/// watch. Until the iPhone has sent them over, there is nothing to show.
struct WatchRootView: View {
    @State private var model = WatchModel()
    @State private var path: [Website] = []

    var body: some View {
        NavigationStack(path: $path) {
            #if DEBUG
            if WatchDebugLaunch.showsComplicationGallery {
                WatchComplicationGallery()
            } else if model.accounts.isEmpty {
                WatchPairingView()
            } else {
                WatchWebsiteList()
            }
            #else
            if model.accounts.isEmpty {
                WatchPairingView()
            } else {
                WatchWebsiteList()
            }
            #endif
        }
        .environment(model)
        .task {
            #if DEBUG
            guard !WatchDebugLaunch.isDemo else { return }
            #endif
            WatchLink.shared.activate()
        }
        .onReceive(NotificationCenter.default.publisher(for: .watchSyncDidChange)) { _ in
            model.readStores()
        }
        // A complication was tapped. Its website may not be loaded yet, so the
        // link is kept until the list it belongs to arrives.
        .onOpenURL { url in
            guard let link = DeepLink(url: url) else { return }
            model.open(link)
            if let website = model.takePendingWebsite() { path = [website] }
        }
        .onChange(of: model.websites) {
            if let website = model.takePendingWebsite() { path = [website] }
        }
        #if DEBUG
        .task(id: model.websites.count) {
            if path.isEmpty, let website = WatchDebugLaunch.website(in: model) { path = [website] }
        }
        #endif
    }
}

struct WatchPairingView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                LogoMark()
                    .frame(width: 22, height: 24)
                    .foregroundStyle(Color.accentColor)
                Text("Open Pocket Stats on your iPhone to send your servers to the watch.")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button("Check again") { WatchLink.shared.requestSync() }
                    .buttonStyle(.bordered)
                    .font(.footnote)
            }
            .padding(.vertical, 8)
        }
    }
}

#Preview {
    WatchRootView()
}
