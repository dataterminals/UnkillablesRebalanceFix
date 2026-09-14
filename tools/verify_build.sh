#!/usr/bin/env bash
# Verify the shipped 153_UnkillablesRebalance_P pak against the LIVE game build.
#
# WHY THIS EXISTS
#   Every build script here stops at `retoc verify`, which validates the CONTAINER and nothing
#   about the contents. That is exactly the check that passed AllWeaponsUnlockableFix's pak on
#   build 24479102 while every weapon in the game pointed at a deleted DataAsset -- a user found
#   that, not the build. See AllWeaponsUnlockableFix/tools/verify_softrefs.py for the full story.
#
# THIS MOD'S EXPOSURE
#   It is a whole-asset override of 11 packages (tools/build_fix.sh). Since 2026-08-05 ALL 11
#   are built the same way -- extracted from the CURRENT BASE cook and byte-patched with only
#   the rebalanced scalars ("Option B"): 6 boss BPs + BPC_IncomingDamageMod via
#   patch_drifted.py, and the 4 Stalker AIDEF DataAssets via patch_stalker_aidef.py. Nothing
#   frozen at 0.9.2.2 ships any more.
#   Two ways a patch breaks that:
#     1. a referenced asset is renamed or deleted -> the override points at nothing
#     2. the devs add a property to an asset      -> our frozen override silently reverts it
#   Check 3 below is (1). Check 4 is (2). (2) used to be the check that mattered most, because
#   the 4 AIDEFs were frozen at 0.9.2.2 and dropped anything the devs added after that. They no
#   longer are, so a drop here now means the extract is STALE -- i.e. the game patched since
#   this pak was built -- rather than that a frozen cook is reverting content.
#
#   READ THIS BEFORE TRUSTING A PASS. Both checks are structural: they prove the pointers
#   resolve and no property was dropped, and nothing automated in this repo proves more. What
#   they no longer have to carry is the frozen-cook risk -- an Option-B asset is the same cook
#   the game itself loads apart from the patched scalars, so there is no stale bytecode and no
#   stale property layout to go wrong. The residual risk is simply age: re-run build_fix.sh
#   after every game patch.
#
#   bash tools/verify_build.sh
#
# Requires: the game installed, the forever-winter-datamine decoder built, python3.
# Exits non-zero if anything dangles, is not covered, or is reverted.
set -uo pipefail

# One fwextract at a time, machine-wide. Two concurrent decoders froze SylDesk on 2026-09-11 --
# tools/fwlock.sh carries the full account and the evidence. The lock is taken for the WHOLE run
# below rather than around each decode() call, because `rm -rf "$WORK"` means two runs sharing a
# WORK dir would destroy each other's dumps even if their decoders never overlapped.
. "$(dirname "$0")/fwlock.sh"

# ---------------------------------------------------------------------------
# Per-machine path resolution.
#   1. an environment override always wins (REPO / GAME_PAKS / DECODER / USMAP / WORK / PY)
#   2. otherwise take the first candidate that exists
# SylG5 (laptop) keeps the repos and the Steam library on D:. SylDesk keeps them on H:.
# Find-and-replacing one drive letter for the other fixes one machine and breaks the other,
# so both are listed and probed. Add a machine by adding a line to each list.
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
cands_decoder() {
  echo "D:/Github Repositories/forever-winter-datamine/datamine/decoder/bin/Release/net10.0/fwextract.exe"
  echo "H:/Github Repositories/forever-winter-datamine/datamine/decoder/bin/Release/net10.0/fwextract.exe"
}
cands_usmap() {
  echo "D:/Github Repositories/forever-winter-datamine/datamine/mappings/ForeverWinter-5.4.2.usmap"
  echo "H:/Github Repositories/forever-winter-datamine/datamine/mappings/ForeverWinter-5.4.2.usmap"
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
resolve REPO      cands_repo    || BAD=1
resolve GAME_PAKS cands_paks    || BAD=1
resolve DECODER   cands_decoder || BAD=1
resolve USMAP     cands_usmap   || BAD=1
if [ "$BAD" -ne 0 ]; then
  echo
  echo "Set the ones above explicitly, e.g.:"
  echo "  REPO=/d/repos/UnkillablesRebalanceFix GAME_PAKS=... DECODER=... USMAP=... bash tools/verify_build.sh"
  exit 2
fi

PY="${PY:-}"
if [ -z "$PY" ]; then
  if command -v python  >/dev/null 2>&1; then PY=python
  elif command -v python3 >/dev/null 2>&1; then PY=python3
  else echo "MISSING: no python on PATH. Set PY=/path/to/python."; exit 2; fi
fi

WORK="${WORK:-$REPO/work/verify-live}"

# The staging dir hardlinks ~119 pak files (about 48 GB); hardlinks cannot cross volumes, so
# WORK must sit on the same drive as the game. Copying instead is not an option at that size.
drive_of() { printf '%s' "$1" | sed -n 's,^\([A-Za-z]\):.*,\1,p' | tr 'a-z' 'A-Z'; }
DW="$(drive_of "$WORK")"; DG="$(drive_of "$GAME_PAKS")"
if [ -n "$DW" ] && [ -n "$DG" ] && [ "$DW" != "$DG" ]; then
  echo "MISSING: the work dir and the game are on different volumes."
  echo "    work: $WORK"
  echo "    game: $GAME_PAKS"
  echo "Hardlinking the game into the work dir is what makes imports resolve, and hardlinks"
  echo "cannot cross volumes. Set WORK to a path on ${DG}: ."
  exit 2
fi

# PAKDIR is what gets verified. It defaults to the built pak in dist/, but it is an env override
# so the SAME check can be pointed at a previously shipped pak -- e.g.
#   PAKDIR=$REPO/work/prev-dist bash tools/verify_build.sh
# which is how the "what does the old pak do on the new build" measurement is taken (2026-08-23
# on the BPC, 2026-09-11 on the 6 boss CDOs). That leg had to be run by hand both times because
# this path was hardcoded.
PAKDIR="${PAKDIR:-$REPO/dist/UnkillablesRebalanceFix}"
PAKNAME="153_UnkillablesRebalance_P"
VERIFY="$REPO/tools/verify_softrefs.py"

# The dumptree filter. These are the retoc `-f` keys tools/build_fix.sh extracts with -- LOWRISK
# plus BASEPATCH, verbatim -- so the filter cannot drift away from the override surface without
# the build script changing too. Substring matching pulls in a few neighbours the mod does not
# ship (_HK / _BlindMother variants, the Toothy animation BP); that is harmless noise. What is
# NOT optional is coverage, so check 2 proves every shipped package produced a dump.
FILTER="AIDEF_Euruska_Stalker,BP_AI_Euruska_MeatMan,BP_AI_Euruska_OrgaMech,BP_AI_Euruska_ShieldOfficer,BP_Mech_Toothy,BP_AI_Eurasia_MotherCourage,BP_AI_Eurasia_Opal,BPC_IncomingDamageMod"

for p in "$PAKDIR/$PAKNAME.utoc" "$VERIFY"; do
  [ -e "$p" ] || { echo "MISSING: $p"; exit 2; }
done

echo "repo    : $REPO"
echo "game    : $GAME_PAKS"
echo "decoder : $DECODER"
echo "usmap   : $USMAP"
echo "work    : $WORK"
echo "python  : $PY"
echo

# Held until this script exits, by any route -- clean pass, failed check, or Ctrl-C.
fw_lock_acquire "verify_build.sh ${PAKDIR##*/}" || exit 2

rm -rf "$WORK"; mkdir -p "$WORK"
FAIL=0

# decode <out-dir> <paks-dir> <mode> [args...]  -- keeps the decoder log instead of /dev/null,
# because a decoder that silently wrote nothing is the exact failure verify_softrefs exists to
# stop being reported as a pass.
decode() {
  local out="$1" paks="$2"; shift 2
  mkdir -p "$out"
  FW_OUT="$out" FW_PAKS="$paks" FW_USMAP="$USMAP" "$DECODER" "$@" >"$out/decoder.log" 2>&1
}

echo "[1/6] enumerate what the pak actually ships (mount the mod alone)"
SHIPPAKS="$WORK/mod-only"; SHIPLIST="$WORK/ship-list"
mkdir -p "$SHIPPAKS"
for e in pak ucas utoc; do cp "$PAKDIR/$PAKNAME.$e" "$SHIPPAKS/" 2>/dev/null; done
decode "$SHIPLIST" "$SHIPPAKS" list
if [ ! -s "$SHIPLIST/filelist.txt" ]; then
  echo "      FAIL the decoder listed nothing from the mod pak. See $SHIPLIST/decoder.log"
  exit 2
fi
NSHIP=$(grep -c '\.uasset$' "$SHIPLIST/filelist.txt")
echo "      $NSHIP package(s) overridden by this mod"

echo "[2/6] regenerate the base filelist from the LIVE game"
BASELIST="$WORK/base-list"
decode "$BASELIST" "$GAME_PAKS" list
if [ ! -s "$BASELIST/filelist.txt" ]; then
  echo "      FAIL the decoder listed nothing from the live game. See $BASELIST/decoder.log"
  exit 2
fi
echo "      $(wc -l < "$BASELIST/filelist.txt") entries"

echo "[3/6] decode the CURRENT BASE versions (for the reversion check)"
BASEDUMP="$WORK/base-dump"
decode "$BASEDUMP" "$GAME_PAKS" dumptree "$FILTER" base
grep -m1 '^matched ' "$BASEDUMP/decoder.log" | sed 's/^/      /'

echo "[4/6] decode the SHIPPED pak inside a FULL game mount"
# Hardlink the whole live game so imports resolve exactly as the engine sees them; the mod is
# staged as zzz_ so it wins the FPackageId collision, same as the build scripts do.
VSTAGE="$WORK/stage"; SHIPDUMP="$WORK/ship-dump"
rm -rf "$VSTAGE"; mkdir -p "$VSTAGE"
for f in "$GAME_PAKS"/*; do [ -f "$f" ] && ln "$f" "$VSTAGE/$(basename "$f")"; done
for e in pak ucas utoc; do cp "$PAKDIR/$PAKNAME.$e" "$VSTAGE/zzz_URF_P.$e"; done
decode "$SHIPDUMP" "$VSTAGE" dumptree "$FILTER" shipped
rm -rf "$VSTAGE"
grep -m1 '^matched ' "$SHIPDUMP/decoder.log" | sed 's/^/      /'
if grep -q '^matched 0 ' "$SHIPDUMP/decoder.log"; then
  echo "      FAIL the filter matched nothing. The filter or the decoder mode is wrong."
  echo "      See $SHIPDUMP/decoder.log"
  exit 2
fi

echo "[5/6] coverage: every shipped package must have produced a dump"
"$PY" - "$SHIPLIST/filelist.txt" "$SHIPDUMP/dumptree/shipped" <<'PY' || FAIL=1
import os, sys
shiplist, dumpdir = sys.argv[1], sys.argv[2]
want = []
with open(shiplist, encoding="utf-8", errors="replace") as fh:
    for line in fh:
        p = line.strip()
        if p.lower().endswith(".uasset"):
            want.append(p.rsplit(".", 1)[0])
have, nfiles = set(), 0
for f in (os.listdir(dumpdir) if os.path.isdir(dumpdir) else []):
    if not f.endswith(".json"):
        continue
    nfiles += 1
    stem = f[:-len(".json")]
    if "__" in stem:
        stem = stem.rsplit("__", 1)[0]
    have.add(stem.lower())
missing = [w for w in want if w.replace("/", "_").lower() not in have]
print("=== dumptree coverage ===")
print("  %d shipped package(s), %d dump(s) written, %d uncovered"
      % (len(want), nfiles, len(missing)))
if not missing:
    print("  OK   the filter covers the whole override surface")
    sys.exit(0)
print("  FAIL %d shipped package(s) produced no dump:" % len(missing))
for m in missing:
    print("    -> " + m)
print("  Widen FILTER in this script, or the package moved in the live build.")
sys.exit(1)
PY

echo "[6/6] verify"
"$PY" "$VERIFY" "$SHIPDUMP/dumptree/shipped" "$BASELIST/filelist.txt" || FAIL=1

# Reversion check: for each shipped package, the shipped version must still carry every property
# shape the CURRENT BASE version has. A shape present in base and absent in the override is a
# field the devs added that this frozen cook drops. List indices are stripped, so reordering and
# row-count changes do not register -- only genuinely absent properties do.
#
# PAIRING IS THE DELICATE PART. In the staged mount both the base and the mod entry are
# enumerated (that is why the decoder reports more matches than the base run does). Where the
# path differs only by CASE -- this mod ships Euruska/Toothy/ while the live build has
# Euruska/TOOTHY/ -- the decoder writes TWO files, one base and one mod, and picking the wrong
# one silently compares base against base and always passes. So the shipped side is matched by
# EXACT case, taken from the mod's own filelist, and a case-insensitive fallback is reported
# rather than used quietly.
#
# Where the package path is byte-identical, however, BOTH copies write to the SAME filename and
# the last write wins. This script used to assert "the mod wins the lookup" there; that is not
# true, and it is the single most dangerous line this file ever contained. Which copy survives
# is decided by mount iteration order, which CUE4Parse does not fix (measured 2026-08-01 -- nine
# mounts of one pak returned the mod's copy for 0, 3, 4 or 7 of its 7 packages across runs;
# renaming the container 000_/aaa_/zzz_ changed nothing). Exact-case pairing does not help here
# because there is only ever one file. That is why the loop below carries an explicit
# provenance gate instead of an assumption.
"$PY" - "$SHIPLIST/filelist.txt" "$BASEDUMP/dumptree/base" "$SHIPDUMP/dumptree/shipped" <<'PY' || FAIL=1
import json, os, sys

shiplist, basedir, shipdir = sys.argv[1], sys.argv[2], sys.argv[3]

def index(d):
    """-> (exact stem -> path, lowercased stem -> [paths])"""
    exact, ci = {}, {}
    if not os.path.isdir(d):
        return exact, ci
    for f in os.listdir(d):
        if not f.endswith(".json"):
            continue
        stem = f[:-len(".json")]
        if "__" in stem:
            stem = stem.rsplit("__", 1)[0]
        p = os.path.join(d, f)
        exact[stem] = p
        ci.setdefault(stem.lower(), []).append(p)
    return exact, ci

def pick(exact, ci, stem, side):
    """-> (path, note). Exact case first; a case-only fallback is announced, never silent."""
    if stem in exact:
        return exact[stem], ""
    cands = ci.get(stem.lower(), [])
    if len(cands) == 1:
        return cands[0], "case differs from the %s dump" % side
    if not cands:
        return None, "no %s dump" % side
    return None, "AMBIGUOUS: %d case variants in the %s dump" % (len(cands), side)

def shapes(path):
    try:
        with open(path, encoding="utf-8") as fh:
            doc = json.load(fh)
    except (OSError, ValueError):
        return None
    out = set()
    def walk(n, trail):
        if isinstance(n, dict):
            for k, v in n.items():
                t = (trail + "." + k) if trail else k
                out.add(t)
                walk(v, t)
        elif isinstance(n, list):
            for v in n:
                walk(v, trail + "[]")
    walk(doc, "")
    return out

want = []
with open(shiplist, encoding="utf-8", errors="replace") as fh:
    for line in fh:
        p = line.strip()
        if p.lower().endswith(".uasset"):
            want.append(p.rsplit(".", 1)[0])

bexact, bci = index(basedir)
sexact, sci = index(shipdir)
print("\n=== property-shape reversion check ===")
if not bci or not sci:
    print("  FAIL one of the dumps is empty (base=%d ship=%d). The check did not run."
          % (len(bci), len(sci)))
    sys.exit(2)

bad = 0
compared = 0
for w in want:
    stem = w.replace("/", "_")
    name = w.rsplit("/", 1)[-1]
    # The mod's own path casing is authoritative for the shipped side.
    sf, snote = pick(sexact, sci, stem, "shipped")
    # The live build may store it under different casing, so the base side may legitimately
    # fall back -- there is only ever one base copy.
    bf, bnote = pick(bexact, bci, stem, "base")
    if sf is None or bf is None:
        print("  FAIL %-40s cannot pair: %s" % (name, snote or bnote))
        bad = 1
        continue
    if snote or bnote:
        print("  NOTE %-40s %s" % (name, bnote or snote))
    # PROVENANCE GATE. Everything below this line compares the shipped dump against the base
    # dump, which is worthless if the "shipped" dump IS the base copy. In the staged full mount
    # both copies are enumerated and, where the package path matches byte-for-byte, both write
    # to the same filename -- last write wins, and CUE4Parse resolves colliding paths
    # non-deterministically (measured 2026-08-01). Exact-case pairing above only rescues the
    # case-differing packages; for the identical-path ones nothing forces the mod to win. A
    # base-vs-base comparison trivially reports "0 dropped", which is the false pass this whole
    # script exists to prevent. Every package this mod ships changes at least one scalar, so
    # byte-equality with base means the mount graded vanilla -- not that the mod is clean.
    try:
        with open(bf, "rb") as fb, open(sf, "rb") as fs:
            if fb.read() == fs.read():
                print("  FAIL %-40s dump is IDENTICAL to base -- the mount graded the base"
                      % name)
                print("       copy, so this comparison proves nothing. Re-run; if it repeats,")
                print("       mount the pak in isolation instead of staging the full game.")
                bad = 1
                continue
    except OSError:
        pass
    bsh, ssh = shapes(bf), shapes(sf)
    if bsh is None or ssh is None:
        print("  FAIL %-40s unreadable dump" % name)
        bad = 1
        continue
    compared += 1
    lost = sorted(bsh - ssh)
    gained = len(ssh - bsh)
    if not lost:
        print("  OK   %-40s base %4d shapes, ship %4d (+%d)" % (name, len(bsh), len(ssh), gained))
        continue
    bad = 1
    print("  FAIL %-40s DROPS %d propert(ies) the live build has:" % (name, len(lost)))
    for l in lost[:12]:
        print("        -> " + l)
    if len(lost) > 12:
        print("        ... and %d more" % (len(lost) - 12))

print("  compared %d of %d shipped package(s)" % (compared, len(want)))
if bad:
    print("  A dropped property means this frozen override reverts something the devs added.")
    print("  Rebuild that asset from the current base (Option B in tools/build_fix.sh).")
    sys.exit(1)
print("  OK   0 properties dropped")
sys.exit(0)
PY

echo
if [ "$FAIL" -ne 0 ]; then echo "RESULT: FAILURES ABOVE"; exit 1; fi
echo "RESULT: clean - full coverage, 0 dangling references, 0 properties dropped"
echo "        (structural only; this does not clear Blueprint graph drift)"
