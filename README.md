# PharmaConnect

A pharmaceutical field-force operating system, built in Flutter.

This build is **UI-complete and backend-free**: every screen, workflow and
business rule runs against in-memory mock repositories. Connecting a real API
is a per-repository swap that touches no UI code.

---

## Running it

```bash
flutter run
```

Any device works. There is no backend to start.

Sign in with any of these IDs and **any non-empty password** — each opens the
app in a different role:

| Employee ID | Role                    | What you see                                    |
| ----------- | ----------------------- | ----------------------------------------------- |
| `MR1001`    | Medical Representative  | Field experience: today's plan, visits, expenses |
| `ASM201`    | Area Sales Manager      | Team exceptions, approvals, target assignment    |
| `RSM301`    | Regional Sales Manager  | Same, over a wider reporting subtree             |
| `NSM401`    | National Sales Manager  | Global scope — the whole organisation            |
| `ADM001`    | Administrator           | Users, master data, geo-fence and approval rules |

Tap a row in the demo-accounts panel to fill the ID — no typing needed.

**Every role is demo-ready.** Managers file their own expenses, leave and tour
plans; ASMs and RSMs run joint field calls so they have a real day plan; and
attendance for non-field roles is present-by-default rather than derived from
visits they never log. The administrator's side menu drops the personal field
modules, which would be empty by definition for a system owner.

Run the tests:

```bash
flutter test
```

---

## Home

Three metric tiles answer the first questions a rep has, in the app palette
rather than a stock dashboard style:

- **Today's Goal** — a progress ring for today's completion, with the month's
  visit count beneath it.
- **Today's Work** — planned visits, and whether that is more or fewer than
  yesterday.
- **Pending Tasks** — open task count, tapping through to the task list.

Below them: a status strip (work type and pace), the **next action** card with
Start Visit, then **eight quick actions** in two rows — My Day Plan, My
Activity, Add Client, Clients Data, Chat, To-Do, Tour Plan, Expenses — and the
rest of the day.

The quick-action tints are grouped by the kind of work, so the colour carries a
little meaning rather than being decoration: teal for planning and executing the
day, sand for client relationships, info for coordination, success for money and
movement. All four are existing palette families; `sandDeep` was added as the
sand family's readable accent so no semantic colour (which must keep meaning
"something needs attention") is borrowed for a decorative tile.

Home stays operational — no sales charts, no target rings (§78); those live in
Business and Reports.

## Navigation

- **Four bottom tabs**, adapting to role: Home · Activity · Business (Team for
  a manager, Master Data for an admin) · Reports. There is no "More" tab — it
  was a menu pretending to be a destination.
- **The side menu** (hamburger, top-left) is the full module index, grouped by
  job: Field operations, Business, Workplace, Management, Administration,
  Account. Everything the old More tab held lives here.
- **The docked "+"** opens role-aware quick actions from any tab.

## Architecture

```
lib/
  core/          theme, routing, location, providers, formatting
  data/          mock dataset + repository implementations
  features/      one folder per product area, presentation-first
  shared/        models, enums, reusable widgets
```

**The rule that matters:** the presentation layer depends only on the
repository *interfaces* in `data/repositories/repositories.dart`. Screens never
know whether they are talking to a mock, a database or an API.

| Concern           | Choice                                                        |
| ----------------- | ------------------------------------------------------------- |
| State             | Riverpod, with sealed state classes rather than boolean flags |
| Navigation        | go_router, with a redirect that is the authorization gate      |
| Data              | Repository interfaces + in-memory mocks                        |
| Models            | Plain immutable Dart classes (no codegen — fast builds)        |
| Charts            | fl_chart, deliberately plain                                   |
| Geo               | Pure-Dart haversine, testable without a device                 |

### Swapping in a real backend

1. Write `ApiActivityRepository implements ActivityRepository`.
2. Change one line in `core/providers/app_providers.dart`.
3. Done. No screen changes.

---

## Design system

Tokens live in `core/theme/` and are the single source of colour, type and
spacing. No screen contains a raw `Color(0x...)` or a hardcoded font size.

Warm ivory `#F7F5F0` · deep teal `#075E63` · sand `#D8C5A3` · graphite `#182027`

Deep teal means **action / active / verified**. Sand means **secondary /
planned**. Semantic colours mean actual states, never decoration. Every status
is communicated by text as well as colour.

Typography uses the platform UI face on purpose — this is an offline-first
field app, and a webfont that resolves over the network is the wrong dependency
for a rep standing in a hospital basement. Drop a bundled face into
`assets/fonts/` and set `AppTypography.fontFamily` to change it.

---

## Business rules worth knowing

**Geo-fence.** Default radius 50 m, policy `warn`. An out-of-range visit is
*allowed* but requires a written reason and is permanently flagged unverified.
Blocking was deliberately not made the default: a rep who genuinely met a doctor
elsewhere would otherwise be unable to record the call at all, which pushes real
work out of the system. Admins can switch to `strict` in Settings → Geo-fence,
where the trade-off is stated on screen.

**Role visibility.** Resolved once at login into a `DataScope`
(self / subtree / global) and applied at the repository layer, not per screen.
An out-of-scope `employeeId` filter returns nothing rather than leaking. This is
the client-side half only — **the server must enforce the same rules.**

**Approvals.** History is append-only. Rejection always requires a reason. A
manager never sees their own requests in their queue.

**Reports.** Every figure is computed from transactional records, never stored
alongside them. The aggregation in `mock_report_repository.dart` is the
executable spec for what the server endpoints must return.

**Offline.** Records carry a client-generated UUID so a retry after a timeout
cannot create duplicates. Toggle Settings → Simulate offline to see the
treatments.

---

## Tests

170 tests, all passing.

| Suite                        | What it protects                                        |
| ---------------------------- | -------------------------------------------------------- |
| `geo_fence_test`             | Haversine, fence evaluation, accuracy tolerance, policy   |
| `order_calculation_test`     | Discount-before-GST ordering, FOC exclusion, achievement  |
| `role_scope_test`            | Hierarchy resolution and repository scope enforcement     |
| `report_aggregation_test`    | Reports reconcile with the underlying records             |
| `screen_smoke_test`          | 54 screens render across three roles and three viewports  |
| `screen_smoke_test` (drawer) | Side menu opens and shows role-correct destinations        |
| `screen_smoke_test` (header) | Brand sits in the top bar, greeting below it, 4 tabs only  |
| `screen_smoke_test` (tiles)  | Home metric tiles + all 8 quick actions, incl. a 320pt phone |
| `demo_data_coverage_test`    | **No screen opens empty for any role** — see below        |
| `demo_data_coverage_test`    | Per-role checks for MR / ASM / RSM / NSM / Admin           |

`demo_data_coverage_test` exists because this build is shown to clients, and
the fastest way to make finished work look broken is a screen that opens empty.
It asserts that every rep has clients, trade clients, activities, a next action
on Home, expenses, travel, leave, orders, targets, tasks and attendance — and
that every chat thread has history, every filter chip has rows, and the
notification bell has something unread. A thin seed now fails CI instead of
surfacing live in a demo. It has already caught one real bug.

The smoke suite exists because unit tests cannot catch a layout error: a widget
that throws during layout in release renders *nothing* and takes the rest of the
list with it. In a test binding the same error is a hard failure. It has already
caught two real bugs.

---

## Not built yet

Stated plainly rather than faked:

- **Real map tiles.** Team Map renders a schematic map surface with real
  projected positions — team pins coloured by pace, client dots for coverage,
  pan/zoom and tap-to-inspect. The streets underneath are generated, not
  cartography; a live tile layer needs a Maps API key and billing. The map
  labels itself "Design preview · positions are real" so nobody is misled.
- **File capture.** Camera, gallery and file pickers are wired as UI with a
  clear message; they need platform permissions and an upload endpoint.
- **Chat** is polling-shaped against mock data. Real-time messaging is its own
  product decision.
- **Push notifications.** In-app notifications work; push needs FCM.
- **Persistence.** The mock store is in memory, so changes reset on restart.
  A SQLite outbox lands with the sync layer.

## Environment note

iOS builds need a full Xcode install — this machine has Command Line Tools only,
so the app was verified on Chrome and via the widget-test suite.
