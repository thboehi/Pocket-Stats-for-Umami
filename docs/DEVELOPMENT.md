# Development guide

How Pocket Stats for Umami is built: product context, architecture, the quirks of the Umami API and the rules the code follows.

> **For AI assistants working on this project:** read this file in full before touching the code.

---

## 1. Product context

| | |
|---|---|
| **App Store name** | **Pocket Stats for Umami**. The code, the Xcode project (`AnalyticsForUmami`), the product `Analytics for Umami.app`, the bundle IDs and the App Group keep the original name "Analytics for Umami" on purpose: don't rename them. Under the Home Screen icon the name is **"Umami"** (`CFBundleDisplayName`), so the tool is easy to recognize. |
| **Unofficial** | "Umami" is a trademark of Umami Software, Inc. Always show "Not affiliated with Umami Software, Inc." |
| **Business model** | Paid up-front on the App Store. No in-app purchases, no subscription, no ads, no tracking. |
| **Target** | iOS / iPadOS 26.0+, built with Xcode 27 / iOS 27 SDK, Swift 6 |
| **Languages** | English (source), French, German |

### Features
- Sign in to one or more instances:
  - **self-hosted**: URL, username and password → JWT token;
  - **Umami Cloud**: API key;
  - **share link** (`<server>/share/<id>`): one website, read-only, no account. List, dashboard and realtime work; adding, editing, deleting, resetting and the tracking code are hidden (`Account.canManageWebsites`). The website opens directly;
  - **demo mode**: fictional offline data, required for Apple's review.
- Websites list styled like the Stocks app: visitors for the chosen period (today by default), sparkline and a green/red change badge. Search, sort (name or visitors), pinned websites on top (swipe right). "My websites / All (admin)" switch for admins.
- Accounts in a panel on the left (`AccountsDrawer`): the whole app slides to the right. Opens with the button at the top left or by swiping from the left edge of the list; "Settings" is at the bottom of the panel.
- Website dashboard:
  - live visitors;
  - 6 KPIs with the change from the previous period;
  - views/visitors chart (Swift Charts, finger selection), previous period as a dashed line;
  - breakdowns: pages, entries/exits, titles, referrers, countries, cities, languages, browsers, OS, devices, events;
  - full list with search.
- Periods: today, 24 hours, yesterday, week, 7/30/90 days, month, year, 12 months, or a custom range.
- Realtime view (refreshed every 10 s).
- Website management:
  - create (with team choice), edit, delete;
  - reset statistics (with confirmation);
  - show the tracking code and the share link.
- Widgets inspired by the Stocks app (`Shared/Widgets/`, data in `WebsiteSnapshot`):
  - "Website" small, medium, large: period curve with a gradient, dashed line = average of the previous period, figure, change badge, visitors online; the large one adds 6 KPIs and the top pages;
  - "Websites" (watchlist) medium (3) and large (7): chosen websites, otherwise the pinned ones then the others of the current account;
  - Lock Screen: rectangular (figure + curve), circular (gauge against the previous period), inline;
  - interactive: the period label is a button (today → 24 h → 7 d → 30 d), stored per widget in `WidgetPeriodStore` until the next configuration change;
  - a tap opens the website in the app (deep link).
- "Live visitors" control (Control Center, Lock Screen, Action button): visitors online, opens realtime.
- Siri and Shortcuts (`PocketStatsShortcuts`, phrases translated in `AnalyticsForUmami/AppShortcuts.xcstrings`): "How many visitors on … in Umami" (answer + card), "Open … in Umami".
- Home Screen quick actions (`QuickActions`): realtime of the last opened website and 3 recent websites.
- Figures roll like a mechanical counter (`RollingNumber`), respecting Reduce Motion.
- iPad: two-column `NavigationSplitView`.

### Ideas (not done)
User and team management (admin), Umami reports (funnels, retention, UTM, goals), filters (by URL, country…), custom period comparison, Apple Watch. Live Activities were ruled out: without a push server they only update while the app runs.

---

## 2. Running the project

1. Open `AnalyticsForUmami.xcodeproj` with **Xcode 27**.
2. Scheme `AnalyticsForUmami`, destination: an iOS 27 simulator or a device.
3. ⌘R.

Signing is automatic. The team and identifiers come from `Config/Signing.xcconfig`; to use your own, copy `Config/Local.xcconfig.example` to `Config/Local.xcconfig` (see the README).

**Xcode 27 / macOS 27 notes**
- The Simulator is now called **DeviceHub** (`/Applications/Xcode.app/Contents/Applications/DeviceHub.app`).
- If Xcode crashes at launch (`Symbol not found … CoreDevice / Mercury`), its system components are out of date: run `sudo xcodebuild -license accept && sudo xcodebuild -runFirstLaunch`.

### Command line
```sh
# Simulator build
xcodebuild -project AnalyticsForUmami.xcodeproj -scheme AnalyticsForUmami \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' build

# Release device build (checks signing)
xcodebuild -project AnalyticsForUmami.xcodeproj -scheme AnalyticsForUmami \
  -configuration Release -destination 'generic/platform=iOS' -allowProvisioningUpdates build
```

### Driving the app without touching the screen (DEBUG builds only)
`AnalyticsForUmami/App/DebugLaunch.swift` reads environment variables. With `simctl`, prefix them with `SIMCTL_CHILD_`:
```sh
SIMCTL_CHILD_UMAMI_DEBUG_SERVER=umami.example.com \
SIMCTL_CHILD_UMAMI_DEBUG_USER=… SIMCTL_CHILD_UMAMI_DEBUG_PASSWORD=… \
SIMCTL_CHILD_UMAMI_DEBUG_SCOPE=all \
SIMCTL_CHILD_UMAMI_DEBUG_WEBSITE=<website-id> \
xcrun simctl launch booted <bundle id>
```
The full list of variables is documented at the top of `DebugLaunch.swift`. Highlights:
- `UMAMI_DEBUG_DEMO=1` adds the demo account (websites `demo-bakery`, `demo-blog`, `demo-shop`, `demo-portfolio`);
- `UMAMI_DEBUG_SHARE=<share link>` adds a share link account;
- `UMAMI_DEBUG_LINK=<deep link>` opens an `analyticsforumami://…` link;
- `UMAMI_DEBUG_SCREEN=widgets` shows every widget at its real size with sample data; `sections|realtime|code|edit` scrolls the dashboard or opens that screen (used for the App Store screenshots);
- `UMAMI_DEBUG_PERIODS=today,last30Days` switches the dashboard through these periods, to check that every section follows.

All this code is inside `#if DEBUG` and absent from Release builds. Then `xcrun simctl io booted screenshot out.png` takes a screenshot.

### Test instance
Use your own Umami instance, a share link, or the demo mode. Never test write operations (create, edit, delete, reset) on websites you care about: create a throwaway website (`zz-test-…`) and delete it afterwards.

---

## 3. Architecture

```
AnalyticsForUmami.xcodeproj   Xcode project (synchronized folders: any file added to a folder is compiled)
AnalyticsForUmami/            App target
  App/                        Entry point, AppModel (accounts), WebsitesModel (websites of the current account), DashboardModel (data of one dashboard), RootView, DebugLaunch
  Views/Onboarding/           WelcomeView, AddAccountView
  Views/Accounts/             AccountsDrawer: the page slides to the right and shows the accounts on the left, with "Settings" at the bottom
  Views/Websites/             List, editor, tracking code, delete alert
  Views/Dashboard/            Dashboard, StatsGrid, TrafficChart, MetricSection (+ detail), RealtimeView, RollingNumber
  Views/Settings/             Settings (accounts, about)
  Assets.xcassets             AppIcon (light / dark / tinted)
AnalyticsWidget/              WidgetKit extension target (configuration AppIntent, timeline, views)
Shared/                       Compiled into BOTH targets (app + widget)
  API/                        AnalyticsService (protocol), UmamiClient (REST), CachingService (short cache + shared requests), UmamiError
  Models/                     Website, WebsiteStats, TrafficSeries, MetricItem, MetricType, Account, DateSelection
  Storage/                    AccountStore (App Group UserDefaults), CredentialStore (Keychain)
  Demo/                       DemoService: deterministic fictional data
  Intents/                    App Intents (Siri, Shortcuts, widget configuration)
  Widgets/                    Widget views and data (WebsiteSnapshot), also used by the app
  Support/                    Formatting, DeepLink, LogoMark (logo drawn in SwiftUI)
  Localizable.xcstrings       All strings (en/fr/de)
  PrivacyInfo.xcprivacy       Privacy manifest (no collection, UserDefaults CA92.1 + 1C8F.1)
  SharedAssets.xcassets       AccentColor
Config/                       Info.plists, entitlements, Signing.xcconfig (outside the targets, referenced by build settings)
```

### Principles
- **100 % Apple components**: SwiftUI, `List`, `Form`, `NavigationSplitView`, Swift Charts, `ContentUnavailableView`, native menus and toolbars. The Liquid Glass look of iOS 26/27 comes for free: no heavy custom styling.
- **State**: `@Observable` + `@MainActor`.
  - `AppModel` holds the accounts and the current account.
  - `WebsitesModel` is created per account in `MainSplitView` and injected with `.environment`. The list and the dashboard share the same data: a change shows everywhere.
  - Switching accounts recreates the whole hierarchy (`.id(account.id)`).
- **Loading statistics**:
  - `WebsitesModel.service` is a `CachingService`: reads (stats, series, breakdowns) are kept 60 s and identical requests in flight are shared. The last known values are shown immediately when coming back to a website. Period bounds are rounded to the minute so cache keys match.
  - `DashboardModel` loads **the whole** dashboard (KPIs, chart, first tab of every section) as soon as it opens, in tasks it owns. **Don't** put loading `.task`s back on `List` rows: SwiftUI cancels them when it recycles cells, and sections stayed stuck on their placeholders.
  - On a 401, a single sign-in is made for all parallel requests (`TokenRefresher`). `UmamiClient.send` is `@concurrent`: Keychain and network off the main thread.
  - Network: 15 s request timeout, one retry on a dropped connection, no HTTP cache; the dashboard refreshes when the app comes back to the foreground.
- **Settings › About / Developer**: links are in `AppLinks` (`SettingsView.swift`). "Rate the app" opens the App Store review page once `AppLinks.appStoreID` is set; while it is `nil` the row is hidden. `requestReview` is not used on a button: iOS may ignore it, and a button that does nothing is a rejection reason.
- **Network security**: HTTPS required, except on the local network (`NSAllowsLocalNetworking` + `NSLocalNetworkUsageDescription`, translated in `AnalyticsForUmami/InfoPlist.xcstrings`). A public `http://` server gives `UmamiError.insecureConnection`, with a clear message.
- **Demo**: `.example` domains (reserved) and no "Open website" link in demo, so a reviewer is never sent to someone's real website.
- **Keychain**: `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` (readable by the widget in the background, never restored on another device). The access group is the App Group.
- **Chart**: the selected value (finger or pointer) replaces the legend above the chart. No `annotation` above the bar: the list cell clipped it.
- **Service**: everything goes through the `AnalyticsService` protocol, implemented by `UmamiClient` (network) and `DemoService` (demo). New API feature = add it to both.
- **Security**:
  - passwords, tokens and API keys are in the **Keychain** (`CredentialStore`), with the App Group as access group so the widget can read them;
  - account metadata (no secrets) is in the App Group `UserDefaults`;
  - the password is kept to sign in again automatically on a 401.
- **Privacy**: no request to any third party. Favicons are deliberately not loaded (colored monograms instead), otherwise an external service would learn which domains are tracked.
- **Concurrency**: Swift 6, `SWIFT_APPROACHABLE_CONCURRENCY = YES`, default isolation non-MainActor. Views and models are `@MainActor`, services `Sendable`.
- **Destructive actions**:
  - deleting a website requires **typing its name**;
  - resetting statistics asks for confirmation;
  - signing out deletes nothing on the server.

### Deep links
`analyticsforumami://website/<account-uuid>/<website-id>` (dashboard) and `analyticsforumami://realtime/<account-uuid>/<website-id>` (realtime): used by the widgets, the control, Siri and the quick actions, handled in `AppModel.open(_:)`. `pendingWebsiteID` is consumed by `MainSplitView`, `pendingRealtimeWebsiteID` by the dashboard. App Intents and quick actions run outside the SwiftUI hierarchy: they go through `NavigationRouter.shared.pendingLink`.

### Time series
Umami only returns the buckets (hours/days) that have data. `TrafficSeries.filled(in:unit:)` adds the empty ones: required for the curves and to align the previous period (`DateSelection.previous(of:unit:)`).

---

## 4. Umami API: what to know

Base: `<server>/api` when self-hosted, `https://api.umami.is/v1` for Cloud (header `x-umami-api-key`).

| Use | Endpoint |
|---|---|
| Login | `POST /auth/login {username,password}` → `{token, user}` |
| Share link | `GET /share/:shareId` → `{websiteId, token}` (404 if sharing is disabled). Then header `x-umami-share-token: <token>` instead of `Authorization`; on a 401 the client asks for a new token. Opens `GET /websites/:id`, `stats`, `pageviews`, `metrics`, `active` of the shared website, nothing else |
| Current user | `GET /me` → `{token, shareToken, user}` (v3) |
| My websites | `GET /websites?includeTeams=true&page=&pageSize=` → `{data,count,page,pageSize}` |
| All websites (admin) | `GET /admin/websites` (v3) |
| Teams | `GET /me/teams` (v3), otherwise `GET /teams` (v2) |
| Create / edit / delete | `POST /websites`, `POST /websites/:id`, `DELETE /websites/:id` (soft delete in v3: `deletedAt`) |
| Reset | `POST /websites/:id/reset` |
| Stats | `GET /websites/:id/stats?startAt&endAt` (milliseconds) |
| Time series | `GET /websites/:id/pageviews?startAt&endAt&unit=hour|day|month&timezone=` → `{pageviews:[{x,y}], sessions:[{x,y}]}` |
| Breakdowns | `GET /websites/:id/metrics?type=…&limit=` → `[{x,y}]` (`city` adds `country`) |
| Active visitors | `GET /websites/:id/active` |

**v2 / v3 differences handled by the client**
- `stats`: flat numbers plus `comparison:{…}` in v3; `{pageviews:{value,prev}}` in v2. See `WebsiteStats.parse`.
- `metrics`: v3 uses `type=path` (`url` returns a 400), v2 uses `url`. On a 400 the client retries with the v2 name.
- `active`: `{visitors}` in v3, `{x}` or `[{x}]` in v2.
- The series date `x` is `"yyyy-MM-dd HH:mm:ss"` in the requested time zone (v3), or ISO 8601.
- Some numbers arrive as strings (`"pageviews":"37"`): `JSONNumber.double` handles both.

Derived metrics:
- bounce rate = `bounces / visits`;
- visit duration = `totaltime / visits` (seconds).

---

## 5. Localization

- All strings are in `Shared/Localizable.xcstrings` (en/fr/de). Write English text in the code (`Text("…")`, `String(localized:)`, `LocalizedStringResource`).
- Plurals use automatic grammar agreement: `Text("^[\(count) visitor](inflect: true)")`, translated as `^[%lld visiteur](inflect: true)`.
- After adding text, open the catalog in Xcode: new keys appear after a build. Translate them into French **and** German.

---

## 6. Versioning

- `MARKETING_VERSION` changes with every public version, `CURRENT_PROJECT_VERSION` (build) with every upload.
- Add an entry at the top of `changelog.md` for every published version.
