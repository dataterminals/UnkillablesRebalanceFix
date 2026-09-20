# Changelog — Unkillables Rebalance (Fix)

Plain-language changelog for the Nexus page. Newest first.

## v1.4 — rebuilt for game 0.9.5.x (build 25071553)

**If you are on v1.3 — which is what this page has served since 24 August — update. v1.3 crashes
the game on the current build.**

**What was wrong:** the **August 2026 Update (0.9.5.0, 28 August)** rebuilt the game's AI systems,
and that moved the internal layout of the boss character class. The game stores these files as a
bare list of values with no names attached, matched up by position — so when the layout moves, an
older file is not rejected, it is **read wrong**. v1.3 was built four days before that patch.

**This is confirmed in-game, not just on paper.** A player sent a crash report on 29 August, one day
after the update, running v1.3:

```
ObjectSerializationError: .../BP_AI_Euruska_MeatMan
  ...Default__BP_AI_Euruska_MeatMan_C: Bad import index 1996488703/198
```

That is the game dying while it loads the Meatman, because the mod's copy of him no longer lines up
with what the game expects and the read comes apart partway through. If you crash on startup or on
entering a mission with an error naming `BP_AI_Euruska_MeatMan` or another `BP_AI_*`, this is it.
Note the boss does not have to be anywhere near you — the file is read when the game loads it.

Measured against the live game, every one of v1.3's six boss files does the same thing. Partway
through, the values slide onto neighbouring settings — on Meatman, "far distance" comes back as 150
instead of 750, and the 750 lands on the close-range setting — and then the read desynchronises and
**19 of its 35 settings are lost outright**, including which skeletal mesh, collision capsule,
movement component and AI controller the boss uses. Those missing pieces are exactly what the crash
above trips over.

The control that pins it on the game patch rather than on a bad download: those same v1.3 files,
read with the *previous* build's layout, decode perfectly — all 35 settings, all correct.

**What changed:** every file is re-taken from the current build and the rebalance re-applied on top.
Verified against the live game: nothing dropped, every reference resolves. Nothing about the
rebalance itself moved — boss HP, the Grabber/Stalker changes and the armour thresholds are exactly
as before. The four Grabber/Stalker files are byte-for-byte identical to v1.3 (that class did not
move), and the shared damage component lost nothing this time.

**About the "crash when shooting the Grabber" report:** still open, still needs a crash log. That
one happens while you *shoot* a Grabber; the crash above happens while the game *loads*. Fixing the
second does not explain the first. If it still happens to you on this build, please send
`…\Saved\Crashes\` and `…\Saved\Logs\ForeverWinter.log`.

**To update:** replace your `153_UnkillablesRebalance_P` files (`.pak`, `.ucas`, `.utoc`) with the
new ones. As always after a game patch, do a clean reinstall of your mod loader (Signature Bypass +
UE4SS) too — remove and re-add, don't just toggle.

## v1.3 — rebuilt for build 24536482 (2026-08-23)

**If you use this mod, update it.** The previous release was built for game build `24501089`. The
game is now on `24536482`, and on that build the old pak **switches off two pieces of behaviour the
game patch added.**

**What was wrong:** this mod works by shipping its own copies of a few game files. One of them — the
shared damage component every rebalanced boss and the Grabber use — was rewritten by the game patch
to add a **weapon-suppressor check** and a **damaged-foe cleanup** pass, and to make the noise a
damaged enemy raises **faction-aware**. The mod's copy predates all of that, so installing it put
the older component back: measured against the live game, the old pak is missing 9 of the
component's pieces, including the whole *"Check if Weapon Silenced"* and *"Clean Up Damaged Foes"*
functions. In practice that means suppressors and enemy-alert behaviour quietly revert to the
pre-patch version while the mod is enabled.

**What changed:** every file is re-taken from the current game and the rebalance re-applied on top.
The rebuilt pak now matches the live component exactly — nothing dropped. Nothing about the
rebalance itself moved: boss HP, the Grabber/Stalker changes and the armour thresholds are all
exactly as before, and ten of the eleven files are byte-for-byte identical to the previous release.

**About the "crash when shooting the Grabber" report:** this was investigated and the suspected
cause has been **ruled out**. The theory was that the mod's four Grabber/Stalker data files, still
built for the mod's original game version, no longer matched the current game. Rebuilding them from
the current game produced **byte-for-byte the same files** — so those files had never gone stale,
and they cannot have been mis-reading. If you are still crashing when you shoot a Grabber, that
crash is something else and we need your crash log (`…\Saved\Crashes\` and
`…\Saved\Logs\ForeverWinter.log`) to find it. Note the stale component described above is a
plausible contributor on its own, so try this build first.

**To update:** replace your `153_UnkillablesRebalance_P` files (`.pak`, `.ucas`, `.utoc`) with the
new ones. As always after a game patch, do a clean reinstall of your mod loader (Signature Bypass +
UE4SS) too — remove and re-add, don't just toggle.

*Note: this mod ships whole copies of game files, so it has to be rebuilt after every game patch. If
a patch lands and there's no new release here yet, assume it's out of date.*

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
