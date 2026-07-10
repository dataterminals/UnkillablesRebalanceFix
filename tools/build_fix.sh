#!/usr/bin/env bash
# Rebuild the fixed 153_UnkillablesRebalance_P pak (HYBRID strategy):
#   - 4 Stalker AIDEF DataAssets  -> rebase the MOD's version onto the current build. DataAssets
#     carry no Kismet bytecode, so there is no serialization-crash surface; only 2 scalars differ.
#   - ALL 6 boss BPs + BPC        -> patch the CURRENT BASE version's scalars in place (Option B,
#     tools/patch_drifted.py): MeatMan, OrgaMech, ShieldOfficer, Toothy, MotherCourage, Opal +
#     BPC_IncomingDamageMod. Ships current 0.9.3.9.2 structure with ONLY the rebalanced values.
#   NOTE (2026-07-10): the 4 boss BPs (MeatMan/OrgaMech/ShieldOfficer/Toothy) were MOVED from the
#   Option-A rebase group to Option-B after the mod's stale 0.9.2.2 MeatMan cook crashed in-game on
#   0.9.3.9.2 (community-confirmed ObjectSerializationError / Bad export index) — the same HeavyRifle
#   HRF05 failure class. Matching export counts did NOT make the stale cook safe to ship.
#
# Requires: retoc (tools/retoc/retoc.exe, v0.1.5), the game installed, python3.
# Re-run after a future patch that re-breaks the pak (re-extracts/rebases onto the new build).
set -euo pipefail

REPO="H:/Github Repositories/UnkillablesRebalanceFix"
GAME_PAKS="H:/SteamLibrary/steamapps/common/The Forever Winter/Windows/ForeverWinter/Content/Paks"
AES="0x84B2244BE0AF90C22976D739FA0665569219F4CEA119CEA37C81F2D9ABEE4795"
RETOC="$REPO/tools/retoc/retoc.exe"
PY="${PY:-python}"
UP="$REPO/upstream/UnkillablesRebalance_0.9.2.2"   # vendored original pak (cooked binaries restored from Nexus #68)

STAGE="$REPO/work/staging-full"; LEGA="$REPO/work/legacy-A"; LEGB="$REPO/work/legacy-B"
BUILD="$REPO/work/build-legacy"; CONTENT="$BUILD/ForeverWinter/Content"
OUT="$REPO/dist/UnkillablesRebalanceFix"

# Option A (rebase mod's version): only the Stalker AIDEF DataAssets (-f prefix matches all 4 variants).
LOWRISK="AIDEF_Euruska_Stalker"
# Option B (patch current base): all 6 boss BPs + the shared BPC component.
BASEPATCH="BP_AI_Euruska_MeatMan BP_AI_Euruska_OrgaMech BP_AI_Euruska_ShieldOfficer BP_Mech_Toothy BP_AI_Eurasia_MotherCourage BP_AI_Eurasia_Opal BPC_IncomingDamageMod"

echo "[1/6] stage current game (hardlinks) + original mod renamed zzz_ (wins the FPackageId collision)"
rm -rf "$STAGE"; mkdir -p "$STAGE"
for f in "$GAME_PAKS"/*; do [ -f "$f" ] && ln "$f" "$STAGE/$(basename "$f")"; done
for e in pak ucas utoc; do cp "$UP/153_UnkillablesRebalance_P.$e" "$STAGE/zzz_UnkillablesRebalance_P.$e"; done

echo "[2/6] to-legacy the Stalker AIDEFs MOD-won (mod wins; imports resolve vs current base)"
rm -rf "$LEGA"; mkdir -p "$LEGA"
for k in $LOWRISK; do "$RETOC" -a "$AES" to-legacy --version UE5_4 -f "$k" "$STAGE" "$LEGA" >/dev/null 2>&1; done

echo "[3/6] to-legacy the 6 boss BPs + BPC from CURRENT BASE (to patch scalars)"
rm -rf "$LEGB"; mkdir -p "$LEGB"
for k in $BASEPATCH; do "$RETOC" -a "$AES" to-legacy --version UE5_4 -f "$k" "$GAME_PAKS" "$LEGB" >/dev/null 2>&1; done

echo "[4/6] assemble build tree: repath the mod-won Stalker AIDEFs -> real /Game paths; copy 6 boss BPs + BPC from base"
rm -rf "$BUILD"; mkdir -p "$CONTENT/FW/AI/Characters"
declare -A REL=(
 [AIDEF_Euruska_Stalker]=Euruska/Stalker [AIDEF_Euruska_Stalker_HK]=Euruska/Stalker
 [AIDEF_Euruska_Stalker_Pregnant_Quest]=Euruska/Stalker [AIDEF_Euruska_Stalker_Underground]=Euruska/Stalker )
for name in "${!REL[@]}"; do
  d="$CONTENT/FW/AI/Characters/${REL[$name]}"; mkdir -p "$d"
  for ext in uasset uexp; do cp "$LEGA/$name.$ext" "$d/$name.$ext"; done
done
for rel in \
  Euruska/MeatMan/BP_AI_Euruska_MeatMan Euruska/OrgaMech/BP_AI_Euruska_OrgaMech \
  Euruska/ShieldOfficer/BP_AI_Euruska_ShieldOfficer Euruska/Toothy/BP_Mech_Toothy \
  Eurasia/MotherCourage/BP_AI_Eurasia_MotherCourage Eurasia/Opal/BP_AI_Eurasia_Opal \
  Shared/BPC_IncomingDamageMod; do
  d="$CONTENT/FW/AI/Characters/$(dirname "$rel")"; mkdir -p "$d"
  for ext in uasset uexp; do cp "$LEGB/ForeverWinter/Content/FW/AI/Characters/$rel.$ext" "$d/"; done
done
cp "$LEGA/scriptobjects.bin" "$BUILD/scriptobjects.bin"

echo "[5/6] patch the 6 boss BPs + BPC from base (self-verifying: aborts if base scalars/order don't match)"
"$PY" "$REPO/tools/patch_drifted.py" "$CONTENT/FW/AI/Characters"

echo "[6/6] to-zen -> new 153 pak + verify"
rm -rf "$OUT"; mkdir -p "$OUT"
"$RETOC" to-zen --version UE5_4 "$BUILD" "$OUT/153_UnkillablesRebalance_P.utoc" >/dev/null 2>&1
"$RETOC" verify "$OUT/153_UnkillablesRebalance_P.utoc"
cp "$REPO/dist/readme.txt" "$OUT/readme.txt" 2>/dev/null || true
echo "DONE -> $OUT"
