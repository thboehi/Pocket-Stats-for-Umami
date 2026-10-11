# Changelog

Version history of **Pocket Stats for Umami** (iOS, iPadOS and watchOS).
Each entry gives the version (`MARKETING_VERSION`) and the build (`CURRENT_PROJECT_VERSION`). Add new versions at the top.

---

## 1.3 (build 6), unreleased

Pocket Stats on the wrist.

### New
- **An Apple Watch app.** Your websites, their figures for the period you pick, the curve of the day and who is online, without taking the iPhone out. It is part of the same app: one purchase, one install.
  - The list shows one figure per website, pinned ones first, like the iPhone.
  - A website screen adds the hourly curve with the previous period dashed behind it, the visitors online right now, and views, visits, bounce rate, visit duration and views per visit, each with its change.
  - Today, 24 hours, 7 days or 30 days, chosen on the watch and kept there.
  - Several servers: the watch follows the one selected on the iPhone, and can switch by itself.
- **The watch works on its own.** It talks to your Umami server directly over Wi-Fi or cellular, and signs in again by itself when its session expires: the iPhone only has to be there the first time. Your servers and credentials travel straight from the iPhone to the watch over an encrypted link, never through anyone's server, and land in the watch's own Keychain. Signing out of an account on the iPhone erases it from the watch too.
- **Complications**, in the four shapes a watch face offers: rectangular (figure, trend and curve), circular (a ring against the previous period), corner and inline. Two of them: a website's figure for the period you pick, and how many visitors are on it right now. Tapping one opens that website in the app.
  - The watch face gallery offers them ready to use; configuring one is only needed to follow another website or another metric.
  - Left unconfigured, a complication follows the first pinned website of the server in front, like the iPhone widgets.

### Technical
- New `AnalyticsWatch` target, embedded in the iOS app: same App Store record, same version and build, one review. The complications are a second target, `AnalyticsWatchWidgetExtension`, inside the watch app.
- Both ends of the sync are in `Shared/Storage/WatchLink.swift`.
- `Shared/` now compiles for watchOS: the UIKit system colours became `Color.positive` / `.negative` / `.muted`, the Home Screen widget families are behind `#if os(iOS)`, and `.accessoryCorner` behind `#if os(watchOS)`.
- `AppIntentTimelineProvider.recommendations()` has no default on watchOS: a face gallery needs a list of ready-made complications, so both providers return one.

---

## 1.2 (build 5), unreleased

Widgets you configure, and widgets that survive a tinted Home Screen.

### New
- **Choose the metric.** Every widget now shows the figure you pick instead of visitors only: visitors, views, visits, bounce rate, visit duration or views per visit. The headline, the curve and the comparison follow it.
  - A rise in the bounce rate is red, a fall is green. Everywhere else, up is green.
  - Umami only serves two curves (views and sessions), so the bounce rate and the visit duration draw the visits curve and label it, rather than passing it off as their own.
- **Choose the details.** The bottom of the large "Website" widget is no longer locked to the top pages: pick top referrers, countries, browsers, devices, operating systems or events — or nothing. Each row carries a bar for its share.
- **Watchlist options.** Number of rows (2 to 8, within what the size can hold), order (as configured, highest first, biggest change, by name), and a small size showing 2 websites.
- **Comparison off.** A switch hides the change badge and the dashed line.
- **Three new widgets.**
  - **Ranking** (small, medium, large): one ranking of one website — top pages, referrers, countries, browsers, devices, operating systems or events — with a bar for each row's share. 3, 4 or 8 rows depending on the size. One request, the cheapest widget of the bundle.
  - **Live** (small, medium, Lock Screen): how many visitors are on the site right now, and on the medium one what they opened in the last half hour. Umami serves no minute-by-minute curve, so the widget keeps its own: every refresh records the count it read, and the bars show the hours it has collected. Bars rather than a line, because the samples are spaced by whatever the reload budget allowed and a line would invent what happened in between.
  - **Total** (small, medium): every website of an account added up into one figure, with the biggest contributors. The raw counters are summed before the ratios are computed, so the bounce rate and the visit duration are properly weighted — a site with 10 visits never counts as much as one with 10 000.

### Fixes
- **The sign-out confirmation appeared anywhere but where it should.** It was a confirmation
  dialog, which anchors itself to whatever presented it; inside the accounts panel — a drawer with
  the whole app slid aside — that anchor landed off the panel. It is an alert now, centred on the
  screen whatever the drawer is doing.
- German: three strings addressed the reader as "Sie" while the rest of the app says "du".
- **The change badge was an empty white rectangle on a tinted or clear Home Screen.** The badge was a coloured shape with white text on it; those styles flatten every fill to a single colour, so the text landed on its own background. Outside full colour the badge now drops its background and shows an arrow with the percentage. Same cause, same fix, on the Lock Screen.
- What the system tints (`.widgetAccentable()`) is now the figure and the curve, the parts worth highlighting, instead of the site name and the badge.

### Performance
- **Refreshes now land where they matter.** Every widget asked to be reloaded every 15 minutes, which is 96 times a day when WidgetKit grants roughly 40 to 70: the extra requests were simply dropped, at hours the system picked. The interval now follows what is being shown — 20 minutes when someone is on the site, 45 when nobody is, 1 hour on the 7 and 30 day periods whose buckets barely move, 3 hours between 1 and 6 in the morning. The Live widget keeps a shorter leash (15 minutes).
- **One request less per website, everywhere.** The dashed line is the previous period's average per bucket, and the stats call already returns that period's totals: dividing them by the number of buckets gives the same line without a second traffic request. A large watchlist of 8 websites went from 24 requests per refresh to 16.
- The small watchlist draws no curve, so it no longer asks for one: one request per website instead of two.
- **Smart Stack.** Widgets now rate their own entries (`TimelineEntryRelevance`): a website that moved a lot, or that has people on it right now, comes up before one that has been flat all day.

### Technical
- Widget configuration enums live in `Shared/Widgets/WidgetOptions.swift` (`WidgetMetric`, `WidgetBreakdown`, `WatchlistSort`, `WatchlistRows`). Widgets already on a Home Screen keep working: every new parameter has a default.
- Reload intervals and relevance scores are in `Shared/Widgets/WidgetRefresh.swift`; the sampled realtime history is in `Shared/Storage/LiveHistoryStore.swift` (App Group, 24 samples, dropped after a day).
- New snapshots next to `WebsiteSnapshot`: `BreakdownSnapshot`, `LiveSnapshot`, `TotalSnapshot`.
- The debug widget gallery (`UMAMI_DEBUG_SCREEN=widgets`) has a rendering-mode picker, and `UMAMI_DEBUG_GALLERY_MODE=tinted|lockscreen` opens it straight in one of them. The tinted mode is where colour-only designs break. `UMAMI_DEBUG_GALLERY=center` scrolls to the middle.

---

## 1.1 (build 3), September 2026

A big visual and functional update.

### New
- **Stocks-style widgets**
  - "Website" widget in small, medium and large, with:
    - the period curve, filled with a gradient;
    - a dashed line for the average of the previous period;
    - the number of visitors;
    - a green or red change badge;
    - the visitors online.
  - The large widget adds 6 key metrics and the most viewed pages.
  - New "Websites" widget (watchlist) in medium (3 websites) and large (7 websites). By default: the pinned websites, then the other websites of the account.
  - Lock Screen:
    - rectangular: figure and curve;
    - circular: gauge against the previous period;
    - inline.
  - Interactive widgets: tapping the period switches from today to 24 hours, then 7 and 30 days.
- **Share links**: a new kind of account. Paste a `…/share/…` URL to follow one website without an account, read-only.
- **Siri and Shortcuts**: "How many visitors on … in Umami" (answer and card), "Open … in Umami". In English, French and German.
- **"Live visitors" control** (Control Center, Lock Screen, Action button): shows the visitors online and opens realtime.
- **Quick actions** (touch and hold the icon): realtime of the last opened website and 3 recent websites.
- **Mechanical-counter figures**: when loading and on every change, digits roll like the wheels of a counter, with a slight bounce, from right to left (dashboard, websites list, realtime). Respects Reduce Motion.
- **Pinned websites** at the top of the list (swipe right) and **sorting** by name or by visitors.
- **Websites list period**: today by default, changeable from the list header (7 days, 30 days, this year…). Figures, curves, changes and sorting follow the period.

### Improvements
- Redesigned websites list: sparkline, visitors and change badge on every row. While loading, gray placeholders appear, then the figures fade in. In narrow columns (iPad sidebar) the curve is hidden to leave room for the name.
- Dashboard chart: the previous period is shown as a dashed line.
- Accounts in a side panel on the left: the whole app slides to the right, with rounded corners, a shadow and a depth effect. Opens with the button or by swiping from the left edge. "Settings" is at the bottom of the panel.
- Settings: header with the app icon, name and version.
- The name of the active account shows under the "Websites" title.

### Fixes
- Dashboard: changing the period reloads everything immediately, without pull to refresh. Loading no longer depends on what is on screen; the old figures stay visible, dimmed, then roll to the new ones.
- Network: a request stuck on a dead connection (common when coming back from the background) fails after 15 s instead of 60 and is retried once. No more HTTP cache. The dashboard refreshes when coming back to the app.
- Dashboard: changing the period now reloads every breakdown, including the tab chosen in a section scrolled out of view (cities, OS, entries…) and cached data.
- Chart: the previous period is aligned on the same hours or days (today compared with yesterday at the same hours, 7 days with the 7 days before).
- Websites list: pull to refresh reloads the figures. Before, rows could stay gray.
- Resetting a website's statistics also updates its row in the list.
- Realtime: refreshes no longer pile up in memory.

### Technical
- Time series are completed with the hours and days that have no data (`TrafficSeries.filled`), for correct curves and comparisons.
- New deep link: `analyticsforumami://realtime/<account>/<website>`.
- Code shared between the app and the widget: `Shared/Widgets/` and `Shared/Intents/`.
- Demo mode: websites grow steadily, and "Today" is compared with yesterday at the same time.

---

## 1.0 (build 1), September 2026

First version.

- Sign in to a self-hosted Umami instance (credentials) or to Umami Cloud (API key). Several accounts.
- Offline demo mode with sample websites.
- Websites list with search and today's visitors. Administrators see every website of the instance.
- Dashboard:
  - live visitors;
  - 6 metrics compared with the previous period;
  - views and visitors chart;
  - breakdowns: pages, sources, countries, cities, languages, browsers, OS, devices, events.
- Preset or custom periods.
- Realtime view, refreshed every 10 seconds.
- Website management: create, edit, delete, reset, tracking code.
- Small and medium widgets, and Lock Screen widgets.
- iPad: two-column sidebar.
- In English, French and German. No data collection.
