import SwiftUI

struct WelcomeView: View {
    @Environment(AppModel.self) private var model
    @State private var isShowingSignIn = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 36) {
                    VStack(spacing: 16) {
                        AppBadge()
                        Text("Pocket Stats for Umami")
                            .font(.largeTitle.bold())
                            .multilineTextAlignment(.center)
                        Text("The statistics of your Umami server, in a fast and native app.")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)

                    VStack(alignment: .leading, spacing: 22) {
                        FeatureRow(systemImage: "dot.radiowaves.left.and.right", color: .green,
                                   title: "Live visitors", text: "See who is on your websites right now.")
                        FeatureRow(systemImage: "chart.bar.xaxis", color: .accentColor,
                                   title: "Detailed reports", text: "Pages, sources, countries, devices and events.")
                        FeatureRow(systemImage: "square.and.pencil", color: .orange,
                                   title: "Website management", text: "Add websites and copy their tracking code.")
                        FeatureRow(systemImage: "rectangle.3.group", color: .purple,
                                   title: "Widgets", text: "Keep an eye on your visitors from the Home Screen.")
                    }
                    .frame(maxWidth: 460, alignment: .leading)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 12) {
                    Button {
                        isShowingSignIn = true
                    } label: {
                        Text("Connect to Umami")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button("Explore with demo data") {
                        model.addDemoAccount()
                    }
                    .controlSize(.large)

                    Text("Not affiliated with Umami Software, Inc.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: 460)
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
            }
            #if DEBUG
            .task { if DebugLaunch.screen == "share" { isShowingSignIn = true } }
            #endif
            .sheet(isPresented: $isShowingSignIn) {
                AddAccountView()
            }
        }
    }
}

private struct FeatureRow: View {
    let systemImage: String
    let color: Color
    let title: LocalizedStringKey
    let text: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(text).foregroundStyle(.secondary)
            }
        }
    }
}

struct AppBadge: View {
    var size: CGFloat = 96

    var body: some View {
        LogoMark()
            .fill(.white)
            .frame(width: size * 0.53, height: size * 0.58)
            .frame(width: size, height: size)
            .background(
                LinearGradient(colors: [Color(red: 0.41, green: 0.38, blue: 0.98), Color(red: 0.15, green: 0.13, blue: 0.50)],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                in: .rect(cornerRadius: size * 0.225, style: .continuous)
            )
            .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
            .accessibilityHidden(true)
    }
}

#Preview {
    WelcomeView()
        .environment(AppModel())
}
