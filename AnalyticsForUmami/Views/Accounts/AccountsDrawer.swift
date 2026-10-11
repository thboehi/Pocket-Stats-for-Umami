import SwiftUI

/// Slides the whole app to the right to reveal the accounts panel on the left,
/// like a sidebar. It follows the finger: swipe from the left edge of the
/// website list to open it, drag the app back or tap it to close.
struct AccountsDrawer<Content: View>: View {
    @ViewBuilder let content: Content

    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var containerWidth: CGFloat = 0
    /// Horizontal translation of the drag in progress.
    @State private var dragOffset: CGFloat = 0

    private var panelWidth: CGFloat { max(min(320, containerWidth * 0.84), 1) }
    private var isOpen: Bool { model.isShowingAccounts }

    /// 0 closed, 1 open, following the finger while dragging.
    private var progress: CGFloat {
        let base: CGFloat = isOpen ? 1 : 0
        return min(max(base + dragOffset / panelWidth, 0), 1)
    }

    /// Rounded like the screen while the app is moved aside, square at rest.
    private var appShape: some Shape {
        RoundedRectangle(cornerRadius: (containerWidth > 500 ? 18 : 44) * min(progress * 4, 1), style: .continuous)
    }

    private var animation: Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : .smooth(duration: 0.38)
    }

    var body: some View {
        ZStack(alignment: .leading) {
            AccountsPanel()
                .frame(width: panelWidth)
                // Slight parallax: the panel comes from under the app.
                .offset(x: reduceMotion ? 0 : -panelWidth * 0.3 * (1 - progress))
                .opacity(progress > 0 ? 1 : 0)
                .accessibilityHidden(!isOpen)

            // Shadow on a plain shape, so the app itself isn't re-rendered for it.
            appShape
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.22 * progress), radius: 30, x: -4)
                .offset(x: panelWidth * progress)
                .opacity(progress > 0 ? 1 : 0)
                .allowsHitTesting(false)

            content
                .clipShape(appShape)
                .overlay {
                    // Always there so the dimming fades with the movement;
                    // only catches touches while open.
                    Color.black.opacity(0.1 * progress)
                        .clipShape(appShape)
                        .contentShape(.rect)
                        .onTapGesture { setOpen(false) }
                        .gesture(dragGesture)
                        .allowsHitTesting(isOpen)
                        .accessibilityHidden(!isOpen)
                        .accessibilityLabel(Text("Close accounts"))
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction { setOpen(false) }
                }
                .offset(x: panelWidth * progress)
                .gesture(EdgePanGesture(isEnabled: !isOpen && model.canOpenAccountsFromEdge,
                                        onChange: { dragOffset = max($0, 0) },
                                        onEnd: { endDrag(translation: $0, velocity: $1) }))
                .accessibilityHidden(isOpen)
        }
        .ignoresSafeArea(.container)
        .background(Color(.systemGroupedBackground))
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { containerWidth = $0 }
        .animation(animation, value: isOpen)
        .onChange(of: model.currentAccount?.id) { setOpen(false) }
        #if DEBUG
        .task {
            guard ["accounts", "signout"].contains(DebugLaunch.screen) else { return }
            try? await Task.sleep(for: .seconds(1.5))
            model.isShowingAccounts = true
        }
        #endif
    }

    /// Dragging the open app back to the left.
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { dragOffset = min($0.translation.width, 0) }
            .onEnded { endDrag(translation: $0.translation.width, velocity: $0.velocity.width) }
    }

    /// Settles open or closed depending on where the finger was going.
    private func endDrag(translation: CGFloat, velocity: CGFloat) {
        let projected = (isOpen ? panelWidth : 0) + translation + velocity * 0.2
        setOpen(projected > panelWidth / 2)
    }

    private func setOpen(_ open: Bool) {
        withAnimation(animation) {
            model.isShowingAccounts = open
            dragOffset = 0
        }
    }
}

/// Swipe from the left edge of the screen, without stealing taps from the
/// content (a plain `DragGesture` on an edge strip would).
private struct EdgePanGesture: UIGestureRecognizerRepresentable {
    let isEnabled: Bool
    let onChange: (CGFloat) -> Void
    let onEnd: (_ translation: CGFloat, _ velocity: CGFloat) -> Void

    func makeUIGestureRecognizer(context: Context) -> UIScreenEdgePanGestureRecognizer {
        let recognizer = UIScreenEdgePanGestureRecognizer()
        recognizer.edges = .left
        return recognizer
    }

    func updateUIGestureRecognizer(_ recognizer: UIScreenEdgePanGestureRecognizer, context: Context) {
        recognizer.isEnabled = isEnabled
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIScreenEdgePanGestureRecognizer, context: Context) {
        let translation = recognizer.translation(in: recognizer.view).x
        switch recognizer.state {
        case .changed:
            onChange(translation)
        case .ended, .cancelled, .failed:
            onEnd(recognizer.state == .ended ? translation : 0, recognizer.velocity(in: recognizer.view).x)
        default:
            break
        }
    }
}

/// The accounts, "Add account" and Settings, shown by `AccountsDrawer`.
private struct AccountsPanel: View {
    @Environment(AppModel.self) private var model
    @State private var isShowingAddAccount = false
    @State private var isShowingSettings = false
    @State private var accountPendingRemoval: Account?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(model.accounts) { account in
                        AccountRow(account: account, isCurrent: account.id == model.currentAccount?.id) {
                            if account.id == model.currentAccount?.id {
                                model.isShowingAccounts = false
                            } else {
                                model.select(account)
                            }
                        }
                        .swipeActions {
                            Button("Sign Out", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                                accountPendingRemoval = account
                            }
                        }
                        .contextMenu {
                            Button("Sign Out", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                                accountPendingRemoval = account
                            }
                        }
                    }
                    Button("Add account", systemImage: "plus") { isShowingAddAccount = true }
                } footer: {
                    Text("Swipe an account to sign out.")
                }
            }
            .navigationTitle("Accounts")
            .safeAreaInset(edge: .bottom) {
                Button {
                    isShowingSettings = true
                } label: {
                    Label("Settings", systemImage: "gearshape")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
        }
        #if DEBUG
        .task {
            if DebugLaunch.screen == "settings" { isShowingSettings = true }
            if DebugLaunch.screen == "signout" {
                try? await Task.sleep(for: .seconds(2))
                accountPendingRemoval = model.currentAccount
            }
        }
        #endif
        .sheet(isPresented: $isShowingAddAccount) {
            AddAccountView()
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView()
        }
        // An alert rather than a confirmation dialog: a dialog anchors itself to
        // whatever presented it, and inside the drawer — a panel with the whole
        // app slid aside — that anchor lands off the panel. An alert is centred
        // on the window whatever its presenter is doing.
        .alert(
            "Sign out of \(accountPendingRemoval?.title ?? "")?",
            isPresented: Binding(get: { accountPendingRemoval != nil }, set: { if !$0 { accountPendingRemoval = nil } }),
            presenting: accountPendingRemoval
        ) { account in
            Button("Sign Out", role: .destructive) { model.remove(account) }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("Your credentials will be removed from this device. Nothing is deleted on the server.")
        }
    }
}

private struct AccountRow: View {
    let account: Account
    let isCurrent: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: account.kind.systemImage)
                    .frame(width: 28)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(account.title)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if let subtitle = account.subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                if isCurrent {
                    Image(systemName: "checkmark")
                        .fontWeight(.semibold)
                        .foregroundStyle(.tint)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }
}
