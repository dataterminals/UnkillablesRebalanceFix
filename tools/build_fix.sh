#!/usr/bin/env bash
# Rebuild the fixed 153_UnkillablesRebalance_P pak (HYBRID strategy):
#   - 8 structurally-identical overrides  -> rebase the MOD's version onto the current build
#     (MeatMan, OrgaMech, ShieldOfficer, Toothy + 4 Stalker AIDEFs). Current base == what the
#     mod overrides, so the mod-cooked class is safe; only the rebalanced scalar differs.
#   - 3 structurally-DRIFTED overrides   -> patch the CURRENT BASE version's scalars in place
#     (MotherCourage, Opal, BPC_IncomingDamageMod). Base gained exports since 0.9.2.2, so we ship
#     current structure + only the rebalanced values (tools/patch_drifted.py) instead of the mod's
#     stale bytecode. Avoids the HeavyRifle-style ObjectSerializationError / reverted-content risk.
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

LOWRISK="BP_AI_Euruska_MeatMan BP_AI_Euruska_OrgaMech BP_AI_Euruska_ShieldOfficer BP_Mech_Toothy AIDEF_Euruska_Stalker"
DRIFTED="BP_AI_Eurasia_MotherCourage BP_AI_Eurasia_Opal BPC_IncomingDamageMod"

echo "[1/6] stage current game (hardlinks) + original mod renamed zzz_ (wins the FPackageId collision)"
rm -rf "$STAGE"; mkdir -p "$STAGE"
for f in "$GAME_PAKS"/*; do [ -f "$f" ] && ln "$f" "$STAGE/$(basename "$f")"; done
for e in pak ucas utoc; do cp "$UP/153_UnkillablesRebalance_P.$e" "$STAGE/zzz_UnkillablesRebalance_P.$e"; done

echo "[2/6] to-legacy the 8 low-risk MOD-won assets (mod wins; imports resolve vs current base)"
rm -rf "$LEGA"; mkdir -p "$LEGA"
for k in $LOWRISK; do "$RETOC" -a "$AES" to-legacy --version UE5_4 -f "$k" "$STAGE" "$LEGA" >/dev/null 2>&1; done

echo "[3/6] to-legacy the 3 drifted assets from CURRENT BASE (to patch)"
rm -rf "$LEGB"; mkdir -p "$LEGB"
for k in $DRIFTED; do "$RETOC" -a "$AES" to-legacy --version UE5_4 -f "$k" "$GAME_PAKS" "$LEGB" >/dev/null 2>&1; done

echo "[4/6] assemble build tree: repath the 8 mod-won bare extracts -> real /Game paths; copy the 3 drifted"
rm -rf "$BUILD"; mkdir -p "$CONTENT/FW/AI/Characters"
declare -A REL=(
 [BP_AI_Euruska_MeatMan]=Euruska/MeatMan [BP_AI_Euruska_OrgaMech]=Euruska/OrgaMech
 [BP_AI_Euruska_ShieldOfficer]=Euruska/ShieldOfficer [BP_Mech_Toothy]=Euruska/Toothy
 [AIDEF_Euruska_Stalker]=Euruska/Stalker [AIDEF_Euruska_Stalker_HK]=Euruska/Stalker
 [AIDEF_Euruska_Stalker_Pregnant_Quest]=Euruska/Stalker [AIDEF_Euruska_Stalker_Underground]=Euruska/Stalker )
for name in "${!REL[@]}"; do
  d="$CONTENT/FW/AI/Characters/${REL[$name]}"; mkdir -p "$d"
  for ext in uasset uexp; do cp "$LEGA/$name.$ext" "$d/$name.$ext"; done
done
for rel in Eurasia/MotherCourage/BP_AI_Eurasia_MotherCourage Eurasia/Opal/BP_AI_Eurasia_Opal Shared/BPC_IncomingDamageMod; do
  d="$CONTENT/FW/AI/Characters/$(dirname "$rel")"; mkdir -p "$d"
  for ext in uasset uexp; do cp "$LEGB/ForeverWinter/Content/FW/AI/Characters/$rel.$ext" "$d/"; done
done
cp "$LEGA/scriptobjects.bin" "$BUILD/scriptobjects.bin"

echo "[5/6] patch the 3 drifted assets (self-verifying: aborts if base scalars/order don't match)"
"$PY" "$REPO/tools/patch_drifted.py" "$CONTENT/FW/AI/Characters"

echo "[6/6] to-zen -> new 153 pak + verify"
rm -rf "$OUT"; mkdir -p "$OUT"
"$RETOC" to-zen --version UE5_4 "$BUILD" "$OUT/153_UnkillablesRebalance_P.utoc" >/dev/null 2>&1
"$RETOC" verify "$OUT/153_UnkillablesRebalance_P.utoc"
cp "$REPO/dist/readme.txt" "$OUT/readme.txt" 2>/dev/null || true
echo "DONE -> $OUT"
