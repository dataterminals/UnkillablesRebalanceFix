# Fix notes — what changed and how to test

Target build: **0.9.3.9.2** (24097213). Original mod: **Unkillables Rebalance 0.9.2.2** (Nexus #68).

## The change (hybrid rebuild of one pak)

The mod is a pure pak mod (`153_UnkillablesRebalance_P`) overriding 11 cooked boss/AI assets with **scalar
rebalancing** only. It was cooked for 0.9.2.2; on 0.9.3.9.2 three of the eleven base classes had drifted (gained
exports), so the stale overrides risked the HeavyRifle-style `ObjectSerializationError` and/or reverting base content.
The rebuild reproduces the **identical rebalance** on the current build, per-asset by risk tier:

| Assets | Action | Why |
|---|---|---|
| `MeatMan`, `OrgaMech`, `ShieldOfficer`, `Toothy`, + 4× `AIDEF_Euruska_Stalker*` (8) | **rebased** — the mod's own cooked version, re-emitted onto the current build (retoc `to-legacy` mod-wins → repath to `/Game` → `to-zen`) | current base is structurally identical to what the mod overrides; only the rebalanced scalar differs, so the mod class is safe. Values preserved as-shipped. |
| `MotherCourage`, `Opal`, `BPC_IncomingDamageMod` (3) | **patched current base** — extract the **current** base class, change only the rebalanced scalars (`tools/patch_drifted.py`), repack | base gained exports since 0.9.2.2 (141→182 / 385→417 / 464→497). Shipping the mod's stale bytecode here would revert that and risk a crash. This ships **current structure + only the rebalanced numbers**. |

The rebalanced values (identical to the original mod) are in [`rebalance-values.json`](rebalance-values.json):

- **Boss HP** (`FWHealthComponent.DefaultHealth`/`DefaultMaxHealth`, float32): MeatMan 330k, OrgaMech 286,870,
  ShieldOfficer 328k, Toothy 308,700, MotherCourage 372k, Opal 213k (all from 1e9 / 9e8).
- **Stalkers** (all 4 AIDEF DataAssets): `DamageToStagger` 20000→1000, `SyncKillMaxPlayerHealth` 2000→1000.
- **`BPC_IncomingDamageMod`**: 19 ordered Kismet **double** constants (armour/body-zone HP). The patcher is
  self-verifying — it asserts the current base double sequence equals the datamined order before writing, so a wrong
  split can't ship.

## How it was verified (without launching the game)

- `retoc verify` on the rebuilt container → **verified**.
- **FPackageIds 11/11 byte-identical** to the original working mod (`retoc manifest` diff) → the rebuilt overrides bind
  to the same base packages the working 0.9.2.2 mod did.
- Decoded in a full game + rebuilt-pak mount → **ok=11 fail=0** (imports resolve; no data loss):
  - Boss HP reads 330000 / 286870 / 328000 / 308700 / 372000 / 213000.
  - All 4 Stalkers read `DamageToStagger` 1000, `SyncKillMaxPlayerHealth` 1000.
  - `BPC` reads the 19 constants in exact order: 61870×4, 108700 (with 72000 at position 7), … 43000.
  - **Drifted 3 now report current base export counts** (MotherCourage **182**, Opal **417**, BPC **497**) — i.e. current
    structure, not the stale 0.9.2.2 subset.

## Install

Contents of `dist/UnkillablesRebalanceFix/` (the three `153_…` files) go where the original mod's pak went:
`…\The Forever Winter\Windows\ForeverWinter\Content\Paks\Mods\`. Remove the **original** mod's `153_` files first (don't
run both). Keep your pak-mod loader (Signature Bypass + UE4SS) current for 0.9.3.x; after a hotfix, clean-reinstall the
loader + pak (remove, don't just toggle). No TFWWorkbench dependency — this is a plain pak. Full player-facing notes in
`dist/readme.txt`.

## Test checklist (build 24097213)

1. **Baseline (optional):** original mod → watch for a crash / no-effect on a rebalanced boss. Fixed mod → neither.
2. Reaches main menu and loads a mission without crashing.
3. Each boss (MeatMan, OrgaMech, ShieldOfficer, Toothy, Mother Courage, Opal — non-HK) is staggerable and killable by
   weapons; no `ObjectSerializationError` for any `BP_AI_*` / `BP_Mech_Toothy` / `BPC_IncomingDamageMod`.
4. Grabber/Stalker: ~600-dmg swipe + disengage instead of an insta-kill grab (while you're above 1000 HP).
5. `…\Saved\Crashes\` stays empty.

## Known minor issues / caveats (not introduced by this fix)

- **Mother Courage / OrgaMech death freeze:** they sometimes freeze to an idle pose on death before despawning — a
  pre-existing behaviour the original author documents, not a crash and not from this rebuild.
- **Rebuild after future patches:** any hotfix that changes these boss classes can re-break the pak. Re-run
  `tools/build_fix.sh` (re-extracts/rebases onto the new build; the patcher aborts if base values moved).
- **Attribution:** original mod by its Nexus #68 author. This is a community compatibility fix; confirm the author's
  permission before any public redistribution.
