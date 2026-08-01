# Changelog — Unkillables Rebalance (Fix)

Plain-language changelog for the Nexus page. Newest first.

## v1.2 — rebuilt for the 2026-08-01 hotfix (build 24501089)

**If you use this mod, update it.** The previous build silently undid part of the game's
2026-08-01 hotfix.

**What was wrong:** this mod works by shipping its own copies of a few game files. Those copies
were taken on 2026-07-20, *before* the hotfix. One of them — the shared damage component every
rebalanced boss uses — was missing three pieces of behaviour the hotfix added, including what
looks like the weapon damage buff. Installing the old pak put the pre-hotfix version back, so
you'd quietly lose that buff while the mod was enabled.

**What changed:** the same files are re-taken from the current game and the rebalance re-applied
on top. Nothing about the rebalance itself moved — boss HP, the Grabber/Stalker changes and the
armour thresholds are all exactly as before, and the four Grabber/Stalker data files are
byte-for-byte identical to the previous release.

**To update:** replace your `153_UnkillablesRebalance_P` files (`.pak`, `.ucas`, `.utoc`) with
the new ones. As always after a game patch, do a clean reinstall of your mod loader
(Signature Bypass + UE4SS) too — remove and re-add, don't just toggle.

*Note: this mod ships whole copies of game files, so it has to be rebuilt after every game
patch. If a patch lands and there's no new release here yet, assume it's out of date.*

## v1.1 — Meatman startup-crash fix (2026-07-10)

**Fixes a crash on startup.** Some players crashed while loading, with an error like:

```
ObjectSerializationError: .../BP_AI_Euruska_MeatMan ... Bad export index
```

**What caused it:** the mod was shipping its own out-of-date copies of the boss "blueprints"
(Meatman, OrgaMech, Shield Officer, Toothy) — built for an older version of the game. After a
game update those copies no longer matched what the game expects, so the game crashed trying to
load the Meatman.

**What changed:** all six bosses are now rebuilt from the **current** game files, with only their
health numbers changed. That means they load cleanly on the current build while keeping the exact
same rebalance.

**The rebalance itself is unchanged** — same killable-boss HP, same weakened Grabber/Stalker. If
you weren't crashing, nothing about how the mod plays changes; if you were, this fixes it.

**To update:** replace your old `153_UnkillablesRebalance_P` files with the new ones (`.pak`,
`.ucas`, `.utoc`). As always after a game patch, do a clean reinstall of your mod loader
(Signature Bypass + UE4SS) too — remove and re-add, don't just toggle.

## v1.0 — Initial compatibility rebuild

Rebuilt the original **Unkillables Rebalance** (Nexus #68) so it works on The Forever Winter build
0.9.3.9.2. De-invincibles six bosses (finite, killable HP) and weakens the Grabber/Stalker
insta-kill grab — the same rebalance as the original, re-cooked for the current game.
