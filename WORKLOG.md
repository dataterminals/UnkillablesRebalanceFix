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

---

## 2026-08-01 — Session 4: rebuilt for hotfix build 24501089 (SylG5)

**Goal:** the shipped pak was found to REVERT the 2026-07-31 hotfix. Rebuild and verify.

### The finding, reproduced at the byte level
`dist/` was built 2026-07-20, so its Option-B extraction predates the hotfix. Confirmed independently
of the decoder, by string-searching the `to-legacy` output of both copies of `BPC_IncomingDamageMod`:

| name | live base | shipped (stale) |
|---|---|---|
| `Attack Add` | x3 | **x0** |
| `Modify Attack Add` | x1 | **x0** |
| `Big boi Sniper Rifles` | x1 | **x0** |
| `Noisy Player` | x1 | **x0** |

That is the 13 dropped property shapes stated in bytes. Installing the old pak put the pre-hotfix
component back — silently undoing the weapon damage buff.

### Machine portability — `build_fix.sh` could not run here at all
It hardcoded `H:` (SylDesk's NVMe), which does not exist on SylG5. Given the same per-machine
resolution `verify_build.sh` already uses: env override → candidate list, `D:` before `H:`, with the
script's own location as the first candidate for `REPO`. Not a find-and-replace, which would just
break SylDesk. `RETOC` is resolved the same way (`tools/retoc/` is gitignored, so a fresh checkout
has none; the sibling repos that vendored the same v0.1.5 are listed as fallbacks).

### Option-A source: `upstream/` is not on this machine
`upstream/UnkillablesRebalance_0.9.2.2/` holds the pristine Nexus pak, and its cooked binaries are
gitignored — deliberately, as third-party IP. So a checkout on a machine that never held the Nexus
archive does not have it, and SylG5 is exactly that. The build now falls back to the **previously
shipped `dist/` pak** for the 4 Stalker AIDEFs, which is sound because those 4 are upstream's own
payload already rebased once. It is only sound *because it is proven*, by two gates that are not
optional:
- **`[2b]` provenance gate** — the staged extract must carry the mod's `1000.0f` ×2, and must differ
  from the base extract. Measured: retoc extracts **both** colliding copies onto the same output
  path, so last-write-wins decides which survives. Without this gate a lost race ships base-HP
  Stalkers with no error anywhere.
- **`[6c]` regression gate** — the rebuilt AIDEF payloads came out **byte-identical** to the ones
  already shipping, all 4. That is what makes the substitution provably lossless.

### Two more gates added
- **`[6b]` isolated read-back.** The built pak is re-extracted mounted alone with `global.*`. No base
  copy present → no collision possible → the bytes are certainly the mod's. Measured: `.uexp`
  payloads are identical between an isolated and a staged extract; `.uasset` headers are not
  (isolation cannot resolve base imports), so compare payloads across mounts, headers only within.
- **`[7]` FPackageId parity** vs `tools/expected_package_ids.txt` (captured from the last known-good
  pak). An override binds by FPackageId, derived from the package path, so a moved id is a silent
  no-op override. This also pins the `Euruska/Toothy` casing the live build spells `TOOTHY` —
  Windows' case-insensitive filesystem hides a wrong-case copy, the id does not. 11/11 match.

### `verify_build.sh` — removed a false claim
Its pairing comment asserted that where the package path is byte-identical "the mod wins the lookup".
**That is not true**, and it was the most dangerous line in the file: both copies write to the same
filename and the last write wins, non-deterministically. Exact-case pairing does not help there
because there is only ever one file. Replaced with a real **provenance gate** — the shipped dump must
differ from the base dump, since every package this mod ships changes at least one scalar.
**Negative-tested:** swapping the base BPC dump in makes it FAIL (exit 1) where the old logic reported
`OK BPC 276/276 (+0)` — the exact false pass.

### Result — rebuilt and verified on 24501089
- Build: all gates green. `retoc verify` verified; 11 packages; `.ucas` **526,684 → 542,979 B**
  (`.pak` unchanged). Scalars re-applied and re-verified in order (19 BPC doubles, 6 boss HP pairs).
- `verify_build.sh`: **11 shipped packages, 17 dumps, 0 uncovered · 4519 references, 0 dangling ·
  0 properties dropped.** `BPC_IncomingDamageMod` now **276 base / 276 ship (+0)**, was dropping 13.
- Provenance confirmed by value, not just by hash: all 11 shipped dumps carry the mod's numbers and
  **none** of the base numbers — boss HP ×2 each with `1E+09` absent, Stalkers `1000` ×2, BPC
  `61870`×4 `108700`×7 `86870`×2 `128000`×3 `43000`×2 `72000`×1 = the 19 patched doubles.
- Deployed to MO2 hash-verified. Left **disabled** in `profiles/Default/modlist.txt` as found.

**Unchanged risk:** both checks are structural. Blueprint graph / Kismet bytecode changes move
neither the package path nor the property shape, so this does **not** clear the 4 Option-A Stalker
AIDEFs, still frozen at the mod's 0.9.2.2 cook. Separate and unresolved.

### Next (user)
- [ ] In-game test on 24501089 (never launched here — Steam `AutoUpdateBehavior 0`, so a launch
      risks pulling another build mid-work).
- [ ] Re-publish Nexus #124 with the v1.2 zip once the launch is green.

---

## 2026-08-05 — Session 5: Grabber shooting crash → the last 4 Option-A assets moved to Option B

**Report:** a community member (Frnix) says the game **crashes when shooting the Grabber**, and
others report issues too. No crash log yet (see "What the log did not show" below).

### Two separate problems, both real

**1. The pak is stale — the game patched.** Steam now reports build **24536482**; `dist/` was
built 2026-08-01 against **24501089**. Every Option-B asset in it was extracted from the old
build, so the pak is in exactly the state that caused the v1.2 incident (silently reverting a
hotfix). This alone explains "other people are having issues too" — a game patch breaks this
mod for everyone until it is rebuilt, which is the standing warning in `build_fix.sh`'s header.

**2. The Grabber crash points at the last Option-A holdouts.** The 4 Stalker AIDEF DataAssets
were the only assets still shipping the mod's **frozen 0.9.2.2 cook**, and the only
Grabber-specific assets in the pak. Session 4 left them flagged as "separate and unresolved".

**Why the justification for keeping them was wrong.** The comment in `build_fix.sh` /
`patch_drifted.py` read *"DataAssets carry no Kismet bytecode, so there is no
serialization-crash surface."* Absence of bytecode is not the relevant property. UE5 cooked
assets use **unversioned property serialization**: a property is identified by its **index in
the class's property schema**, not by name. If the AIDEF class gained / removed / reordered a
`UPROPERTY` since 0.9.2.2, the frozen bitstream decodes into the **wrong fields** — object and
soft-object pointers included. That is a property-layout problem, and it is if anything *worse*
for a bare DataAsset than for a BP, because the payload is almost entirely property data.

The failure that produces is a crash **when a mis-decoded field is dereferenced, not at load** —
which fits the report exactly: not a startup crash, not a spawn crash, but a crash when you
*shoot* it and the damage path reads `DamageToStagger` / the stagger + sync-kill fields.

This is the **same mistake twice**. 2026-07-10 it was "export counts match, so the cook is
safe" (MeatMan crashed). 2026-08-05 it is "no bytecode, so the cook is safe". Both were
reasoning about why a frozen cook *ought* to load, in place of evidence that it does.

### What the log did not show — being straight about it
A `UE4SS_8.log` was supplied from SylG5. It contains **no crash and no
`ObjectSerializationError`**: it runs 16:45:32 → 16:47:37, loads AshenMesa, and stops with no
shutdown line. That abrupt end is *consistent* with a hard crash but proves nothing, and UE4SS
does not capture UE serialization errors in the first place — those land in `…\Saved\Crashes\`
and `…\Saved\Logs\ForeverWinter.log`. Its 3 `FAILED` lines are benign (2 StaggerControl hook
retries, 1 known UE4SS signature miss). **So the diagnosis above is still inference, not a
confirmed root cause.** Get the real crash log before publishing.

Also noted from that log, as an interaction to rule out rather than a finding: a Lua mod
**`TFWStaggerControl`** is hooking `GA_Player_HitReaction:K2_ActivateAbility` and
`BP_PlayerBase:ReceiveAnyDamage` — the same *stagger* subsystem, though on the player side, not
the Grabber's.

### The change (repo work only — nothing was built or launched this session)
Built on a Linux container with no game and no retoc, so **no pak was produced and no claim
below is runtime-verified**.

- **New `tools/patch_stalker_aidef.py`** — patches the 4 AIDEFs from current base:
  `DamageToStagger` 20000→1000, `SyncKillMaxPlayerHealth` 2000→1000 (float32). Self-verifying
  like `patch_drifted.py`: each base value must occur **exactly once** per file or it aborts.
  Resolves both offsets against the unmodified buffer before writing, because the mod sets both
  scalars to the *same* value (1000.0f) and a chained replace would re-match its own output.
- **`tools/build_fix.sh` — Option A retired entirely.** All 11 packages now come from the live
  game. Removed: the `MODSRC`/`upstream/` resolution block, the `zzz_` collision staging, the
  `[2b]` provenance gate, and with them the **~48 GB hardlink staging** (only `global.*` is
  linked now, for the isolated read-back). `scriptobjects.bin` now comes from the base extract.
  Steps renumbered to `/6`.
- **`[5c]` content gate A is INVERTED.** It demanded the AIDEFs be byte-**identical** to the
  shipped pak; under Option B they must **differ**. Left as-is it would have failed every
  correct build.
- **New `[2b]` drift diagnostic** — prints base-vs-frozen `.uexp` sizes and the string-set
  difference for each AIDEF, the same evidence shape that proved MeatMan (5931 vs 5904 B, base
  having gained `"Sync Kill in Log"`). Evidence only; it does not gate.
- `expected_package_ids.txt` **unchanged** — retoc derives the id from the destination package
  path and that path has not moved, so `[6]` must still report 11/11. If it does not, the
  assemble step wrote somewhere new.

### A bug the tests caught before it shipped
Gate A was first written as "exactly 8 bytes must differ from base" — 2 × float32. That is
**wrong**: two float32s *occupy* 8 bytes, but how many bytes *change* depends on the values.
`20000→1000` moves 3 bytes and `2000→1000` moves 1, so a correct build differs by **4**, and the
gate would have rejected it. Replaced with a semantic check: locate each base scalar, require
the mod value there, and require every other byte to be untouched. Found by running the gate
against synthetic fixtures — the patcher and the gate were both exercised that way (happy path,
moved base default, ambiguous pattern, re-run, unpatched variant, over-patch, fresh checkout).

### Next (user) — nothing here is verified until these run
- [ ] Get Frnix's actual crash log (`…\Saved\Crashes\`, `ForeverWinter.log`). Confirm it names a
      Stalker AIDEF. If it names something else, this diagnosis needs revisiting.
- [ ] `bash tools/build_fix.sh` on 24536482. If `patch_stalker_aidef.py` aborts on a count
      assertion, the devs moved a base default — re-datamine and update `rebalance-values.json`.
- [ ] Paste the `[2b]` diagnostic output into this log; correct
      `rebalance-values.json`'s `stalker_aidef.structural_drift` from what it actually measures.
- [ ] `bash tools/verify_build.sh` → expect 0 dangling, 0 dropped.
- [ ] In-game on 24536482: **shoot a Grabber repeatedly** (Frnix's exact repro), bosses killable,
      `…\Saved\Crashes\` empty.
- [ ] Only then: regenerate the zip and publish v1.3.

---

## 2026-08-23 — Session 6: built on 24536482, and the Session-5 diagnosis retracted (SylG5)

**Goal:** the repo had sat since 2026-08-01 stamped to `24501089`; Session 5 (2026-08-05, remote,
no game and no retoc) had rewritten the pipeline for a Grabber shooting-crash but produced no pak.
This machine has the game at **24536482**, retoc v0.1.5, the CUE4Parse decoder, and a usmap already
regenerated for 24536482 in the sibling datamine repo. So: build it, and check the claims.

### Result: the pak is built and clean
- `build_fix.sh`: all gates green. `retoc verify` verified; 11 packages; `[6/6]` **11/11** package
  ids match `expected_package_ids.txt`.
- `verify_build.sh`: **11 shipped packages, 17 dumps, 0 uncovered · 4525 references, 0 dangling ·
  0 properties dropped.**
- Scalars re-applied and re-verified in order: 19 BPC doubles, 6 boss HP pairs, 4 AIDEF pairs.
  Health unchanged — 330000 / 286870 / 328000 / 308700 / 372000 / 213000; Stalkers 1000/1000.

### What the rebuild actually fixes — measured, and it is only one package
Comparing the old shipped pak's payloads against the new build, **10 of the 11 packages are
byte-identical**. The single exception is `BPC_IncomingDamageMod`: uexp **72,145 → 80,724 B**.

Decoding the *old* pak inside a full **live 24536482** mount (staged as `zzz_URF_P`, so it is the
mod's copy that resolves — confirmed by value: it carries the mod's `61870`/`128000` and the base
does not) gives the regression directly rather than by inference:

| BPC_IncomingDamageMod, decoded vs live 24536482 | property shapes | dropped |
|---|---|---|
| live base | 285 | — |
| **new** pak (this build) | 285 | **0** |
| **old** pak (24501089, currently shipping) | 276 | **9** |

The 9 the old pak drops:

```
[].FuncMap.Check if Weapon Silenced      (+ .ObjectName, .ObjectPath)
[].FuncMap.Clean Up Damaged Foes         (+ .ObjectName, .ObjectPath)
[].ChildProperties[].Inner.Struct        (+ .ObjectName, .ObjectPath)
```

The name-table diff says what the patch did: `MakeAINoise` → **`MakeAINoiseForFactions`**, plus
`WeaponUsesSilencer` / `Check if Weapon Silenced`, `Damaged Foes` / `Damaged Foe Factions` /
`Clean Up Damaged Foes`, and `MakeGameplayTagContainerFromArray`. So 24536482 made the noise a
damaged enemy raises **faction-aware and suppressor-aware**, and the shipping pak reverts it. Same
failure class as the v1.2 incident, one build later — and it is the standing consequence of a mod
that ships whole copies of game files.

### The Session-5 Grabber diagnosis is wrong. Retracted.
Session 5 moved the 4 Stalker AIDEFs from Option A to Option B because a frozen 0.9.2.2 cook would
mis-decode against a drifted class schema and crash when a field is dereferenced — i.e. when you
shoot it. The precondition is that the class drifted. **It did not.** Byte comparison, three ways:

| AIDEF | uexp len | base vs rebuilt | rebuilt vs previously shipped |
|---|---|---|---|
| `AIDEF_Euruska_Stalker` | 206 B | 4 bytes @ 102,103,104,136 | **0 — identical** |
| `AIDEF_Euruska_Stalker_HK` | 205 B | 4 bytes @ 100,101,102,134 | **0 — identical** |
| `AIDEF_Euruska_Stalker_Pregnant_Quest` | 202 B | 4 bytes @ 98,99,100,132 | **0 — identical** |
| `AIDEF_Euruska_Stalker_Underground` | 202 B | 4 bytes @ 98,99,100,132 | **0 — identical** |

Those 4 bytes are exactly the 2 rebalanced scalars (`20000→1000` moves 3 bytes, `2000→1000` moves
1 — the count Session 5 correctly derived when it fixed its first gate formulation). Same length,
same string set, same layout. The frozen cook and the current base cook agree byte for byte, so
these files were never mis-decoding and the stated mechanism cannot have applied to them.

`[2b]`'s output, which Session 5 asked to have pasted here, says the same thing and is worth
reading carefully because its wording oversells it: it reports `delta +0` on every length and
`payloads DIFFER`, annotated *"same string set — the difference is in values/layout, not names"*.
The difference is neither values-in-general nor layout: it is precisely the 2 scalars the mod
patches. `[2b]` cannot tell "drift" from "the rebalance we ourselves applied", so on its own it is
not the evidence it was designed to be. The three-way comparison above is.

**Option B is kept for the AIDEFs** — nothing frozen should remain in the pipeline, and it drops the
`upstream/` requirement for good — but it must be described as what it is: a **no-op in shipped
bytes**, not a fix. `rebalance-values.json` now records `stalker_aidef.structural_drift: false` with
a `structural_drift_basis` saying it was *measured*, replacing a flag stamped from 24097213 export
counts that could not have seen this either way.

**So the reported "crash when shooting the Grabber" has no established cause.** The stale BPC above
is real, is in the damage path, and is a plausible contributor — but that is a different claim, and
it should not be published as the Grabber fix.

### A gate that would have rejected every correct build
`[5c]` gate A asserted the AIDEFs must **differ** from the previously shipped pak, on the reasoning
that under Option B an unchanged payload meant the strategy change had not taken effect. That is an
assumption about the game, not a property of the build, and it is false here: the first run of this
session **failed on all 4** with `FAIL payload is UNCHANGED … the Option-A -> Option-B move did not
take effect`, when the build was correct.

This is the same defect Session 5 caught once already in the same gate ("exactly 8 bytes differ"),
one level up: both encoded a guess about what the bytes would look like instead of asserting the
contract. The safety property — *current base cook, only the 2 scalars moved*, checked against the
pristine live-game extract — passed on all 4 and is what actually rules out shipping a frozen cook.
The differ-clause is now a **drift report**, not a gate. The identical BPC clause below it had the
same flaw (a patch that does not touch the BPC would make a correct rebuild "fail") and got the same
treatment.

### Notes
- `dist/` had to be restored from git between the two runs: step `[5]` writes the new pak into
  `dist/` before `[5c]` runs, so a failed build leaves `dist/` overwritten and the *next* run's
  step `[1]` would snapshot **that** as the regression baseline. Confirmed the restored copy against
  the committed blob (`md5 fe37303098c2b3c61572e9756b7446e9`) before re-running.
- No game launch. Steam still has `AutoUpdateBehavior 0`; the build already moved once mid-project.

### Next (user)
- [ ] In-game on 24536482: **shoot a Grabber repeatedly** (the reported repro — now an open
      question, not a confirmed fix), bosses staggerable and killable, `…\Saved\Crashes\` empty.
- [ ] Get the crash log from Frnix if the report stands. It is still the missing evidence, and the
      AIDEF theory is now excluded rather than merely unconfirmed.
- [ ] Publish v1.3 to Nexus #124 once the launch is green. The CHANGELOG entry is rewritten around
      the BPC regression, which is the claim that survives.

---

## 2026-09-11 — Session 7: built on 25071553, and the index-shift mechanism finally measured (SylDesk)

**Goal:** the game patched on 2026-09-10 (Steam `buildid` **25071553**, paks dated 14:22) while `dist/`
was stamped to `24536482`. Rebuild, and measure what the stale pak does on the new build.

The sibling datamine repo had already re-dumped the usmap at 14:52 the same day, and its
`provenance.json` flags this patch as one that **moved type layouts** — the old map went stale
*silently*, truncating `FWWeaponDefinition` from 57 properties to 30. That is the warning shot for
this repo: whatever moved a weapon class can have moved an AI class.

### Result: clean build, clean verify
- `build_fix.sh`: all gates green. 11 packages, `[6/6]` **11/11** package ids match
  `expected_package_ids.txt`. Scalars re-applied and re-verified in order — 19 BPC doubles, 6 boss
  HP pairs, 4 AIDEF pairs. Health unchanged: 330000 / 286870 / 328000 / 308700 / 372000 / 213000;
  Stalkers 1000/1000.
- `verify_build.sh`: **11 shipped packages, 16 dumps, 0 uncovered · 3165 references, 0 dangling ·
  0 properties dropped** against live 25071553.
- Payload diff v1.3 → v1.4: the 4 Stalker AIDEFs are **byte-identical**; the 6 boss BPs and the BPC
  each move 3–5 bytes with **no name-table change on any of them** (`+0 / -0` strings). The packages
  barely moved. What moved is the schema they serialise against.

### What the 25071553 patch actually does to the stale pak — measured, with a control
Decoding the **v1.3 pak** inside a full live 25071553 mount (staged `zzz_URF_P`; provenance confirmed
by value — the dump carries the mod's 330000 / 286870 / 213000 / Stalker 1000.0 and the live base
does not):

| `Default__BP_AI_Euruska_MeatMan_C` | CDO properties |
|---|---|
| live base, live usmap | **35** |
| **v1.4** pak (this build), live usmap | **35** |
| **v1.3** pak, live usmap | **19** |
| **v1.3** pak, archived `24536482` usmap | **35 — coherent** |

That last row is the control, and it is what makes this a measurement rather than a story: the same
bytes decode perfectly under the retired schema and desynchronise under the live one. The pak is not
corrupt. The class layout moved underneath it.

All 6 boss BPs, same shape — divergence begins at the same property on every one of them:

| boss CDO | base | v1.4 | v1.3 on live | lost | decoded under a wrong name | diverges at |
|---|---|---|---|---|---|---|
| MeatMan | 35 | 35 | **19** | 19 | 3 | `FarDistance` |
| OrgaMech | 31 | 31 | **15** | 19 | 3 | `FarDistance` |
| ShieldOfficer | 29 | 29 | **13** | 19 | 3 | `FarDistance` |
| Toothy | 17 | 17 | 17 | 8 | 8 | `CloseDistanceRadiusScalar` |
| MotherCourage | 32 | 32 | **20** | 17 | 5 | `CloseDistanceRadiusScalar` |
| Opal | 41 | 41 | **25** | 19 | 3 | `FarDistance` |

Toothy is the one to read carefully: its property *count* is unchanged at 17, and 8 of those 17 are
values sitting under the wrong name. A count-based gate would have passed it — the same lesson as
2026-07-10, when matching export counts got MeatMan classed "low-risk" and it crashed.

Whole-package property shapes tell the same story (base → v1.3-on-live): MeatMan 290 → 248, OrgaMech
285 → 243, ShieldOfficer 292 → 250, Toothy 268 → 250, MotherCourage 317 → 281, Opal 296 → 256.

The failure is the textbook one for unversioned property serialization, and it is worth recording in
detail because the repo has twice reasoned about this mechanism without seeing it. Reading MeatMan's
CDO with the live schema, the stream tracks correctly for 14 properties, then slides:

```
  live base (25071553)                     the SAME v1.3 bytes, read under it
  ------------------------------------     ------------------------------------
  [13] bCanMoveBackwards        false      [13] bCanMoveBackwards        false   <- last agreement
  [14] FarDistance              750.0      [14] CloseDistanceRadiusScalar 750.0
  [15] MinSpeed                 150.0      [15] FarDistance              150.0
  [16] MaxSpeed                 150.0      [16] MinSpeed                 150.0
  [17] MaxExtraTurnVel           90.0      [17] MinTurnAngle              90.0
  [18] MoveTargetInterpolateTime  0.5      [18] EngagementDistance         0.5
```

The value sequence is intact — `750, 150, 150, 90, 0.5` — and every one of them lands **one name
late**. That is an index shift and nothing else; a corrupt payload does not preserve the values in
order while relabelling them.

and then it runs off the end: **19** properties never decode at all, while 3 wrong ones appear in
their place — a net 35 → 19. The 19 lost are
`MaxSpeed`, `MaxExtraTurnVel`, `MoveTargetInterpolateTime`, `ThrowingSystem`, `AnimationDefinition`,
`SprintingSpeedModifier`, `RootBoneName`, `MeleeAttackDamage`, `bEnableTickThrottle`,
`PawnDefinition`, `PawnComponentPrivate`, `AbilitySystemComponentPrivate`, `HealthComponentPrivate`,
`Mesh`, `CharacterMovement`, `CapsuleComponent`, `AIControllerClass`, `RootComponent`, `Tags`.

A boss CDO with no `RootComponent`, no `Mesh`, no `CapsuleComponent` and no `AIControllerClass` is
the same shape of breakage as the v1.1 MeatMan startup crash (`ObjectSerializationError` / bad export
index). **Caveat, stated plainly:** this is the decoder's view under the live usmap, not an observed
in-game crash. It is the strongest static evidence this repo has ever had — including a control that
rules out the pak itself — but the in-game test is still the arbiter, and it is still outstanding.

### What did *not* move
- **The 4 Stalker AIDEFs**: 50/51/50/50 shapes, base and both paks; byte-identical v1.3 → v1.4. That
  class did not move in this patch either. `structural_drift: false` stands.
- **`BPC_IncomingDamageMod`**: 285 shapes in base, in v1.4 **and in v1.3** — **0 dropped**. Unlike
  24536482, this patch took nothing out of the BPC. Its decoded values differ from base by exactly
  the mod's own 19 `Codex AI to Disable Health Threashold` doubles and nothing else, on both paks.
  The 4 raw bytes that moved in its `.uexp` are outside the decoded property set (bytecode//index
  region), and its `.uasset` shrank 6 B with an identical string set — consistent with script-object
  index shifts, not a content change.

So v1.3's damage is confined to the 6 boss Blueprints — but there it is total, not cosmetic.

### Notes
- Method reused from Session 6 (stage the old pak as `zzz_URF_P` in a hardlinked full-game mount,
  decode, compare against the base dump), plus the new usmap control leg. `verify_build.sh` hardcoded
  `PAKDIR` to `dist/`, so the old-pak legs were run by hand against `work/prev-dist/` — for the third
  build running. **Fixed:** `PAKDIR` is now an env override like every other path in that script, so
  `PAKDIR=$REPO/work/prev-dist bash tools/verify_build.sh` takes the regression measurement directly.
  The usmap control leg (decode the old pak under the archived usmap for its own build) is still by
  hand; the archived maps live in the datamine repo's `mappings/archive/`.
- `dist/` was pristine at HEAD before the run (`md5 0da77f6f5910e584aa582ca9539f5f1c` on the v1.3
  `.ucas`), so the step-[1] regression baseline is trustworthy.
- The dist zip now stores the readme with **CRLF**; the previous zips shipped it LF-only inside a
  Windows-only archive.
- No game launch this session.

### Next (user)
- [ ] In-game on 25071553: bosses spawn with model/collision/behaviour intact, staggerable and
      killable, `…\Saved\Crashes\` empty. If v1.3 is still installed anywhere, expect it to break
      first — that is the prediction this session makes.
- [ ] Shoot a Grabber repeatedly (still an open report, still no established cause, still needs a
      crash log).
- [ ] Publish v1.4 to Nexus #124 once the launch is green.
