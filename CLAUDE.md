# PharmaConnect — working agreements

Guardrails for anyone (human or AI) extending this codebase. These are the
rules the existing code already follows; breaking them creates inconsistency
that is expensive to unwind later.

## Design system

- **Never hardcode a colour, font size, or spacing value in a widget.** Use
  `AppColors`, `AppTypography`, `AppSpacing`, `AppRadius`, `AppSizes` from
  `lib/core/theme/`. If a token is missing, add it there — do not inline a
  `Color(0x...)` or a `fontSize:`.
- The palette is **warm ivory + deep teal + sand + graphite**. Deep teal means
  action/active/verified. Sand means secondary/planned. Semantic colours mean
  real states, never decoration.
- **Never communicate state by colour alone** — every badge carries text.
- Typography uses the platform UI face deliberately (offline-first field app;
  no webfont fetch). Change it only via `AppTypography.fontFamily`.
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
- **Reports are derived from transactional records**, never stored alongside
  them. If you add a report figure, compute it.
- **Scope is resolved once at login** into a `DataScope` and applied at the
  repository layer. Never filter by employee in a screen.
- Offline-capable records use **client-generated UUIDs** so a retry cannot
  duplicate them.

## Layout traps this codebase has already hit

Both of these render *nothing* in release while asserting in debug — which is
why the widget smoke suite exists:

- **Never pass both `shape` and `borderRadius` to `Material`.** `shape` carries
  the radius.
- **Never use `Row(crossAxisAlignment: stretch)` inside a scrolling list.** It
  has no bounded height and collapses the card and everything after it.
- Metadata rows must degrade on a 320pt phone: wrap the give-way element in
  `Flexible` with `overflow: ellipsis`, or use a `Wrap`.

## Testing

- `flutter test` must stay green. 132 tests.
- Business logic gets unit tests (`test/unit/`). UI gets render smoke tests
  (`test/widget/`) — `testWidgets` fails on any layout exception, which is the
  only thing that catches the traps above.
- When you add a screen, add it to `screen_smoke_test.dart`. It is one line.

## Deliberate non-choices

Rejected on purpose; re-open only with a reason:

- **`lucide_icons`** — Material outlined icons are already consistent across
  ~150 usages; swapping adds a dependency and a migration for no user benefit.
- **`flutter_svg`** — there are no SVG assets. The brand mark is drawn in code
  so it scales and re-colours with the palette.
- **`flutter_animate`** — motion here is deliberately minimal (§11: calm,
  professional, not flashy). The few transitions use built-in
  `AnimatedContainer`. A dependency for chained entrance animations would
  fight the product's character.
- **Code generation (freezed/json_serializable/drift)** — deferred until the
  API lands, to keep builds fast while the UI is being iterated.
