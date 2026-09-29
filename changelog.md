# Changelog

Version history of **Pocket Stats for Umami** (iOS / iPadOS).
Each entry gives the version (`MARKETING_VERSION`) and the build (`CURRENT_PROJECT_VERSION`). Add new versions at the top.

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
