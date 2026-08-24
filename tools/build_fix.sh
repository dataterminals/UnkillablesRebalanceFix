#!/usr/bin/env bash
# Rebuild the fixed 153_UnkillablesRebalance_P pak.
#
# STRATEGY: every one of the 11 packages is now built the SAME way -- extract the CURRENT BASE
# cook from the live game and byte-patch ONLY the rebalanced scalars back in ("Option B"). The
# pak therefore ships the current structure with nothing frozen in it:
#   - 6 boss BPs + BPC_IncomingDamageMod -> tools/patch_drifted.py
#   - 4 Stalker (Grabber) AIDEF DataAssets -> tools/patch_stalker_aidef.py
#
# HOW WE GOT HERE -- two rounds of the same mistake.
#   2026-07-10: the 4 "low-risk" boss BPs were rebased from the mod's own 0.9.2.2 cook
#     ("Option A") on structurally-identical / matching-export-count reasoning. A community
#     member crashed on the current build (ObjectSerializationError / Bad export index on
#     BP_AI_Euruska_MeatMan). All 6 boss BPs + BPC moved to Option B.
#   2026-08-05: the 4 Stalker AIDEFs were the last Option-A holdouts, justified by "DataAssets
#     carry no Kismet bytecode, so there is no serialization-crash surface." Players then
#     reported the game CRASHING WHEN SHOOTING THE GRABBER, and since these were both the only
#     Grabber-specific assets here and the only ones still frozen at 0.9.2.2, they were moved to
#     Option B. The "no bytecode" premise IS unsound in general -- UE5 uses UNVERSIONED property
#     serialization, so a property is identified by its INDEX in the class schema and a drifted
#     class makes a frozen cook decode into the WRONG fields, crashing when one is USED rather
#     than at load.
#   2026-08-23: the first rebuild on a machine with the game MEASURED that and the precondition
#     is FALSE -- all 4 AIDEFs build byte-identical to the frozen cook, so this class never
#     drifted and the move fixed nothing. It is kept anyway (nothing frozen should remain, and
#     it drops the upstream/ requirement), but as hygiene, not as a fix. The Grabber crash has
#     no established cause. See tools/patch_stalker_aidef.py and WORKLOG.md Session 6.
#   The rule all three rounds taught: do not ship a frozen cook because it LOOKS safe -- and do
#   not adopt a mechanism because it explains the symptom. Both need measurement. There is no
#   Option A left in this build, and adding one back needs evidence, not reasoning.
#
# WHY YOU RE-RUN THIS: everything here is extracted from the live game, so the pak is only ever
# as current as the day it was built. On 2026-08-01 the shipped pak was found to REVERT the
# 24501089 hotfix -- its frozen BPC_IncomingDamageMod predated the patch and dropped 13 property
# shapes (the functions "Noisy Player" / "Modify Attack Add" / "Big boi Sniper Rifles", the
# property "Attack Add"). Step [2/6] re-extracts from the current $GAME_PAKS, which picks that
# up. Re-run after every game patch, then run tools/verify_build.sh.
#
# Requires: retoc v0.1.5, the game installed, python3.
set -euo pipefail

# ---------------------------------------------------------------------------
# Per-machine path resolution — same contract as tools/verify_build.sh.
#   1. an environment override always wins (REPO / GAME_PAKS / RETOC / WORK / PY)
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

LEGB="$REPO/work/legacy-base"
BUILD="$REPO/work/build-legacy"; CONTENT="$BUILD/ForeverWinter/Content"
PREV="$REPO/work/prev-dist"
OUT="$REPO/dist/UnkillablesRebalanceFix"

# The isolated read-back in [5b] hardlinks the game's global.* container next to the pak;
# hardlinks cannot cross volumes, so work/ must sit on the same drive as the game. (This used
# to hardlink the WHOLE game -- ~119 files, about 48 GB -- to stage an Option-A collision.
# With no Option A left there is nothing to contest, so only global.* is linked now.)
drive_of() { printf '%s' "$1" | sed -n 's,^\([A-Za-z]\):.*,\1,p' | tr 'a-z' 'A-Z'; }
DW="$(drive_of "$REPO")"; DG="$(drive_of "$GAME_PAKS")"
if [ -n "$DW" ] && [ -n "$DG" ] && [ "$DW" != "$DG" ]; then
  echo "MISSING: the repo work dir and the game are on different volumes."
  echo "    repo: $REPO"
  echo "    game: $GAME_PAKS"
  echo "Hardlinking the game's global container into the read-back mount is what makes imports"
  echo "resolve, and hardlinks cannot cross volumes. Check out the repo on ${DG}: ."
  exit 2
fi

STALKERS="AIDEF_Euruska_Stalker AIDEF_Euruska_Stalker_HK AIDEF_Euruska_Stalker_Pregnant_Quest AIDEF_Euruska_Stalker_Underground"
# Everything is extracted from the current base. -f is a prefix match, so the bare Stalker key
# pulls all 4 AIDEF variants.
EXTRACT="AIDEF_Euruska_Stalker BP_AI_Euruska_MeatMan BP_AI_Euruska_OrgaMech BP_AI_Euruska_ShieldOfficer BP_Mech_Toothy BP_AI_Eurasia_MotherCourage BP_AI_Eurasia_Opal BPC_IncomingDamageMod"

echo "repo     : $REPO"
echo "game     : $GAME_PAKS"
echo "retoc    : $RETOC  ($("$RETOC" --version 2>&1 | head -1))"
echo "python   : $PY"
echo

# iso_extract <dir-with-the-pak-trio> <outdir>
# Mount a pak ALONE alongside the game's global.* and extract it. With no base copy present
# there is no colliding output path, so the bytes are certainly that pak's. Measured
# 2026-08-01: .uexp payloads are byte-identical between an isolated and a staged extract, while
# .uasset headers are NOT (isolation cannot resolve base imports into real names). So compare
# PAYLOADS across mounts, and headers only within the same mount kind.
iso_extract() {
  local src="$1" out="$2" iso="$2.mount" e f
  rm -rf "$iso" "$out"; mkdir -p "$iso" "$out"
  for e in pak ucas utoc; do cp "$src/$PAKNAME.$e" "$iso/"; done
  for f in "$GAME_PAKS"/global.*; do [ -f "$f" ] && ln "$f" "$iso/$(basename "$f")"; done
  "$RETOC" -a "$AES" to-legacy --version UE5_4 "$iso" "$out" >/dev/null 2>&1
  rm -rf "$iso"
}

ISOPREV="$REPO/work/iso-prev"; ISONEW="$REPO/work/iso-new"

echo "[1/6] snapshot the previously shipped pak (regression reference)"
# Snapshot BEFORE step [5] overwrites dist/. This is a regression reference only -- a fresh
# checkout with no dist/ can still build, the prev-comparison legs just report SKIP.
rm -rf "$PREV"; mkdir -p "$PREV"
HAVE_PREV=0
if [ -e "$OUT/$PAKNAME.utoc" ]; then
  for e in pak ucas utoc; do cp "$OUT/$PAKNAME.$e" "$PREV/$PAKNAME.$e"; done
  iso_extract "$PREV" "$ISOPREV"
  HAVE_PREV=1
  echo "      previously shipped pak captured from dist/"
else
  rm -rf "$ISOPREV"; mkdir -p "$ISOPREV"
  echo "      NOTE no previous dist/ pak on this checkout -- regression legs will SKIP"
fi

echo "[2/6] to-legacy all 11 packages from the CURRENT BASE game"
# This is the step that picks up a game patch. It reads $GAME_PAKS directly -- no mod in the
# mount, so no collision and nothing to gate.
rm -rf "$LEGB"; mkdir -p "$LEGB"
for k in $EXTRACT; do "$RETOC" -a "$AES" to-legacy --version UE5_4 -f "$k" "$GAME_PAKS" "$LEGB" >/dev/null 2>&1; done

echo "[2b/6] DRIFT DIAGNOSTIC — current base AIDEF vs the frozen 0.9.2.2 cook we were shipping"
# Evidence, not a gate: this is what the Grabber-crash diagnosis rests on, in the same shape
# that proved the MeatMan case (base uexp 5931 B vs shipped 5904 B, base having gained a
# "Sync Kill in Log" element). Record the output in WORKLOG.md. It does NOT gate the build --
# the move to Option B is correct regardless of what this prints, because shipping the current
# base cook is strictly safer than shipping a frozen one. This only shows HOW the crash happened.
if [ "$HAVE_PREV" -eq 1 ]; then
  "$PY" - "$LEGB" "$ISOPREV" $STALKERS <<'PY' || true
import os, re, sys
legb, isoprev, names = sys.argv[1], sys.argv[2], sys.argv[3:]

def find(root, fname):
    for d, _, fs in os.walk(root):
        if fname in fs:
            return os.path.join(d, fname)
    return None

STR = re.compile(rb'[ -~]{6,}')
for n in names:
    base = find(legb, n + ".uexp")
    ship = find(isoprev, n + ".uexp")
    if base is None or ship is None:
        print("  %-40s SKIP (base=%s shipped=%s)" % (n, bool(base), bool(ship)))
        continue
    bb, sb = open(base, 'rb').read(), open(ship, 'rb').read()
    print("  %s" % n)
    print("     uexp  base %6d B   shipped(frozen) %6d B   delta %+d"
          % (len(bb), len(sb), len(bb) - len(sb)))
    if bb == sb:
        print("     payloads are BYTE-IDENTICAL — no measurable drift in the uexp")
        continue
    bs = set(STR.findall(bb)); ss = set(STR.findall(sb))
    only_base = sorted(x.decode('ascii', 'replace') for x in (bs - ss))
    only_ship = sorted(x.decode('ascii', 'replace') for x in (ss - bs))
    print("     payloads DIFFER")
    if only_base:
        print("     strings the LIVE BASE has that the frozen cook does not (%d):" % len(only_base))
        for s in only_base[:12]:
            print("        + " + s)
        if len(only_base) > 12:
            print("        ... and %d more" % (len(only_base) - 12))
    if only_ship:
        print("     strings ONLY in the frozen cook (%d):" % len(only_ship))
        for s in only_ship[:12]:
            print("        - " + s)
        if len(only_ship) > 12:
            print("        ... and %d more" % (len(only_ship) - 12))
    if not only_base and not only_ship:
        print("     (same string set — the difference is in values/layout, not names)")
PY
else
  echo "      SKIP — no previously shipped pak to compare against"
fi

echo "[3/6] assemble build tree from the base extract"
rm -rf "$BUILD"; mkdir -p "$CONTENT/FW/AI/Characters"
# All 4 AIDEFs live in one folder. Locate by name and write to the canonical destination: the
# destination path is what retoc hashes into the FPackageId, and step [6] asserts those ids, so
# a wrong path here cannot ship silently.
SDEST="$CONTENT/FW/AI/Characters/Euruska/Stalker"; mkdir -p "$SDEST"
for name in $STALKERS; do
  for ext in uasset uexp; do
    src="$(find "$LEGB" -type f -name "$name.$ext" -print -quit)"
    [ -n "$src" ] || { echo "ABORT: $name.$ext not found under $LEGB"; exit 1; }
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
SO="$(find "$LEGB" -type f -name scriptobjects.bin -print -quit)"
[ -n "$SO" ] || { echo "ABORT: scriptobjects.bin not found under $LEGB"; exit 1; }
cp "$SO" "$BUILD/scriptobjects.bin"

echo "[4/6] patch the rebalanced scalars (both patchers are self-verifying and abort on surprise)"
"$PY" "$REPO/tools/patch_drifted.py"       "$CONTENT/FW/AI/Characters"
"$PY" "$REPO/tools/patch_stalker_aidef.py" "$CONTENT/FW/AI/Characters"

echo "[5/6] to-zen -> new 153 pak + container verify"
rm -rf "$OUT"; mkdir -p "$OUT"
"$RETOC" to-zen --version UE5_4 "$BUILD" "$OUT/$PAKNAME.utoc" >/dev/null 2>&1
"$RETOC" verify "$OUT/$PAKNAME.utoc"
cp "$REPO/dist/readme.txt" "$OUT/readme.txt" 2>/dev/null || true

echo "[5b/6] READ BACK the built pak from an ISOLATED mount (deterministic; no collision)"
iso_extract "$OUT" "$ISONEW"

echo "[5c/6] CONTENT GATE — every package is current base + only the rebalanced scalars"
# `retoc verify` checks the CONTAINER and nothing about the contents -- that is the exact check
# that passed a pak whose every weapon pointed at a deleted DataAsset. These assertions are
# about content:
#   A. each of the 4 Stalker AIDEFs must be the CURRENT BASE cook with only the 2 patched
#      float32s moved. That is the entire safety property, and it is asserted against $LEGB --
#      the pristine live-game extract -- so a build that somehow shipped a frozen cook instead
#      would show stray bytes and fail right here.
#      This gate ALSO used to demand the payload DIFFER from the previously shipped pak, on the
#      reasoning that under Option B an unchanged payload meant the Option-A -> Option-B move
#      had not taken effect. That was an assumption about drift, not a safety property, and on
#      2026-08-23 it was measured FALSE: on 24536482 all 4 AIDEFs build byte-identical to the
#      frozen 0.9.2.2 copy, because this class never drifted. A correct build IS identical
#      there, so the clause rejected every good build. It is now a drift REPORT, not a gate.
#      (Same defect as the "exactly 8 bytes differ" formulation it already replaced once: both
#      encoded a guess about what the bytes would look like instead of asserting the contract.)
#   B. the BPC must carry the function/property names the live base has. This is the 24501089
#      regression stated in bytes rather than in decoded property shapes, so it holds even when
#      the decoder or the usmap is unavailable.
"$PY" - "$ISONEW" "$ISOPREV" "$LEGB" "$HAVE_PREV" <<'PY'
import os, struct, sys
isonew, isoprev, legb, have_prev = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4] == "1"
bad = 0

def f32(v):
    return struct.pack('<f', v)

# Keep in step with tools/patch_stalker_aidef.py SCALARS.
AIDEF_SCALARS = [("DamageToStagger", 20000.0), ("SyncKillMaxPlayerHealth", 2000.0)]
AIDEF_MOD = f32(1000.0)

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

print("  A. Stalker AIDEFs are current base + exactly the 2 patched scalars")
for n in ("AIDEF_Euruska_Stalker", "AIDEF_Euruska_Stalker_HK",
          "AIDEF_Euruska_Stalker_Pregnant_Quest", "AIDEF_Euruska_Stalker_Underground"):
    new = find(isonew, n + ".uexp")
    base = find(legb, n + ".uexp")
    if new is None or base is None:
        print("     FAIL %-38s missing extract (new=%s base=%s)"
              % (n, bool(new), bool(base))); bad = 1
        continue
    nb = open(new, 'rb').read()
    # Compare against the UNPATCHED base extract. [3] copied it into the build tree and [4]
    # patched the copy, so $LEGB still holds the pristine base bytes.
    bb = open(base, 'rb').read()
    if len(nb) != len(bb):
        print("     FAIL %-38s length %d != base %d -- not an in-place scalar patch"
              % (n, len(nb), len(bb))); bad = 1
        continue
    # Assert SEMANTICALLY, not by counting changed bytes. Two float32s occupy 8 bytes, but how
    # many of those bytes actually change depends on the values: 20000->1000 moves 3 bytes and
    # 2000->1000 moves 1, so a "exactly 8 bytes differ" check is simply wrong and would reject a
    # correct build. Instead: locate each base scalar, require the built pak to hold the mod
    # value there, and require every remaining byte to be untouched.
    allowed, ok = set(), True
    for prop, basev in AIDEF_SCALARS:
        hits, start = [], 0
        while True:
            i = bb.find(f32(basev), start)
            if i < 0:
                break
            hits.append(i); start = i + 1
        if len(hits) != 1:
            print("     FAIL %-38s base has %d x %s (%.0f), expected 1"
                  % (n, len(hits), prop, basev)); ok = False; continue
        off = hits[0]
        allowed.update(range(off, off + 4))
        if nb[off:off + 4] != AIDEF_MOD:
            got = struct.unpack('<f', nb[off:off + 4])[0]
            print("     FAIL %-38s %s reads %.0f in the built pak, expected 1000"
                  % (n, prop, got)); ok = False
    stray = [i for i in range(len(bb)) if bb[i] != nb[i] and i not in allowed]
    if stray:
        print("     FAIL %-38s %d byte(s) differ from base OUTSIDE the 2 patched scalars"
              % (n, len(stray)))
        print("          first stray offset 0x%x -- the payload was re-encoded or over-patched"
              % stray[0])
        ok = False
    if ok:
        print("     OK   %-38s current base cook, only the 2 scalars moved" % n)
    else:
        print("          base extract: %s" % base)
        print("          built pak   : %s" % new)
        bad = 1
    # Drift REPORT -- deliberately not a gate. See the note on A above: whether this payload
    # matches the previous ship is a fact about the GAME (did the class layout move?), not
    # about whether this build is correct. Correctness is the assertion above.
    if not have_prev:
        print("          SKIP drift report (no dist/ pak at build start)")
        continue
    old = find(isoprev, n + ".uexp")
    if old is None:
        print("          NOTE not present in the previous pak -- nothing to compare")
    elif open(old, 'rb').read() == nb:
        print("          NOTE identical to the previously shipped copy -- this class did NOT")
        print("               drift: the frozen cook and the current base cook agree byte for byte")
    else:
        print("          NOTE differs from the previously shipped copy -- this class DID drift,")
        print("               so rebuilding changed what ships")

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

# Report, not a gate, for the same reason as A: if a game patch simply did not touch the BPC,
# a byte-identical rebuild is the CORRECT result. What must hold is B above -- that the shipped
# BPC carries the live base's names -- and that is asserted, not inferred from a difference.
if have_prev:
    prevb = find(isoprev, "BPC_IncomingDamageMod.uasset")
    if prevb:
        same = open(prevb, 'rb').read() == nb
        print("     NOTE BPC %s the previous pak" %
              ("is byte-identical to (the live base's copy did not move since)" if same
               else "differs from (the live base's copy moved since)"))
sys.exit(1 if bad else 0)
PY

echo "[6/6] FPackageId parity — the override binding contract"
# A pak override binds by FPackageId, derived from the package path. If an id moves, that
# package stops overriding anything and the mod half-applies with NO error at runtime.
# Moving the AIDEFs from Option A to Option B does NOT move their ids: retoc derives the id
# from the destination package PATH, and [3] writes them to the same path as before. So this
# check is unchanged and must still report 11/11.
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
