# Crash report, 2026-08-29 — MeatMan CDO, `Bad import index` on a pre-`0.9.5.0` cook

**This is the in-game arbiter the repo has been asking for since Session 5 — for the *stale pak*
half of the claim.** A published build of this mod, cooked before the `0.9.5.0` AI rebuild, crashes
the game at load with a serialization error on the MeatMan class default object. That is the exact
failure Session 7 measured statically on the same object, confirmed on a third party's machine.

It says nothing about v1.4, which remains statically verified only.

## Provenance

- Reported over Discord DM, 2026-08-29 01:54 EDT (08:53 Europe/Kiev on the reporter's clock), by
  the community reporter the WORKLOG spells "Frnix" — the handle is **Fenix**. Same person who
  filed the still-open Grabber report.
- Two parts: the crash text, pasted into the message, and `UE4SS.log` (69.5 KB), attached.
- The log is a third party's machine log and is **not committed**: it sits in gitignored
  `work/reporter-UE4SS-2026-08-29.log`. The `LoginId` and `EpicAccountId` lines of the crash text
  are redacted below for the same reason.
- It sat unread in the DM through Sessions 6 and 7. Picked up 2026-09-20.

## The crash

```
LowLevelFatalError [File:G:\FW-staging\Engine\Source\Runtime\CoreUObject\Private\Serialization\AsyncLoading2.cpp] [Line: 1823]
ObjectSerializationError: /Game/FW/AI/Characters/Euruska/MeatMan/BP_AI_Euruska_MeatMan (0x7551B1DC4D4EECD5)
  /Game/FW/AI/Characters/Euruska/MeatMan/BP_AI_Euruska_MeatMan (0x7551B1DC4D4EECD5) - BP_AI_Euruska_MeatMan_C
  /Game/FW/AI/Characters/Euruska/MeatMan/BP_AI_Euruska_MeatMan.Default__BP_AI_Euruska_MeatMan_C:
  Bad import index 1996488703/198.
```

Then 27 frames of `ForeverWinter_Win64_Shipping`, `kernel32`, `ntdll`. `AsyncLoading2.cpp` is the
IoStore/Zen loader — the path a pak mod's container is read through.

## It is our package, and it is the CDO

- `0x7551B1DC4D4EECD5` is the `FPackageId` the engine prints as a u64. retoc prints the same id as
  little-endian bytes: `d5ec4e4ddcb15175`. That is line 22 of
  [`tools/expected_package_ids.txt`](../tools/expected_package_ids.txt) —
  `/Game/FW/AI/Characters/Euruska/MeatMan/BP_AI_Euruska_MeatMan`. **The crashing package is exactly
  the package this mod overrides**, by our own binding table.
- The failing object is `Default__BP_AI_Euruska_MeatMan_C` — the class default object. That is the
  same object Session 7 measured: 35 properties under live base, **19** under v1.3 read on live.

## The value

- `1996488703` = `0x76FFFFFF`. On disk, little-endian, those bytes read `FF FF FF 76`. The package's
  import table has **198** entries; the stream asked for entry ~2 billion.
- Three consecutive `FF` bytes followed by one unrelated byte is what a **null object reference**
  (`0xFFFFFFFF`) looks like when it is read late — the reader takes the tail of the null plus the
  head of whatever follows. Consistent with a misaligned stream; it is a tell, not a proof of
  byte-level (as against property-level) misalignment.
- Either reading gives the same conclusion, and it is the one Session 7 predicts. Of the 19
  properties that never decode on that CDO, the object references are
  `RootComponent`, `Mesh`, `CapsuleComponent`, `CharacterMovement`, `AIControllerClass`,
  `PawnComponentPrivate`, `AbilitySystemComponentPrivate`, `HealthComponentPrivate`,
  `PawnDefinition`, `AnimationDefinition`, `ThrowingSystem` — **every one of them an import-index
  read**. A desynchronised stream hits one of those and hands the loader a garbage index.

## What he was running

- **Mod:** v1.3 was the published build. Nexus #124 was updated to v1.3 on **24 August 2026**, five
  days before the crash, and still served v1.3 on 2026-09-20.
- **Game:** his `ForeverWinter-Win64-Shipping.exe` is 169,738,240 B (log header). SylDesk's exe at
  build `25071553` is 169,740,288 B — a different build. He was on the **`0.9.5.0` / `0.9.5.1`**
  build of 08-28, one day old at the time of the crash. No depot capture of it exists; per
  `tfw-update-ops/state/build-history.md` the intermediate manifests between `24536482` and
  `25071553` are unrecoverable.
- **`0.9.5.0` rebuilt the AI subsystem from the ground up** (ops repo, same file). v1.3's cook is
  from `24536482` — four days older than that rebuild.

## What the UE4SS log does and does not carry

- It is a startup log. It ends at `Event loop start` and records **no crash** — same as the
  2026-08-05 log, and for the same reason: a `LowLevelFatalError` is the game's, not UE4SS's.
- Useful anyway: UE **5.4** confirmed; mods running are `TFW_ExpandedQuestLimits` (C++),
  `BPModLoaderMod`, `DayNightSelector`, `Keybinds`; `TFWWorkbench`, `SoloRailGunMod`,
  `TFWStaggerControl` and `NoMinefields` are disabled in `mods.txt`. None of those ships a boss
  Blueprint.
- It does **not** enumerate mounted paks, so it cannot by itself prove which `153_` build was
  installed.

## What this settles, and what it does not

**Settles:**
- A pre-`0.9.5.0` cook of `BP_AI_Euruska_MeatMan` crashes `0.9.5.x` at load, in-game, on a machine
  that is not ours, with a serialization error on the CDO. The crash surface the index-shift
  mechanism predicts is real and is not a decoder artifact.
- The mechanism's blast radius is load-time, not use-time — the boss does not have to be
  encountered for the game to die on it.
- Same class as the v1.1 MeatMan crash (2026-07-10). Third time this repo has been bitten by a
  frozen cook on this exact asset.

**Does not settle:**
- Anything about **v1.4**. Its green is static: full coverage, 0 dangling references, 0 properties
  dropped, re-measured against live `25071553` on 2026-09-20. No launch.
- The **Grabber shooting crash** — that report is a *use*-time crash with a different shape. This
  one is at load. Still open, still no log for it.
- Strictly, that the mod caused this: one report, one machine, no pak listing in the log. Package
  identity, the CDO, the value, and the five-day-old publish date all point one way, and nothing
  points elsewhere.

## Correction: the schema move is a `0.9.5.0` event, not a 2026-09-10 one

Session 7, the CHANGELOG and the player readme all attribute the boss-class move to "the 2026-09-10
patch (build `25071553`)". **2026-09-10 is the day SylDesk downloaded it.** Build `25071553`
accumulates four announced versions — `0.9.5.0` (08-28), `0.9.5.1` (08-28), `0.9.5.2` (08-31),
`0.9.5.3` (09-02) — and landed on SylG5 on 09-03.

Session 7's usmap control brackets the move to somewhere in `24536482 → 25071553`. This crash dates
it to the **first** patch in that range, `0.9.5.0` on 2026-08-28, which is also the one whose notes
say the AI subsystem was rebuilt. Player-facing text corrected in v1.4's changelog entry and readme.
