# Palette backup — deep teal on a green ground

The palette the app ran before the white/multi-colour rebuild. Kept whole so it
can be restored without archaeology.

## What it was

Deep teal `#075E63` on a green wash (`#D3E6E6` → `#F4FAF9`), one lit icon well
in that teal for every module, and a day-progress bar in the same green with a
knob of light at its leading edge. The rationale for each value — including two
documented dead ends, the pale well and the dark channel — is in the doc
comments of `app_colors.dart` here.

## Restore

```bash
cp design/palettes/green-teal/app_colors.dart     lib/core/theme/
cp design/palettes/green-teal/app_glow.dart       lib/core/theme/
cp design/palettes/green-teal/app_background.dart lib/core/theme/
```

`home_screen.dart` is kept as a **reference, not a restore target** — it moves
on independently, and copying it back would revert unrelated work. What it
holds is the quick-action grid and `_GoalBar` as they looked in the green
build; take the parts you need.

Anything that referenced a token this palette had and the new one does not will
fail to compile, which is the intended safety net.
