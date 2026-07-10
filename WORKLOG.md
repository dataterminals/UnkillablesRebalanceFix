# Unkillables Rebalance — Fix Worklog

Running tally of what we find and do. Newest entries at the bottom.

---

## 2026-07-09 — Session 1: recon, repo setup & diagnosis

**Goal:** repair the "Unkillables Rebalance" mod (Nexus #68, The Forever Winter) so it works on the current game build,
mirroring the `HeavyRifleRebalanceFix` workflow.

### Environment
- Game build (live, this machine): **24097213 = Hot-Fix 0.9.3.9.2**.
- Mod ships for game **0.9.2.2** (Nexus filename `UnkillablesRebalance-68-0-9-2-2-...`; files dated Feb 2026).
- Datamine toolchain: `H:\Github Repositories\forever-winter-datamine` (CUE4Parse decoder + `ForeverWinter-5.4.2.usmap`).
- Extractor: `7z.exe` (`C:\Program Files\7-Zip`).

### What the mod is (pure pak mod)
Single container `153_UnkillablesRebalance_P` (`.pak` 347 B / `.ucas` ~495 KB / `.utoc` 1.6 KB) — **no** TFWWorkbench
JSON, **no** loose files, **no** meshes. Standalone mount = **11 overrides**:
- 6 boss BPs: `BP_AI_Euruska_MeatMan`, `_OrgaMech`, `_ShieldOfficer`, `BP_Mech_Toothy`, `BP_AI_Eurasia_MotherCourage`,
  `_Opal`.
- 4 Stalker AI DataAssets: `AIDEF_Euruska_Stalker` + `_HK` / `_Pregnant_Quest` / `_Underground`.
- 1 shared component BP: `BPC_IncomingDamageMod`.

### Decode method
CUE4Parse dumps of GetExports (usmap 5.4.2). Three mounts:
1. **base-only** (game Paks) → vanilla values.
2. **staging-full** (base hardlinks + mod renamed `zzz_`) → confirmed the mod adds +11 vfs entries (mounts at bare
   paths, like HeavyRifle's 152). Basename collisions in the output made this mount unreliable for value diffing — all
   16 came out "SAME" because the `/Game` base entries won the output-file collision, not the mod.
3. **global + mod** (only `global.*` + the mod pak) → the mod's **true** 11 versions, collision-free. `ok=11 fail=0`.
   Diffed vs base-only. (Isolated-mount `null`/`-index` imports are artifacts, filtered out.)

### What the mod actually changes (the rebalance — ground truth)
De-invincibles the billion-HP bosses + defangs the Grabber. Full map in `docs/rebalance-values.json`:
- **Boss HP** (`FWHealthComponent.DefaultHealth`/`DefaultMaxHealth` in each BP CDO): MeatMan 1e9→**330k**,
  OrgaMech 1e9→**286,870**, ShieldOfficer 1e9→**328k**, Toothy 9e8→**308,700**, MotherCourage 1e9→**372k**,
  Opal 1e9→**213k**.
- **Stalkers** (all 4 AIDEF): `DamageToStagger` 20000→**1000** (20× easier to stun), `SyncKillMaxPlayerHealth`
  2000→**1000** (no insta-kill grab above 1000 hp).
- **`BPC_IncomingDamageMod`**: 19 ordered Kismet `EX_FloatConst`s (armour/body-zone HP) scaled down
  (168700→61870/108700, 210000→72000/43000, 283500→128000, 330000→128000, 126000→86870). The 19 small ints (1–9) are
  unchanged segment counts.
- Corroborated verbatim by the mod's public Nexus description (stunnable+killable bosses; 600-dmg Grabber swipe).

### Root cause (static): cooked-asset version drift
Pak overrides bind to base by FPackageId, so the game runs the mod's **0.9.2.2-cooked** class. Export-count check
(mod vs current base):
- **8 low-risk** (identical structure, only the scalar differs): MeatMan 71=71, OrgaMech 73=73, ShieldOfficer 122=122,
  Toothy 783=783, + the 4 DataAssets.
- **3 drifted** (base grew exports): **MotherCourage 141 vs 182 (+41)**, **Opal 385 vs 417 (+32)**,
  **BPC_IncomingDamageMod 464 vs 497 (+33)**. Same failure class as HeavyRifle's `BP_WPN_HRF05`
  (`ObjectSerializationError`). Shipping stale versions here reverts base content and risks a crash. Notably
  MotherCourage/OrgaMech are the two the author already flags as freezing on death.

**Exact runtime symptom on 24097213 not yet confirmed** — could be hard crash (drifted boss spawns), silent no-op
(override fails to bind → bosses stay at 1e9), or loads-but-reverted. The low-risk 8 almost certainly still apply.
Arbiter = an in-game launch, as with HeavyRifle.

### Repo scaffold (this session)
- `upstream/UnkillablesRebalance_0.9.2.2/` — pristine `153_` pak (cooked binaries gitignored) + original `.7z`.
- `docs/diagnosis.md`, `docs/rebalance-values.json`, `README.md`, `WORKLOG.md`, `.gitignore`. `dist/`, `tools/`, `work/`
  present (empty / scratch).

### Fix strategy (documented, not yet built)
Rebalance is pure scalars → a pak is unavoidable (JSON can't express BP CDO health or bytecode constants). Two paths
(see diagnosis): **A** rebase the mod's overrides via retoc (clean for the 8, still stale for the 3); **B** patch the
**current base** scalars via retoc `to-legacy` → byte-patch → `to-zen` (most correct, no drift; more work). Likely
hybrid: A for the 8, B for the drifted 3. **retoc is not on this machine** (was gitignored on the D: machine that built
HeavyRifle) — a build needs it fetched (trumank/retoc v0.1.5) + a launch on 24097213 to verify.

### BUILD — fixed pak built (user chose **Hybrid**; game not launched)
Tooling: **retoc v0.1.5** (trumank/retoc, sha256 `cc036b06…d263aa` verified) in `tools/retoc/` (gitignored).

**Strategy = hybrid** (see `docs/fix-notes.md`, reproducible via `tools/build_fix.sh`):
- **8 low-risk assets** (MeatMan, OrgaMech, ShieldOfficer, Toothy + 4 Stalker AIDEFs): rebase the MOD's version —
  `to-legacy` from the base+`zzz_`mod mount (mod wins) → the extracts land at BARE paths (mod stores bare, like
  HeavyRifle's 152) → **repath to real `/Game` paths** (retoc derives FPackageId from path) → `to-zen`. Verified the
  extracts already carry the mod HP (MeatMan 330000 ×2, etc.) and Stalker 1000s.
- **3 drifted assets** (MotherCourage, Opal, BPC): `to-legacy` the **current base** → `tools/patch_drifted.py` (health:
  1e9 float32 ×2 → 372000 / 213000; BPC: 19 ordered **doubles**) → repack. The constants are UE5 doubles, not float32
  (0 float32 hits, exact double counts 168700×11/210000×3/126000×2/283500×2/330000×1 = 19). Patcher is self-verifying:
  asserts the base double sequence == the datamined index order (20–38) before writing, so a wrong 168700→61870/108700
  or 210000→72000/43000 split can't ship.

**Verified without launching:**
- `retoc verify` → verified. `to-zen` → `153` (.pak 347 B / .ucas 526 KB / .utoc 2 KB).
- **FPackageIds 11/11 byte-identical to the original working mod** (`retoc manifest` diff) → binds to the same base
  packages the 0.9.2.2 mod did.
- Isolated (global + rebuilt) decode: **ok=11 fail=0**; HP 330000/286870/328000/308700/372000/213000; all 4 Stalkers
  1000/1000; BPC 19 constants in exact order (61870×4 … 43000). **Drifted 3 now report CURRENT base export counts
  (182 / 417 / 497)** — current structure, stale-subset eliminated.
- Full game+rebuilt mount decode: **ok=27 fail=0** (imports resolve, no data loss — clears the to-zen isolated-null caveat).

**Delivered:** `dist/UnkillablesRebalanceFix/` (rebuilt `153` + `readme.txt`). `docs/fix-notes.md` = what changed +
install + test checklist. Repo `dist/` tracked (ships the repaired pak), scratch (`work/`, `tools/retoc/`) gitignored.

### Next (user)
- [ ] Install `dist/` pak + current loader (Signature Bypass + UE4SS); launch build 24097213; run the
      `docs/fix-notes.md` checklist (kill each boss; Grabber swipe-not-grab; no `ObjectSerializationError`).
- [ ] Report any residual crash (would mean another asset needs the same treatment).
- [ ] (optional) confirm original-author permission before any public redistribution.

---

## 2026-07-10 — In-game arbiter fired: MeatMan crash → 4 boss BPs moved Option A→B, rebuilt

**The pending in-game test happened (via a community member) and it CRASHED** — exactly the risk
Session 1 flagged for the "low-risk 8." A player running this fix (#124) + HeavyRifleRebalanceFix
(#123) + a hub-upgrade mod hit, on the current build:

```
ObjectSerializationError: /Game/FW/AI/Characters/Euruska/MeatMan/BP_AI_Euruska_MeatMan
  (0x7551B1DC4D4EECD5) ... Default__BP_AI_Euruska_MeatMan_C: Bad export index 1066192076/32.
```

Triage: removing the #124 pak **boots clean** (community-confirmed). HeavyRifleRebalanceFix is
cleared (ships zero AI assets; the MeatMan FPackageId is absent from its 30 packages). The hub mod is
UE4SS data (no pak). So #124 is the culprit — its `BP_AI_Euruska_MeatMan` override.

**Why the Session-1 "low-risk" call was wrong for the boss BPs.** MeatMan was rebased via Option A on
"71=71, structurally identical" reasoning. But the deserialization-relevant export count is **32**
(CUE4Parse GetExports == the runtime's `/32`); the "71" in the drift table was a different IoStore
metric. Decode-diff of the shipped (Option-A) MeatMan vs current base: base uexp **5931 B**, shipped
**5904 B** — current base is a small **superset** (gained a `"Sync Kill in Log"` element post-0.9.2.2).
So the mod's 0.9.2.2 cook is a stale subset whose cooked references desync at runtime → bad export
index → crash. **Export-count parity ≠ a safe cook** — the HRF05 lesson, now proven on an asset we'd
filed as low-risk.

**Fix = move all 4 Option-A boss BPs to Option B.** `tools/build_fix.sh` + `tools/patch_drifted.py`
updated: only the 4 Stalker AIDEF **DataAssets** stay Option-A rebased (no Kismet bytecode → no
serialization-crash surface); **all 6 boss BPs + BPC now patch the CURRENT base** (extract current
base → byte-patch only the scalars → to-zen). Health unchanged from the intended rebalance: MeatMan
330k, OrgaMech 286,870, ShieldOfficer 328k, Toothy 9e8→308,700 (+ MotherCourage 372k, Opal 213k as
before).

**Rebuilt & verified (static):**
- `retoc verify` → verified. 11 packages, MeatMan (`d5ec4e4ddcb15175`) present, FPackageIds preserved.
- Each of the 6 boss BPs is now **byte-identical to current base except exactly its 2 health floats**
  (8-byte diff) — the same cook the game loads in vanilla, so it cannot fail deserialization. MeatMan
  is back to 5931 B with `"Sync Kill in Log"`.
- Isolated global+mod decode: **ok=11 fail=0**; HP 330000/286870/328000/308700/372000/213000; all 4
  Stalkers 1000/1000; BPC 19 ordered doubles verified.
- Full game+mod mount decode: imports resolve, **fail=0**.

**Still pending:** the actual in-game re-test (spawn each boss → killable, Grabber swipe-not-grab, no
`ObjectSerializationError`). Structurally the crash is eliminated; a launch is the final arbiter.

> **In plain terms:** A player's game crashed because of this mod, on a boss called the "Meatman."
> The mod was shipping an out-of-date copy of that boss (and the other bosses), built for an older
> game version, so the current game choked trying to load it. We rebuilt those bosses from the
> *current* game files and changed only their health numbers — so they're guaranteed to load now,
> just with the killable HP the mod intends. It still needs one real in-game test to tick the last
> box, but the crash cause is gone.

### Next (user)
- [ ] Swap the rebuilt `dist/` pak in; launch the current build; spawn MeatMan / OrgaMech /
      ShieldOfficer / Toothy / MotherCourage / Opal → each killable, Grabber swipes (no insta-grab),
      **no `ObjectSerializationError`**.
- [ ] Regenerate the dist zip + re-publish #124 once the launch is green.
