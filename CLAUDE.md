# Mr Sales — working agreements

Guardrails for anyone (human or AI) extending this codebase. These are the
rules the existing code already follows; breaking them creates inconsistency
that is expensive to unwind later.

## Design system

- **Never hardcode a colour, font size, or spacing value in a widget.** Use
  `AppColors`, `AppTypography`, `AppSpacing`, `AppRadius`, `AppSizes` from
  `lib/core/theme/`. If a token is missing, add it there — do not inline a
  `Color(0x...)` or a `fontSize:`.
- The palette is **Dr.Swift's own brand sheet**, on white. The values are not
  sampled from screenshots or invented: they are the CSS custom properties
  published on drswift.in (`--color-blue`, `--color-ink`, `--color-muted`,
  `--color-line`, `--color-hero-purple`, `--color-green-bright-text`,
  `--concern-accent`, …), and each token names the variable it came from. Where
  the site publishes both a colour and a *text* variant of it, use the text
  one — that is the variant Dr.Swift themselves darkened to be readable.
  **Exactly one hue is off-sheet** (`ModulePalette.hr`) and the token says why.
- The ground is near-white (`--color-soft`), **not `#FFFFFF`**: a white card on
  a pure-white page is 1.0:1, and the card stack on Home is the product.
  Colour arrives through the six **modules**; the chrome — buttons, active tab,
  progress — stays `brand` blue, so there is one action colour and six identity
  colours. `design/palettes/` keeps the previous deep-teal-on-green palette
  whole, with a README on restoring it.
- **Anything carrying meaning clears 4.5:1** against the surface behind it.
  Check before adding a colour — `AppColors` documents the ratios that matter.
- **A fill is not a foreground.** `sand`, `star` and `mint` are light
  enough to carry dark ink and nothing else; as an icon or a word they measure
  under 3:1. Each has a paired deep ink for that job.
- **A module states its hue once — on the chip.** Not the card, not the label.
  An earlier version tinted all three: eighteen colour statements on Home, and
  beside the apps this is measured against it read as a paint box rather than a
  system. Apple and Uber Eats are close to monochrome; their colour lives in
  content, and the little that sits in chrome is confined to small marks.
- **Hierarchy comes from the neutral ramp, never from hue.** `grey50`–`grey900`
  is the palette's spine and `textPrimary`, `textSecondary` and
  `surfaceSecondary` are aliases into it, so there is one set of values. If you
  are reaching for a colour to separate two things, reach for a grey step.
- **Each module owns a hue (`ModulePalette`); the semantic set means state.**
  A quick-action tile carries its hue three times — pastel card, saturated
  chip, label in the same ink — which is what makes the grid read as six
  *places* rather than six icons. This was collapsed to a single green once, on
  the argument that the icon and the word already say which module; that
  produced six identical squares, which is a list. Do not collapse it again
  without reading why it came back.
- **A module hue and a semantic colour may share a value.** `travel` is `brand`
  green and `clients` sits beside `warning` amber. They stay legible because a
  badge is a pill with a word in it and a tile is a chip with a label under it
  — never because of hue.
- **Never communicate state by colour alone** — every badge carries text.
- **There is one calendar.** `MonthCalendar` — attendance, the day plan, the
  expense claim and the tour plan are the same widget with different data. Each
  had its own grid, its own cell and its own header once, and they drifted in
  every one of those: one clipped its dates at large text sizes because it
  sized rows from an aspect ratio, one drew rounded squares while the rest drew
  circles, one put the month on the left with both arrows bunched right. A day
  is a **tinted disc, the number, and a small dot** for what happened on it —
  the disc says *something is here*, the dot says *what*, and the legend under
  the grid names every colour, so a calendar never speaks by hue alone. The
  screen supplies a `CalendarDay` per date; it never lays one out itself.
- **A calendar has four colours and no more**, and each one means the same
  thing on every screen: `calendarPlanned` blue is *ahead of you* (a planned
  visit, a working tour day, a claim not yet settled, a company holiday on the
  attendance sheet), `calendarDone` green is *happened and accepted*,
  `calendarOff` orange is *not a working day*, `calendarProblem` red is
  *missed, absent or rejected*. A blank day stays blank — the four are read
  against it. Between them the four calendars had grown six hues, with amber
  meaning "leave" on one screen and "above allowance" on the next; the excess
  is a word on the row, not a fifth colour on the grid. `palette_contrast_test`
  holds each one at 4.5:1 and holds them apart from each other, because the
  mark carrying them is a 5pt dot.
- **Anything holding a single mark is a circle.** Wells, avatars, icon
  buttons, the `+` sheet's chips, and every **day cell in all three
  calendars** — Calendar, Attendance and the expense claim. Each of those
  calendars had drawn its own rounded square, and one of them going round on
  its own is how a set of screens stops looking like one app. Rounded
  rectangles are for things you *read* — cards, fields, sheets — not for
  things you *press* or single glyphs.
  - The one deliberate exception is a **receipt thumbnail**: it stands in for
    a photograph, and photographs are not round.
- **A well is a circle.** `IconWell` defaults to `size / 2` and nothing should
  override it. Home's tiles were discs and the other twenty-six wells were
  rounded squares — one object, two shapes, and the odd one out was the screen
  the app gets judged on. A circle already means *a person* here (`AppAvatar`
  is a disc with initials); the two coexist because they never carry the same
  content and a client row shows one of each side by side. The corollary is a
  rule: **never put a letter in a well, or an icon in an avatar.**
  - The `SkeletonList` placeholder was already a pill, so the loading state
    now matches what it is standing in for — it did not before.
- **Module icons go through `IconWell`, and the well is dark.** A gradient from
  the module ink to a darkened copy of it, a **pure white** glyph, one tight
  bloom on the glyph's strokes and a halo in its own colour. Three things are
  load-bearing and all three are easy to undo by accident:
  - The gradient runs **deep → deeper**, never mid-tone → deep. A mockup draws
    a light fill with a white glyph; that measures 2.2:1 on amber and 2.0:1 on
    lime. Anchoring the light end at the ink puts the floor at the top of the
    well, where every hue clears 4.5:1.
  - The glyph is **white**, not near-white. It was lerped 0.94 toward white on
    the argument that a tinted glyph reads as *lit* rather than as
    white-on-a-dark-chip. On a 42pt chip what it actually read as was a white
    that had gone slightly grey. A review said the icons were "not clear
    white"; it was right. (The old floor still applies and is now trivially
    met: 0.88 put the tightest inks at 4.25:1, 0.94 cleared 4.5:1, white is the
    maximum.)
  - The bloom is **one** stop at `glyphSize * 0.22`. It was two, the wider at
    0.70 — which on a 21pt mark is a halo larger than the glyph, so it stopped
    reading as light off the strokes and started reading as out of focus. That
    haze was the other half of the "not clear white" verdict.
  Do not "fix" the well back to a pale chip with a dark icon either: light does
  not come off a dark line on a pale ground, and every attempt to make that
  bloom visible fogged the square and washed the icon out.
- **Pass `color` to re-tint the well, `background` to switch it off.** A tint
  rebuilds the whole well from that ink (deep amber well, pale amber glyph), so
  a warning still reads as a warning; every semantic ink clears 4.5:1 at the
  light end of its own gradient. `background` gives the flat pale chip instead,
  and is reserved for the quiet half of a state pair — a notification already
  read, a phone not reporting a position. **Lit means live**; do not spend it
  on decoration that has no off state.
- **The app bar is transparent, and so is any header strip under it.** The
  page's wash runs from the top of the screen. A white bar on a tinted ground
  draws a hard edge under every title, and it was the main thing that made an
  inner screen look unrelated to Home. A search field or date strip is white
  against a ground that is not, which is all the separation it needs. A
  translucent panel with a hairline was tried as a middle ground and rejected.
- **A filled control gets a sheen** (`AppGlow.sheen`) — a whisper of white
  along its top lip, gone by 40% of the height. It is the difference between
  glass catching light and a flat block. Not on anything under ~40pt tall: on
  a small pill the band covers most of it and reads as a gradient fault.
- Typography uses the platform UI face deliberately (offline-first field app;
  no webfont fetch). Change it only via `AppTypography.fontFamily`.
- **A dialog's buttons are two equal halves, until the words stop fitting.**
  Two `Expanded` halves make the *longer* label fit in half a dialog, and a
  dialog is narrower than the screen: "Confirm all" and "Not yet" shipped as
  "Confi…" and "Not y…", an ellipsised verb on the one control whose job is
  saying what the tap does. They stack when measurement says they must, with
  confirm on top. Stacking is not the degraded layout — it is the honest one.
- **A `SegmentedField` is the same pill a `FilterChipBar` draws.** It was an
  `AppCard` per option — a rounded rectangle with two drop shadows and a pale
  brand tint — with a Material radio ring inside it. Two shadowed rectangles
  side by side read as muddy grey rather than as one control with two
  positions, and the app already had an answer to "pick one of these" three
  screens away. No radio glyph: a filled pill beside an unfilled one *is* the
  mark, and the ring was a second indicator saying what the fill already said.
- **Two or three options go in a `SegmentedField`, not a dropdown.** Both
  answers on screen, no tap spent revealing them. A dropdown for a two-value
  field costs three taps to express one bit. Past three the row runs out of
  width and the labels ellipsise — that is where [DropdownField] starts.
- **Options open in a bottom sheet, never in an anchored menu.** `DropdownField`
  opens `showModalBottomSheet`, and every dropdown in the app goes through it.
  A rep fills these forms one-handed in the street: an anchored menu opens
  wherever the field happens to sit — often the top of a long form, out of
  thumb reach — it can open behind the keyboard mid-edit, and the cascading
  pairs here (territory → area, HQ → cluster, the client list) are long enough
  that a popup becomes a cramped scroller. Past eight options the sheet grows a
  search box.
- Icons are Material outlined at 13/16/20/24. Keep one icon per metadata row —
  two glyphs competing in a caption row reads as noise.

## Architecture

- **The UI never talks to a data source directly.** Screens depend only on the
  repository interfaces in `lib/data/repositories/repositories.dart`.
- Adding a backend = write `ApiXRepository implements XRepository`, change one
  line in `lib/core/providers/app_providers.dart`. If a screen needs editing to
  connect an API, the abstraction was wrong.
- **No business logic in widgets.** Money maths lives on `OrderItem`, pace
  logic on `DaySummary`, geo rules in `GeoMath`. A widget that computes a
  number is a widget that will disagree with the report showing the same
  number.
- State is Riverpod with explicit sealed states. **No `isLoading` / `hasError`
  boolean pairs.**
- Models are plain immutable classes with `copyWith`. No codegen — builds stay
  fast and there are no generated files to regenerate.

## Business rules that must not be quietly changed

- **Geo-fence policy defaults to `warn`, not `strict`.** Out-of-range visits
  are recorded with a mandatory reason and flagged unverified. Blocking pushes
  real work out of the system.
- **Rejection always requires a reason.** Approval history is append-only.
- **A control that cannot act must still answer.** `onPressed: () {}` renders
  an *enabled* button that swallows the tap — on a demo, indistinguishable from
  a broken app. Where the backing service is not in this build, call
  `showComingWithBackend(context, 'Calling')`. An audit found nineteen of these
  and `no_dead_controls_test.dart` now fails on the next one.
- **A route constant with no `GoRoute` behind it is a dead end**, not a
  placeholder: pushing it lands on the router's "no screen at …" page. Same
  test guards it.
- **Data a rep enters must be shown back somewhere.** An audit found six fields
  captured by a form and rendered on no screen at all — joint work, inputs
  given, POB value, the tour's planned clients, the day plan's GPS address.
  Before adding a field to a form, name the screen that will display it.
  Joint work has since been **removed outright** — the field, both pickers and
  both display rows — because the answer to "who rode along" turned out to be
  nobody's question. The corollary of the rule: a field no one reads is not
  fixed by finding somewhere to print it.
- **A seed that indexes a literal by position will outlive the literal.** The
  product split in `_buildSales` was `[0.29, 0.24, 0.19, 0.16, 0.12][i]`
  indexed by the product's rank; the catalogue grew to twelve, the sixth threw
  a `RangeError` inside a `late final`, and every screen reading sales showed
  "Something went wrong" for the rest of the session. Derive from
  `products.length`, never from a table that has to be kept in step by hand.
- **A render test cannot tell a screen from an error state** — both lay out
  perfectly. Any screen whose worth is its data needs a `navigation_test` that
  taps through to it and asserts on a *figure*. That is what the Sales bug got
  past for the whole build.
- **A claim hangs off a worked day.** Every `Expense` carries a `dayPlanId`,
  and `ExpenseRepository.claimMonth` joins day plans to what has been filed
  against them. No intimation, no claim — enforced at the repository so there
  is one answer to "can this be claimed" whichever screen asks. Leave and
  holidays are never claimable; `ClaimDay.isClaimable` is the single edit when
  the client rules on whether Meeting and Training days earn the allowance.
- **A month is read from everything that knows about it, and it comes back
  whole.** `claimMonth` returned only the days a rep had filed a plan for, so
  a Sunday, a company holiday, a week of approved leave and a day he simply
  forgot to intimate were the same thing on screen: absent. Only the last of
  those is money lost, and it was the one the rep could not see. Every day up
  to today now comes back carrying a `DayKind`, resolved in one place and in
  this order: **the day plan wins** (a declared Sunday was worked), then the
  company holiday calendar, then Sunday, then approved HR leave, then a tour
  plan that says leave — and a working day with none of those is
  `notDeclared`, drawn in the same red attendance uses for an absence.
  Attendance resolves a date the same way, in the same order, so the two
  screens cannot disagree about what a day was.
  - **Today is never a missed day.** It has no day plan because the rep has
    not filed one *yet*; a row reading "No intimation filed" against today is
    the app telling him at nine in the morning that he has already lost the
    day. It is left out until it is declared. Same reasoning as `TierBadge`:
    a day half done is a position, not a warning.
  - `kind` is **required** on `ClaimDay`. With a default it could be
    constructed disagreeing with `workType` — a leave day still claiming to
    have been worked — and the field deciding whether money is owed would be
    the one nobody passed.
- **Sunday is the week off, everywhere.** The tour plan asked a rep to open
  five Sundays a month and tell it what it already knew; a day with one
  possible answer is not a question. `TourMonth.workingDays` excludes Sundays
  and company holidays, and `isComplete` is measured against that — the five
  Sundays were never his to fill. Working one is still allowed: tapping it
  saves a real plan, and it does not move the denominator.
- **The allowance is flat, and it is per *day*.** ₹250 a worked day whatever
  the distance, so the ordinary day is a confirmation rather than a
  calculation. Territory explains an excess; it never prices one — an earlier
  draft gave out-of-territory its own higher rate, which would quietly pay two
  reps differently for the same day.
  - The excess is measured against `ClaimDay.remainingAllowance`, **never**
    against the full allowance. Against the full figure a rep could file ₹250
    twice on one day — each line at the allowance, each needing no bill — and
    take ₹500 for a ₹250 day.
  - Above the allowance, the bill and the reason are **enforced, not hinted**.
    The old form suggested a receipt over ₹500. A hint is not a rule.
- **Never trust a `ClaimDay` handed to a repository.** It is a snapshot from
  when the screen loaded. `confirmStandardDays` originally skipped days whose
  passed-in copy said `isOpen`, which after the first confirm still said yes —
  so a second tap paid every day again. It asks the store now. The comment
  above the guard claimed protection the code did not have, and only a unit
  test found it: **a comment is not a test.**
- **The claim goes in one piece, and the month never shuts.** It is submitted
  once, after the month has ended *and* every day in it has been answered —
  the same gate the tour plan has, because an approver receiving a month in
  instalments is not looking at the month. `claimGate` is that rule, and it is
  read twice: by the screen to disable the button, and by the repository
  against the store, since the button is working from a snapshot. A month is
  over when the calendar says so, never when the last declared day has been
  confirmed — on the 20th every day so far can be answered and the month still
  has ten days in it. What does *not* change is the other half: a day
  remembered in November can still be claimed against September and sent on
  its own, which is what stops a rep guessing a figure rather than losing the
  day. The screen says both out loud — a disabled Submit always carries the
  reason it is disabled.
- **A claimed day must say where it stands.** Draft, submitted, approved and
  rejected all rendered as one green tick once — and when money moves monthly,
  "has this been approved" is the question the screen exists to answer. Where
  a day carries several claims the **worst news wins**: a rejected line is the
  one the rep has to act on.
- **Only a draft is editable.** Clients edit freely; a travel plan or an
  expense stops being editable the moment it is submitted, because an approver
  is looking at it and changing it underneath them is how an approval comes to
  mean nothing. The detail screens only offer Edit on a draft.
- **An edit rewrites the record, it does not fork it.** Keep the id, the
  `createdAt`, the owner and the append-only `approvalHistory`; rebuilding the
  object from form fields alone drops them and leaves the original behind.
- **Correcting a record is not repeating it.** An activity edit goes through
  `ActivityRepository.update`, never `completeVisit`: completion also bumps the
  client's visit count and last-seen date, so re-running it on a typo fix would
  credit a second visit. It also keeps the original timestamps and the geo
  evidence — a correction typed at the office must not claim the rep was
  standing at the clinic.
- **A detail screen loads its record by id.** Complaint detail used to fetch
  the whole list and filter in the widget, which made any record outside the
  caller's list scope render as "not found" even though it exists.
- **A record a rep can create, a rep can correct.** `ClientRepository.update`
  existed and was called by nothing for the whole build — a doctor who changed
  clinic or number could only be re-registered as a duplicate. The client form
  takes an optional `existing` and switches mode; do not fork a second screen
  for editing, because the fields and the territory→area cascade would drift
  apart the first time either changed.
- **`copyWith` must pass every field.** The client's dropped `listing` and
  `specialDate` silently, so any copy reset the category and wiped the date. It
  went unnoticed only because nothing called it yet. When you add a field to a
  model, add it to `copyWith` in the same edit.
- **Reference data comes from the repository, never from a literal in a
  screen.** Specialties were a hardcoded list inside the admin master-data
  screen, where the client form could not reach them — two lists that would
  have disagreed the first time either was edited. They are
  `ClientRepository.specialties()` now, and both read it. Anything a company
  maintains rather than a rep creates belongs there.
- **Active/Inactive belongs to a *listed* client only.** It is a fact about a
  client's place on the company list — a clinic that has closed comes off it —
  and an unlisted client was never on the list, so there is nothing for the
  flag to describe. The form does not ask; choosing Listed is what asks it,
  and choosing Unlisted clears the answer so an "Inactive" given while listed
  cannot sit on the record unasked and unshown, waiting for a report to find
  it. `Client.statusLabel` is the rule: `null` means no badge on a screen and
  `NA` in the exported sheet, which is what the client's own workbook writes.
- **A field with a closed set of answers is a picker, not a text box.** Typed
  free text arrives as "Cardiologist", "cardiologist" and "Cardio" — the same
  thing to a rep, three rows in any report that groups by it.
- **Reports are derived from transactional records**, never stored alongside
  them. If you add a report figure, compute it.
- **An exported sheet is a report, and it keeps the office's shape.** The four
  — Expenses, Tour Plan, DCR, Client List — come from the client's own
  workbook: a title, the rep's name / code / designation / area, a blank line,
  then a table with **one row per calendar day**, and SUNDAY / HOLIDAY / LEAVE
  written into the station column with zeroes beside it. That is exactly what
  `DayKind` already resolves, so the sheets read the claim month rather than
  walking the day plans a second time and disagreeing with it. `ExportSheet`
  holds rows of strings, not a formatted file, and writes itself as either —
  so the contents can be asserted on without opening a file.
  - **It downloads a real `.xlsx`, and it is not a share sheet.** CSV was the
    first answer and it was wrong twice over: every column arrives as text, so
    the amounts will not sum and a month will not sort, which is the first
    thing the office does to one of these. `toXlsx()` writes the six OOXML
    parts by hand — dates as real Excel dates, figures as numbers, the header
    row frozen, filtered and in the app's own blue. Six parts is the whole
    format for a sheet with no formulas in it, which is why there is no
    spreadsheet package here. And the file *saves* to Downloads rather than
    opening a share sheet: the office asks for a file, and a share sheet asks
    the rep to choose an app before he has one. Sharing is the fallback for a
    platform with nowhere to download to.
  - **Building and saving are two acts with two failures.** They were in one
    `try` that blamed the first for both, so a file that would not save
    reported a sheet that would not build — and sent the rep looking in the
    wrong place.
  - **Two of the client's columns are deliberately missing.** Joint work was
    removed from this app outright, and printing a column of "No" would be
    inventing data to fill a shape; the client list's *Unlisted* column is the
    negation of the *Listed* column beside it. A test holds both absences, so
    nobody adds them back to "match the sample" without reading why.
  - **A month with nothing in it is not a month of missed days.**
    `claimMonth` synthesises the days a rep did not intimate so the red ones
    can be found — but a month before he joined has nothing to give context
    to, and thirty "No day plan" rows would paint a red calendar and export a
    sheet of nothing. It returns empty instead, and the screen says so.
- **An area manager is a field person who also runs a team, and the app owes
  them both halves.** They file their own day plan, make their own calls, plan
  their own month and claim their own allowance — and every screen that could
  answer "whose is this" answered *the team's*. Home opened on the team
  dashboard, My Activity listed everyone's calls, and the To-Do button only
  ever said Assign, so a manager could hand work to anyone and had no way to
  note a thing of their own. Home stacks both, own day first; the two lists
  carry a `ViewScope` switch that defaults to **Mine**, because Home has just
  told them how their own morning is going and two screens must not disagree
  about whose day it is. The switch also decides what the To-Do button does.
  Reps never see it — there is only one answer for them — and nothing was
  taken from the manager to make room.
- **Scope is resolved once at login** into a `DataScope` and applied at the
  repository layer. Never filter by employee in a screen — the `ViewScope`
  switch changes the `employeeId` *asked of the repository*, it does not sift
  a list the screen already holds.
- Offline-capable records use **client-generated UUIDs** so a retry cannot
  duplicate them.

## Navigation

- The bottom bar's tabs differ by role, but the shell's **branches do not**:
  each branch holds exactly one route, and a `NavDestination` names its branch
  by index (`ShellBranch`). Never put two routes in one branch — the branch's
  default location becomes whichever is declared first, and the other role's
  tab silently opens the wrong screen.
- **Never `context.push` a tab root.** It lands the screen on a branch
  navigator the indexed stack is not showing: nothing throws, nothing is
  logged, the tap just does nothing. Menus, tiles and cards call
  `navigateTo(context, route)`, which picks `go` for the roots listed in
  `Routes.shellRoots` and `push` for everything else.
- A screen that is pushed needs its back button — do not leave
  `automaticallyImplyLeading: false` on a screen that stops being a tab. A
  screen that *becomes* a tab root needs the drawer button instead, since it
  has nothing to pop back to. **`DrawerMenuButton` decides this itself** by
  asking the navigator whether it can pop, because the same screen is a tab
  for one role and a pushed screen for another.
- **"A tab root" is a question about the *user*, not the route.**
  `Routes.shellRoots` lists every route that is a tab for somebody, and the bar
  differs by role — My Activity is a manager's tab and a rep reaches it from
  the module grid. `navigateTo` therefore checks the signed-in user's own
  destinations, not the global set. Sending a rep to a branch outside their bar
  with `go` left them with no tab lit, no back arrow and nothing to pop.
- **`indexWhere` answers -1, and -1 is not zero.** The shell read
  `selected <= 0` as "we are on the first tab", so `canPop` was true on any
  branch outside the role's bar and the Android back gesture **closed the app**
  from a screen the user had navigated into. Only a genuine `0` is the first
  tab.

## Home

Home answers one question: *what do I need to do today?* (§15, §78 — it is not
an analytics dashboard.) Two rules have already been re-learned the hard way:

- **One fact, one place.** A goal card saying "7 of 10 done" and a status strip
  saying "1 visit behind schedule" are the same fact stated twice; they now
  share a card. Before adding a figure here, check it is not already on screen
  in another form. This is not a Home rule — a client row used to print its
  category in the subtitle *and* in the badge beside it, and on a narrow card
  the badge squeezed the duplicate until it ellipsised mid-word. Where a badge
  states something, the sentence next to it should not restate it.
- **The day's progress is a bar, not a ring.** A ring spent an 84pt square to
  say one number and squeezed the count, the caption and the pace line into
  the half-width column beside it. Flat, it costs 12pt of height, the text
  above it gets the full width, and it has somewhere to glow.
- **The light on the bar is a knob at the leading edge, not a lit segment.**
  Light track, a segment that **ramps light → deep across whatever it has
  filled**, and a green knob in a white ring standing proud of the channel. It
  sits half on the deep segment and half on the light track, which is the one
  place on a white card where a glow has something to register against — a glow
  smeared along the whole segment reads as a coloured fill, and a *dark*
  channel (also tried) makes the bar the loudest object on the screen instead
  of an instrument sitting in a card.
  - The ramp is complete at **5% as much as at 100%** — it spans the fill, not
    the track. Two deep stops (what it was) is a flat blue block; the ramp is
    what turns a fill into distance travelled.
  - The knob is **green and the bar is not**. The bar says how far, the knob
    says *moving* — a different fact, so it gets the one second colour allowed
    on a control in this app. Never widen it into a green fill: green means
    done here, and a green bar at 20% says the opposite of the truth. The white
    ring is not decoration — the knob crosses from the deep fill onto the light
    track as the day runs and would lose its edge against one end or the other.
- **Progress is a rung on `GameTier`, not a bare percentage.** Four rungs —
  Getting started / On pace / Ahead / Target met — and the bar, the knob and
  the chip beside it all take that rung's ink, so they cannot disagree. The
  label always ships with the colour: an earlier bar changed colour with the
  pace on its own and read as a warning light rather than as progress, because
  nothing named what the amber meant. Naming it is the whole difference.
- **Planned vs unplanned is an *origin*, not a status.** A call the rep added
  on the day carries `Activity.isUnplanned`, set by Add New Activity and
  nowhere else — that screen exists for the call made because he was passing,
  which is why it has no date on it. Folding this into `ActivityStatus` would
  erase it the moment the visit was made, which is precisely when a manager
  starts asking about it. My Activity filters on it: the old **Upcoming**
  filter sorted by *when*, and every open call is upcoming, so it answered a
  question nobody was asking.
- **An activity's badge shows its origin before the call and its outcome
  after.** Planned / Unplanned while it is ahead, Completed / Missed once it
  has happened, In Progress while it is being made — a call happening right
  now is neither. "Upcoming" has no surface anywhere any more; the status
  still exists because it is how the day's *next* call is found, but as a word
  it was a second name for Planned. One badge either way: a card carrying both
  the origin and the state squeezes the pair until one ellipsises, which is
  what a client row already taught this app.
- **`TierBadge` for achievement, `StatusBadge` for state.** The old mapping ran
  the *state* palette over targets and painted a rep at 40% in **error red**,
  which tells someone at 11am that their morning is a failure. A target that is
  half done is a position, not a warning.
- **"Plan" means intimating, not viewing.** My Day Plan is the morning
  declaration — work type, HQ, cluster, GPS stamp. The schedule timeline it
  once opened was deleted; the full list is My Day Activity, and Home shows
  today's in full.
- **The day starts when the rep says it does, not when the clock says so.**
  `DaySummary.dayStatusLabel()` reads the day plan's `declaredAt` first and the
  hour second. The line used to be pure clock arithmetic, so it told a rep who
  had declared and driven out at seven that their day had not started, and told
  one who had done nothing at 09:01 that they were on track. On a declared
  meeting or training day it names the work type instead of pacing against a
  visit target that does not exist.
- **Home lists the whole day, and the list is what the count counts.** Every
  visit, completed ones included, in order. It was three rows with the next
  call skipped — because a card above repeated it — and the done ones dropped,
  so a rep with ten visits saw three, none of them the one they were about to
  make, under a figure reading "1 out of 10". The next call is the row with the
  rail and the button on it; that row **is** the deleted "Next action" card,
  and re-adding the card would put the same appointment on screen twice.
- **The module grid shows one row, with a "See all" under it.** Three of the
  six carry nearly all the traffic — declare the day, log a call, look up a
  client — and the other three were spending a whole row of Home on modules a
  rep opens now and then, which pushed today's calls below the fold. Folded,
  five visits are on screen instead of one. Nothing is deleted: the three are
  one tap away here and still in the side menu.
  - It shows `columns`, not a hardcoded three, so the six-across tablet layout
    hides nothing and shows no control — folding there would cost a tap to
    reveal a row that already fit.
  - The control is **right-aligned and reads "See all"**, matching the visit
    list's own See all below it in words and placement, so the two read as the
    same kind of control. Home therefore carries two of them: a test reaching
    for the grid's takes `.first`, which is the one higher in the tree.
  - Two other shapes were built and rejected: a **"Show 3 more"** label (the
    count is a better reason to tap, but two different phrasings of the same
    control on one screen is worse than the repetition), and a **fourth
    "More" tile** opening the side menu (tidier as an object, but the request
    was for See all). `_TileShell` survives from that version and is worth
    keeping — every tile in the row is built from it, and built separately
    they drift.
  - And still no heading. "QUICK ACTIONS" names the *widget*, which is what
    the review called the AI-generated feel — and there is no honest content
    name for a grid of six unrelated modules, which is why it went in the
    first place.
- **Never name a widget in the UI.** "Quick actions", "Overview", "At a
  glance", "Key metrics" — these name the *pattern*, not the content, and a
  screen full of them reads as assembled rather than written. The review's word
  for it was "AI generated", and the fix is to say what is in the box:
  "Today's planned visits". Six labelled tiles need no label of their own; the
  `+` button adds things, so it is called Add.

## Motion and feedback

The app once had five animated widgets and sixty-eight places where a skeleton
became data in a single frame. That was the largest single difference between
it and the apps it is measured against — those are defined by continuous
motion, not by their palettes.

- **The vocabulary is five patterns, and no more.** Arrival (`Arrive`),
  cross-fade (`Swap`), press (`Pressable`), value motion (`CountUp`,
  `AppProgressBar`, `AnimatedContainer`) and continuity (`Hero` on a record's
  avatar). Reusing five is what makes the app feel like one thing; a sixth
  invented for one screen is how a motion system becomes noise.
- **Content arrives, it never appears.** Wrap the data branch of an async build
  in `Arrive`; use `Arrive.staggered(index:)` in a list. It plays **once**, so
  scrolling or a filter change does not re-animate what is already on screen.
- **Everything is 120–260ms** (`AppMotion`), decelerating, never bouncy. Motion
  that draws attention to itself is the failure: this exists to make the app
  feel *quick*, not animated.
- **A spinner must never flash.** `LoadingState` stays blank for 300ms first.
  Most reads here resolve in ~260ms, so almost none should ever draw one — a
  spinner that comes and goes inside a third of a second reads as a stutter.
- **Some lists must not stagger.** A chat thread opens at its newest message;
  animating rows in replays a conversation the reader has already had.
- **Three haptics, no more**: `selection` on choosing, `success` on a saved
  record, `failure` on a refusal. Never on validation — a form that buzzes
  while you fill it in is punishing. And never on merely arriving at a screen,
  which teaches the rep to ignore the one that means their work was saved.
- **Digits are tabular** in every text style that carries a figure. With
  proportional digits a `1` is narrower than a `7`, so columns of numbers
  shift as data changes.
- **`Fmt.count` for anything counted.** "1 visits" appeared in eight places;
  it is the smallest defect in an app and one of the most damaging.

## Layout traps this codebase has already hit

Both of these render *nothing* in release while asserting in debug — which is
why the widget smoke suite exists:

- **Never pass both `shape` and `borderRadius` to `Material`.** `shape` carries
  the radius.
- **Never use `Row(crossAxisAlignment: stretch)` inside a scrolling list.** It
  has no bounded height and collapses the card and everything after it.
- **Never put a `LayoutBuilder` in `AlertDialog.actions`.** They sit in an
  `OverflowBar`, which asks its children for an intrinsic width, and a
  `LayoutBuilder` cannot answer that. `showConfirmDialog` decides whether its
  two buttons sit in a row or stack by measuring the *labels* against the
  narrowest a dialog can be (280), not against the width it actually got.
- Metadata rows must degrade on a 320pt phone: wrap the give-way element in
  `Flexible` with `overflow: ellipsis`, or use a `Wrap`.

## Testing

- `flutter test` must stay green. 339 tests.
- **The palette's floors are a test** (`test/unit/palette_contrast_test.dart`),
  not a comment. It recomputes every ratio from the tokens, so a nudged hex
  fails the suite instead of shipping to a rep reading the screen in the sun.
  It has already caught four values that had drifted under 4.5:1.
- Business logic gets unit tests (`test/unit/`). UI gets render smoke tests
  (`test/widget/`) — `testWidgets` fails on any layout exception, which is the
  only thing that catches the traps above.
- Navigation gets `navigation_test.dart`, which boots the **real router** and
  taps. A dead tab or a menu item that opens nothing throws no exception, so a
  test that only renders screens cannot see it — these tap, then assert on
  what is on screen.
- When you add a screen, add it to `screen_smoke_test.dart`. It is one line.
  Tapping something far down a page in a test needs a taller viewport: the
  bottom bar covers the last ~60pt, and a tap that lands on it is a silent
  no-op that reads as "the route is broken".

## Deliberate non-choices

Rejected on purpose; re-open only with a reason:

- **`lucide_icons`** — Material outlined icons are already consistent across
  ~150 usages; swapping adds a dependency and a migration for no user benefit.
- **`flutter_svg`** — there are no SVG assets. The brand mark is drawn in code
  so it scales and re-colours with the palette.
- **`file_saver`, `archive`, `share_plus`** — accepted, and the only
  dependencies added since the build began. All three are the export's:
  `file_saver` puts the workbook in Downloads through the media store, so
  there is no storage permission to ask for and no `path_provider`; `archive`
  zips the OOXML parts (a workbook is a zip, and hand-rolling one is CRC and
  central-directory code nobody should own); `share_plus` is the fallback
  where there is nowhere to download to. A spreadsheet package was *not*
  taken — the six parts in `ExportSheet.toXlsx` are the whole format for a
  sheet with no formulas, and a library for that only ever writes one shape.
- **`flutter_animate`** — still rejected, but not because motion is unwanted.
  The motion system in `app_motion.dart` and `motion.dart` is built from
  `AnimationController`, `TweenAnimationBuilder` and the implicit animations,
  which is all this needs. A dependency would buy chaining the app does not
  use.
- **Code generation (freezed/json_serializable/drift)** — deferred until the
  API lands, to keep builds fast while the UI is being iterated.
