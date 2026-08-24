# Handoff — Grabber shooting crash (2026-08-05)

> **CLOSED 2026-08-23. This handoff was picked up and run; do not action it again.** The build
> was done on 24536482 and both gates are green, but its central hypothesis did **not** survive
> contact with the measurement:
>
> - **The Stalker-AIDEF diagnosis is withdrawn.** All 4 rebuild byte-identical to the frozen
>   0.9.2.2 cook, so that class never drifted and cannot have been mis-decoding. The Option A →
>   Option B move is kept as hygiene but is a **no-op in shipped bytes**. The reported crash has
>   no established cause and still needs a crash log.
> - **`[2b]` did not settle it, contrary to the expectation set below.** It cannot tell real
>   drift from the rebalance this mod itself applies — it reported `delta +0` and
>   `payloads DIFFER` on every AIDEF, which reads as drift but was only the 2 patched scalars.
>   The three-way base/rebuilt/previously-shipped byte comparison is what answered it.
> - **`[5c]` gate A had to be fixed again.** Its "must DIFFER from the previously shipped pak"
>   clause failed all 4 on a correct build. It asserted a premise, not a contract; it is now a
>   drift report.
> - **What the rebuild genuinely fixes:** the shipped pak drops **9 property shapes** from
>   `BPC_IncomingDamageMod` on 24536482 (`Check if Weapon Silenced`, `Clean Up Damaged Foes`,
>   plus a new array-inner struct). That is the claim v1.3 now ships on.
>
> Full account: [`WORKLOG.md`](../WORKLOG.md) Session 6. The text below is the original handoff,
> kept for history — its "Run this" and "What's still missing" sections are superseded.


For a **local session on Windows** picking this up. Everything below is on branch
`claude/grabber-shooting-crash-weq6js`. The remote session that wrote it had no game install and
no `retoc`, so **nothing here has been built, run, or launched.**

## What you're walking into

Frnix reports the game **crashes when shooting the Grabber**; others report issues too. Two
independent problems were found:

1. **The pak is stale.** `dist/` was built 2026-08-01 against build `24501089`. Steam now reports
   **`24536482`**. A game patch invalidates this mod every time — that alone explains multiple
   players hitting problems at once.
2. **The 4 Stalker/Grabber AIDEFs were the last frozen 0.9.2.2 assets** in the pak, and the only
   Grabber-specific ones. They were kept on the old "Option A" rebase path because *"DataAssets
   carry no Kismet bytecode, so no serialization-crash surface."* That reasoning is wrong — UE5
   uses **unversioned property serialization** (properties identified by schema *index*, not
   name), so a frozen cook mis-decodes into the wrong fields when the class layout changes, and
   crashes when a field is **dereferenced** — i.e. when you shoot it, not when it spawns. Full
   writeup in `tools/patch_stalker_aidef.py`'s docstring and `WORKLOG.md` Session 5.

**This root cause is inferred, not proven.** See "What's still missing" below.

## What changed in the repo (code + docs only)

| File | Change |
|---|---|
| `tools/patch_stalker_aidef.py` | **New.** Patches the 4 AIDEFs from current base: `DamageToStagger` 20000→1000, `SyncKillMaxPlayerHealth` 2000→1000 (float32). Self-verifying — each base value must occur exactly once per file or it aborts. |
| `tools/build_fix.sh` | **Option A retired entirely.** All 11 packages now extract from the live game. Removed the `MODSRC`/`upstream/` block, the `zzz_` collision staging (and with it the ~48 GB hardlink stage), and the `[2b]` provenance gate. Added a `[2b]` drift diagnostic. `[5c]` gate A **inverted**. Steps renumbered to `/6`. |
| `tools/patch_drifted.py` | Docstring corrected — no longer claims the AIDEFs are safe to freeze. |
| `tools/verify_build.sh` | Header rewritten: the Option-A caveat is obsolete; a dropped property now means a *stale extract*, not a frozen cook. |
| `docs/`, `README.md`, `CHANGELOG.md`, `WORKLOG.md` | Diagnosis, strategy table, v1.3 entry (marked pending), status banners, new test-checklist item for **shooting** the Grabber. |
| `tools/expected_package_ids.txt` | **Untouched, deliberately.** retoc derives the id from the destination path, which hasn't moved, so `[6/6]` must still report 11/11. If it doesn't, the assemble step wrote to the wrong path. |

**Verified here:** shell syntax (`bash -n`), all 3 embedded Python heredocs compile, and both the
new patcher and the inverted gate were exercised against synthetic fixtures (happy path, moved
base default, ambiguous byte pattern, re-run, unpatched variant, over-patch, fresh checkout).

**One bug that caught:** gate A was first written as "exactly 8 bytes differ from base" (2 ×
float32). Wrong — two float32s *occupy* 8 bytes but `20000→1000` changes 3 and `2000→1000`
changes 1, so a correct build differs by **4**. It would have rejected every good build. Now a
semantic check instead of a byte count.

## Run this

```bash
bash tools/build_fix.sh        # expects retoc + the game; every gate must pass
bash tools/verify_build.sh     # expects the CUE4Parse decoder + usmap
```

Expected, and worth checking rather than skimming:

- `[2b]` prints the base-vs-frozen AIDEF comparison. **Paste it into `WORKLOG.md`** — this is the
  evidence the diagnosis is currently missing, in the same shape that proved the MeatMan case
  (base uexp 5931 B vs shipped 5904 B, base having gained `"Sync Kill in Log"`).
- `[4/6]` prints one line per patched file from each patcher.
- `[5c]` gate A: each AIDEF **"current base cook, only the 2 scalars moved"**, and **differs** from
  the previously shipped copy. A byte-identical result means the strategy change didn't take.
- `[6/6]` **11/11** package ids.
- `verify_build.sh`: full coverage, **0 dangling**, **0 properties dropped**.

### If `patch_stalker_aidef.py` aborts

That's the design working, not a bug. `found 0` = the devs moved a base default on 24536482 →
re-datamine the AIDEF and update both `docs/rebalance-values.json` and the `SCALARS` table in the
patcher. `found >1` = the byte pattern is ambiguous in that file → find the real property offset
before proceeding. **Don't relax the assertion to get a build out** — a wrong offset ships a pak
that loads fine and rebalances the wrong thing.

## In-game test (build 24536482)

Full checklist in `docs/fix-notes.md`. The one that matters:

- **Shoot a Grabber repeatedly until it staggers — no crash.** Frnix's exact repro. Try the
  variants you can reach (regular, Underground). Note the existing checklist item only covered
  *being grabbed*, which is a different code path — that's why this went unnoticed.
- Bosses staggerable and killable; `…\Saved\Crashes\` empty.

## What's still missing

- **The actual crash log.** The supplied `UE4SS_8.log` contains **no crash** — it runs 16:45:32 →
  16:47:37, loads AshenMesa, and stops with no shutdown line. That's consistent with a hard crash
  but proves nothing, and UE4SS doesn't capture UE serialization errors anyway. Get
  `…\Saved\Crashes\` or `…\Saved\Logs\ForeverWinter.log` from Frnix. If it names something other
  than a Stalker AIDEF, this diagnosis needs revisiting.
- **A rebuild + launch.** Until then `dist/` is the stale 24501089 pak and every claim about the
  fix is structural inference.
- **`stalker_aidef.structural_drift`** in `docs/rebalance-values.json` is still stamped `false`
  from 24097213 and was derived from export counts, which cannot see this failure mode. Correct it
  from what `[2b]` actually measures.
- **Interaction to rule out, not a finding:** the log shows a Lua mod `TFWStaggerControl` hooking
  `GA_Player_HitReaction:K2_ActivateAbility` and `BP_PlayerBase:ReceiveAnyDamage` — the same
  *stagger* subsystem this mod's `DamageToStagger` feeds, though on the player side. Worth a
  mod-isolated repro before concluding.

## Then

Regenerate `dist/UnkillablesRebalanceFix.zip`, publish v1.3 (the CHANGELOG entry is written but
flagged pending — unflag it once the launch is green), and commit the rebuilt pak: `dist/` is
tracked, and the binary can only be produced on a machine with the game.
