#!/usr/bin/env bash
# Rebuild the fixed 153_UnkillablesRebalance_P pak (HYBRID strategy):
#   - 4 Stalker AIDEF DataAssets  -> rebase the MOD's version onto the current build. DataAssets
#     carry no Kismet bytecode, so there is no serialization-crash surface; only 2 scalars differ.
#   - ALL 6 boss BPs + BPC        -> patch the CURRENT BASE version's scalars in place (Option B,
#     tools/patch_drifted.py): MeatMan, OrgaMech, ShieldOfficer, Toothy, MotherCourage, Opal +
#     BPC_IncomingDamageMod. Ships current structure with ONLY the rebalanced values.
#   NOTE (2026-07-10): the 4 boss BPs (MeatMan/OrgaMech/ShieldOfficer/Toothy) were MOVED from the
#   Option-A rebase group to Option-B after the mod's stale 0.9.2.2 MeatMan cook crashed in-game on
#   0.9.3.9.2 (community-confirmed ObjectSerializationError / Bad export index) — the same HeavyRifle
#   HRF05 failure class. Matching export counts did NOT make the stale cook safe to ship.
#
# WHY YOU RE-RUN THIS: the Option-B group is extracted from the live game, so it is only ever as
# current as the day it was built. On 2026-08-01 the shipped pak was found to REVERT the 24501089
# hotfix — its frozen BPC_IncomingDamageMod predated the patch and dropped 13 property shapes
# (the functions "Noisy Player" / "Modify Attack Add" / "Big boi Sniper Rifles", the property
# "Attack Add"). Step [3/7] re-extracts from the current $GAME_PAKS, which picks that up. Re-run
# after every game patch, then run tools/verify_build.sh.
#
# Requires: retoc v0.1.5, the game installed, python3.
set -euo pipefail

# ---------------------------------------------------------------------------
# Per-machine path resolution — same contract as tools/verify_build.sh.
#   1. an environment override always wins (REPO / GAME_PAKS / RETOC / MODSRC / WORK / PY)
#   2. otherwise take the first candidate that exists
# SylG5 (laptop) keeps the repos and the Steam library on D:. SylDesk keeps them on H:.
# This script used to hardcode H:, which meant it simply could not run on SylG5. Find-and-
# replacing one drive letter for the other fixes one machine and breaks the other, so both are
# listed and probed. Add a machine by adding a line to each list.
# ---------------------------------------------------------------------------
first_existing() {
  local c
  for c in "$@"; do
    if [ -e "$c" ]; then printf '%s\n' "$c"; return 0; fi
  done
  return 1
}

cands_repo() {
  # This script lives in <repo>/tools, so its own location is the most reliable answer and
  # survives a checkout that is not on either known drive.
  ( cd "$(dirname "$0")/.." 2>/dev/null && pwd ) || true
  echo "D:/Github Repositories/UnkillablesRebalanceFix"
  echo "H:/Github Repositories/UnkillablesRebalanceFix"
}
cands_paks() {
  echo "D:/SteamLibrary/steamapps/common/The Forever Winter/Windows/ForeverWinter/Content/Paks"
  echo "H:/SteamLibrary/steamapps/common/The Forever Winter/Windows/ForeverWinter/Content/Paks"
}
cands_retoc() {
  # tools/retoc/ is gitignored (third-party binary), so a fresh checkout has no copy. The
  # sibling repos that vendored the same v0.1.5 are listed so a clone can build unattended.
  echo "$REPO/tools/retoc/retoc.exe"
  echo "D:/Github Repositories/HeavyRifleRebalanceFix/tools/retoc/retoc.exe"
  echo "H:/Github Repositories/HeavyRifleRebalanceFix/tools/retoc/retoc.exe"
}

resolve() {
  # resolve <VARNAME> <candidate-generator>
  local var="$1" gen="$2" cur val
  eval "cur=\${$var:-}"
  if [ -n "$cur" ]; then
    if [ -e "$cur" ]; then return 0; fi
    echo "MISSING: $var is set to a path that does not exist:"
    echo "    $cur"
    return 1
  fi
  local IFS=$'\n'
  val="$(first_existing $($gen))" || {
    echo "MISSING: could not resolve $var. Looked for, in order:"
    $gen | sed 's/^/    /'
    return 1
  }
  eval "$var=\$val"
  return 0
}

BAD=0
resolve REPO      cands_repo  || BAD=1
resolve GAME_PAKS cands_paks  || BAD=1
resolve RETOC     cands_retoc || BAD=1
if [ "$BAD" -ne 0 ]; then
  echo
  echo "Set the ones above explicitly, e.g.:"
  echo "  REPO=/d/repos/UnkillablesRebalanceFix GAME_PAKS=... RETOC=... bash tools/build_fix.sh"
  exit 2
fi

PY="${PY:-}"
if [ -z "$PY" ]; then
  if command -v python  >/dev/null 2>&1; then PY=python
  elif command -v python3 >/dev/null 2>&1; then PY=python3
  else echo "MISSING: no python on PATH. Set PY=/path/to/python."; exit 2; fi
fi

AES="0x84B2244BE0AF90C22976D739FA0665569219F4CEA119CEA37C81F2D9ABEE4795"
PAKNAME="153_UnkillablesRebalance_P"

# ---------------------------------------------------------------------------
# Option-A source: where the MOD's Stalker AIDEF payload comes from.
#
# Preferred is upstream/ — the pristine Nexus #68 0.9.2.2 pak. Its cooked binaries are
# gitignored (third-party IP, deliberately not redistributed), so a checkout on a machine that
# never held the Nexus archive does NOT have it; SylG5 is exactly that case.
#
# The fallback is the previously shipped dist/ pak, and it is a faithful substitute for THIS
# group specifically: dist's 4 AIDEFs are upstream's own payload, already rebased once. What
# comes back out of to-legacy is the mod's DataAsset content either way. It is only sound
# because step [2b] then PROVES the recovered payload is the mod's, and step [6b] proves the
# rebuilt AIDEFs are byte-identical to the ones already shipping. Neither leg is optional.
# ---------------------------------------------------------------------------
if [ -n "${MODSRC:-}" ]; then
  [ -e "$MODSRC/$PAKNAME.utoc" ] || { echo "MISSING: \$MODSRC has no $PAKNAME.utoc: $MODSRC"; exit 2; }
  MODSRC_KIND="explicit (\$MODSRC)"
elif [ -e "$REPO/upstream/UnkillablesRebalance_0.9.2.2/$PAKNAME.utoc" ]; then
  MODSRC="$REPO/upstream/UnkillablesRebalance_0.9.2.2"
  MODSRC_KIND="pristine upstream 0.9.2.2 (preferred)"
elif [ -e "$REPO/dist/UnkillablesRebalanceFix/$PAKNAME.utoc" ]; then
  MODSRC="$REPO/dist/UnkillablesRebalanceFix"
  MODSRC_KIND="previous dist build (upstream/ absent on this machine)"
else
  echo "MISSING: no Option-A source. Need one of:"
  echo "    $REPO/upstream/UnkillablesRebalance_0.9.2.2/$PAKNAME.utoc"
  echo "    $REPO/dist/UnkillablesRebalanceFix/$PAKNAME.utoc"
  exit 2
fi

STAGE="$REPO/work/staging-full"; LEGA="$REPO/work/legacy-A"; LEGB="$REPO/work/legacy-B"
BUILD="$REPO/work/build-legacy"; CONTENT="$BUILD/ForeverWinter/Content"
PREV="$REPO/work/prev-dist"; BASEREF="$REPO/work/base-ref"
OUT="$REPO/dist/UnkillablesRebalanceFix"

# The staging dir hardlinks ~119 pak files (about 48 GB); hardlinks cannot cross volumes, so
# work/ must sit on the same drive as the game. Copying instead is not an option at that size.
drive_of() { printf '%s' "$1" | sed -n 's,^\([A-Za-z]\):.*,\1,p' | tr 'a-z' 'A-Z'; }
DW="$(drive_of "$REPO")"; DG="$(drive_of "$GAME_PAKS")"
if [ -n "$DW" ] && [ -n "$DG" ] && [ "$DW" != "$DG" ]; then
  echo "MISSING: the repo work dir and the game are on different volumes."
  echo "    repo: $REPO"
  echo "    game: $GAME_PAKS"
  echo "Hardlinking the game into the staging dir is what makes imports resolve, and hardlinks"
  echo "cannot cross volumes. Check out the repo on ${DG}: ."
  exit 2
fi

STALKERS="AIDEF_Euruska_Stalker AIDEF_Euruska_Stalker_HK AIDEF_Euruska_Stalker_Pregnant_Quest AIDEF_Euruska_Stalker_Underground"
# Option A (rebase mod's version): only the Stalker AIDEF DataAssets (-f prefix matches all 4).
LOWRISK="AIDEF_Euruska_Stalker"
# Option B (patch current base): all 6 boss BPs + the shared BPC component.
BASEPATCH="BP_AI_Euruska_MeatMan BP_AI_Euruska_OrgaMech BP_AI_Euruska_ShieldOfficer BP_Mech_Toothy BP_AI_Eurasia_MotherCourage BP_AI_Eurasia_Opal BPC_IncomingDamageMod"

echo "repo     : $REPO"
echo "game     : $GAME_PAKS"
echo "retoc    : $RETOC  ($("$RETOC" --version 2>&1 | head -1))"
echo "mod src  : $MODSRC"
echo "           ^ $MODSRC_KIND"
echo "python   : $PY"
echo

echo "[1/7] stage current game (hardlinks) + the mod renamed zzz_ (contests the FPackageId collision)"
rm -rf "$STAGE" "$PREV"; mkdir -p "$STAGE" "$PREV"
for f in "$GAME_PAKS"/*; do [ -f "$f" ] && ln "$f" "$STAGE/$(basename "$f")"; done
# Snapshot the Option-A source before anything can overwrite dist/ in step [6].
for e in pak ucas utoc; do cp "$MODSRC/$PAKNAME.$e" "$PREV/$PAKNAME.$e"; done
for e in pak ucas utoc; do cp "$PREV/$PAKNAME.$e" "$STAGE/zzz_$PAKNAME.$e"; done

echo "[2/7] to-legacy the Stalker AIDEFs from the staged mount (imports resolve vs current base)"
rm -rf "$LEGA"; mkdir -p "$LEGA"
for k in $LOWRISK; do "$RETOC" -a "$AES" to-legacy --version UE5_4 -f "$k" "$STAGE" "$LEGA" >/dev/null 2>&1; done

echo "      also extracting the BASE copies, to prove which one we actually got"
rm -rf "$BASEREF"; mkdir -p "$BASEREF"
for k in $LOWRISK; do "$RETOC" -a "$AES" to-legacy --version UE5_4 -f "$k" "$GAME_PAKS" "$BASEREF" >/dev/null 2>&1; done

echo "[2b/7] PROVENANCE GATE — the staged extract must be the MOD's copy, not the base game's"
# Measured 2026-08-01: retoc extracts BOTH colliding copies and they land on the same output
# path, so the last write wins and the winner is not guaranteed. tools/verify_build.sh's header
# documents the same hazard for CUE4Parse ("a run can grade the base game's copy and report
# clean"). Renaming the container zzz_ does NOT settle it. So assert rather than assume: the
# mod sets every Stalker AIDEF's two scalars to 1000.0f, and the base build sets neither.
# Without this gate a lost race ships base-HP Stalkers with no error anywhere in the build.
"$PY" - "$LEGA" "$BASEREF" $STALKERS <<'PY'
import os, struct, sys
lega, baseref, names = sys.argv[1], sys.argv[2], sys.argv[3:]
PAT = struct.pack('<f', 1000.0)

def find(root, fname):
    for d, _, fs in os.walk(root):
        if fname in fs:
            return os.path.join(d, fname)
    return None

bad = 0
for n in names:
    got = find(lega, n + ".uexp")
    ref = find(baseref, n + ".uexp")
    if got is None or ref is None:
        print("  FAIL %-40s missing extract (mod=%s base=%s)"
              % (n, bool(got), bool(ref)))
        bad = 1
        continue
    gb, rb = open(got, 'rb').read(), open(ref, 'rb').read()
    nmod, nbase = gb.count(PAT), rb.count(PAT)
    if nmod == 2 and gb != rb:
        print("  OK   %-40s mod payload (1000.0f x2; base has x%d)" % (n, nbase))
        continue
    bad = 1
    if gb == rb:
        print("  FAIL %-40s extract is BYTE-IDENTICAL to base -- retoc lost the collision" % n)
    else:
        print("  FAIL %-40s expected 1000.0f x2, found x%d" % (n, nmod))
print()
if bad:
    print("  The Option-A extract is not provably the mod's. Re-run; if it repeats, the mod")
    print("  source pak is wrong or retoc's collision order changed. Do NOT ship this build.")
    sys.exit(1)
print("  OK   all 4 Stalker AIDEFs carry the mod's payload")
PY

echo "[3/7] to-legacy the 6 boss BPs + BPC from CURRENT BASE (to patch scalars)"
# This is the step that picks up a game patch. It reads $GAME_PAKS directly -- no mod in the
# mount, so no collision and nothing to gate here.
rm -rf "$LEGB"; mkdir -p "$LEGB"
for k in $BASEPATCH; do "$RETOC" -a "$AES" to-legacy --version UE5_4 -f "$k" "$GAME_PAKS" "$LEGB" >/dev/null 2>&1; done

echo "[4/7] assemble build tree: mod-won Stalker AIDEFs + the 6 boss BPs + BPC from base"
rm -rf "$BUILD"; mkdir -p "$CONTENT/FW/AI/Characters"
# All 4 AIDEFs live in one folder. The source layout varies -- the pristine upstream pak stores
# them at BARE paths, a previously-built dist pak at real /Game paths -- so locate by name and
# write to the canonical destination. The destination is what retoc hashes into the FPackageId,
# and step [7] asserts those ids, so a wrong path here cannot ship silently.
SDEST="$CONTENT/FW/AI/Characters/Euruska/Stalker"; mkdir -p "$SDEST"
for name in $STALKERS; do
  for ext in uasset uexp; do
    src="$(find "$LEGA" -type f -name "$name.$ext" -print -quit)"
    [ -n "$src" ] || { echo "ABORT: $name.$ext not found under $LEGA"; exit 1; }
    cp "$src" "$SDEST/$name.$ext"
  done
done
for rel in \
  Euruska/MeatMan/BP_AI_Euruska_MeatMan Euruska/OrgaMech/BP_AI_Euruska_OrgaMech \
  Euruska/ShieldOfficer/BP_AI_Euruska_ShieldOfficer Euruska/Toothy/BP_Mech_Toothy \
  Eurasia/MotherCourage/BP_AI_Eurasia_MotherCourage Eurasia/Opal/BP_AI_Eurasia_Opal \
  Shared/BPC_IncomingDamageMod; do
  d="$CONTENT/FW/AI/Characters/$(dirname "$rel")"; mkdir -p "$d"
  for ext in uasset uexp; do cp "$LEGB/ForeverWinter/Content/FW/AI/Characters/$rel.$ext" "$d/"; done
done
SO="$(find "$LEGA" -type f -name scriptobjects.bin -print -quit)"
[ -n "$SO" ] || { echo "ABORT: scriptobjects.bin not found under $LEGA"; exit 1; }
cp "$SO" "$BUILD/scriptobjects.bin"

echo "[5/7] patch the 6 boss BPs + BPC from base (self-verifying: aborts if base scalars/order don't match)"
"$PY" "$REPO/tools/patch_drifted.py" "$CONTENT/FW/AI/Characters"

echo "[6/7] to-zen -> new 153 pak + container verify"
rm -rf "$OUT"; mkdir -p "$OUT"
"$RETOC" to-zen --version UE5_4 "$BUILD" "$OUT/$PAKNAME.utoc" >/dev/null 2>&1
"$RETOC" verify "$OUT/$PAKNAME.utoc"
cp "$REPO/dist/readme.txt" "$OUT/readme.txt" 2>/dev/null || true

echo "[6b/7] READ BACK the built pak from an ISOLATED mount (deterministic; no collision)"
# Read-back is done by mounting the pak alone alongside global.utoc/global.ucas. With no base
# copy present there is no colliding path, so the bytes are certainly the mod's -- this is the
# mount-provenance discipline the staged extract in [2] needs a gate for. Measured 2026-08-01:
# the .uexp payload is byte-identical between an isolated and a staged extract, while the
# .uasset header is not (isolation cannot resolve base imports into real names). So compare
# PAYLOADS across mounts, and compare headers only within the same mount kind.
iso_extract() {  # iso_extract <dir-with-the-trio> <outdir>
  local src="$1" out="$2" iso="$2.mount" e f
  rm -rf "$iso" "$out"; mkdir -p "$iso" "$out"
  for e in pak ucas utoc; do cp "$src/$PAKNAME.$e" "$iso/"; done
  for f in "$GAME_PAKS"/global.*; do [ -f "$f" ] && ln "$f" "$iso/$(basename "$f")"; done
  "$RETOC" -a "$AES" to-legacy --version UE5_4 "$iso" "$out" >/dev/null 2>&1
  rm -rf "$iso"
}
ISONEW="$REPO/work/iso-new"; ISOPREV="$REPO/work/iso-prev"
iso_extract "$OUT"  "$ISONEW"
iso_extract "$PREV" "$ISOPREV"

echo "[6c/7] CONTENT GATE — Option A unchanged, Option B carries the live build"
# `retoc verify` checks the CONTAINER and nothing about the contents -- that is the exact check
# that passed a pak whose every weapon pointed at a deleted DataAsset. These assertions are
# about content, and they are what makes a rebuild trustworthy:
#   A. the 4 Stalker AIDEF payloads must come out byte-identical to the ones already shipping.
#      A rebuild is only supposed to move the Option-B group, so drift here is a defect -- and
#      this is what makes the dist-as-Option-A-source fallback provably lossless.
#   B. the BPC must carry the function/property names the live base has. This is the 24501089
#      regression stated in bytes rather than in decoded property shapes, so it holds even when
#      the decoder or the usmap is unavailable.
"$PY" - "$ISONEW" "$ISOPREV" "$LEGB" <<'PY'
import os, sys
isonew, isoprev, legb = sys.argv[1], sys.argv[2], sys.argv[3]
bad = 0

def find(root, fname):
    for d, _, fs in os.walk(root):
        if fname in fs:
            return os.path.join(d, fname)
    return None

n_pkg = len([1 for d, _, fs in os.walk(isonew) for f in fs if f.endswith(".uasset")])
if n_pkg == 11:
    print("  OK   the rebuilt pak ships exactly 11 packages")
else:
    print("  FAIL the rebuilt pak ships %d packages, expected 11" % n_pkg); bad = 1

print("  A. Stalker AIDEF payloads vs the previously shipped pak")
for n in ("AIDEF_Euruska_Stalker", "AIDEF_Euruska_Stalker_HK",
          "AIDEF_Euruska_Stalker_Pregnant_Quest", "AIDEF_Euruska_Stalker_Underground"):
    new, old = find(isonew, n + ".uexp"), find(isoprev, n + ".uexp")
    if new is None or old is None:
        print("     FAIL %-38s missing extract (new=%s prev=%s)"
              % (n, bool(new), bool(old))); bad = 1
        continue
    if open(new, 'rb').read() == open(old, 'rb').read():
        print("     OK   %-38s byte-identical to the shipped copy" % n)
    else:
        print("     FAIL %-38s payload CHANGED -- a rebuild must not move Option A" % n)
        bad = 1

print("  B. BPC_IncomingDamageMod carries the live build's names")
newb = find(isonew, "BPC_IncomingDamageMod.uasset")
basb = os.path.join(legb, "ForeverWinter", "Content", "FW", "AI", "Characters",
                    "Shared", "BPC_IncomingDamageMod.uasset")
nb, bb = open(newb, 'rb').read(), open(basb, 'rb').read()
for s in ("Attack Add", "Modify Attack Add", "Big boi Sniper Rifles", "Noisy Player"):
    e = s.encode()
    got, want = nb.count(e), bb.count(e)
    if want == 0:
        print("     WARN %-38s absent from the live base too (re-check the finding)" % s)
    elif got == want:
        print("     OK   %-38s x%d (matches live base)" % (s, got))
    else:
        print("     FAIL %-38s x%d, live base has x%d" % (s, got, want)); bad = 1

prevb = find(isoprev, "BPC_IncomingDamageMod.uasset")
if prevb and open(prevb, 'rb').read() == nb:
    print("     FAIL BPC is byte-identical to the PREVIOUS pak -- the rebuild changed nothing")
    bad = 1
sys.exit(1 if bad else 0)
PY

echo "[7/7] FPackageId parity — the override binding contract"
# A pak override binds by FPackageId, derived from the package path. If an id moves, that
# package stops overriding anything and the mod half-applies with NO error at runtime.
# `retoc manifest` writes pakstore.json into the CURRENT directory, so run it somewhere
# disposable rather than wherever the caller happened to be.
( cd "$REPO/work" && "$RETOC" manifest "$OUT/$PAKNAME.utoc" >/dev/null 2>&1 )
"$PY" - "$REPO/tools/expected_package_ids.txt" "$REPO/work/pakstore.json" <<'PY'
import json, os, sys
expfile, store = sys.argv[1], sys.argv[2]
want = {}
with open(expfile, encoding="utf-8") as fh:
    for line in fh:
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        i, n = line.split(None, 1)
        want[n] = i
doc = json.load(open(store, encoding="utf-8"))
got = {e["packagestoreentry"]["packagename"]: e["packagedata"][0]["id"]
       for e in doc["oplog"]["entries"]}
os.remove(store)
bad = 0
for n in sorted(want):
    if n not in got:
        print("  FAIL %s -- NOT SHIPPED by the rebuilt pak" % n); bad = 1
    elif got[n] != want[n]:
        print("  FAIL %s\n       expected %s got %s" % (n, want[n], got[n])); bad = 1
for n in sorted(set(got) - set(want)):
    print("  FAIL %s -- UNEXPECTED extra package" % n); bad = 1
if bad:
    print("  Package ids are the binding contract; a mismatch means a silent no-op override.")
    sys.exit(1)
print("  OK   %d/%d package ids match the shipped contract" % (len(want), len(want)))
sys.exit(0)
PY

echo
echo "DONE -> $OUT"
echo "Now run:  bash tools/verify_build.sh"
