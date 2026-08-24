#!/usr/bin/env python3
"""Patch the CURRENT base Stalker (Grabber) AIDEF DataAssets with ONLY the mod's two
rebalanced scalars changed (Option B).

WHY THIS EXISTS — and what it did NOT turn out to fix. Read this before citing it.
Until 2026-08-05 these 4 AIDEFs were the last assets still built via Option A: the mod's own
cook, frozen at game 0.9.2.2. The justification, written in build_fix.sh and patch_drifted.py,
was "DataAssets carry no Kismet bytecode, so there is no serialization-crash surface."

That justification is not sound IN GENERAL. UE5 cooked assets use UNVERSIONED property
serialization: a property is identified by its INDEX in the class's property schema, not by its
name. If a class gains, removes, or reorders a UPROPERTY, a frozen cook's bitstream misaligns
against the current schema and values decode into the WRONG fields -- object and soft-object
pointers included -- which crashes when a field is DEREFERENCED rather than at load. Absence of
bytecode does not protect against that; it is a property-layout problem, not a bytecode problem.

BUT: on 2026-08-05 that mechanism was adopted as the explanation for players crashing when they
SHOT the Grabber, and on 2026-08-23 the first real rebuild MEASURED its precondition and found
it FALSE. All 4 AIDEFs build byte-identical to the frozen 0.9.2.2 cook (uexp 206/205/202/202 B;
the only bytes differing from current base are the 4 belonging to the 2 scalars below). This
class never drifted, so it was never mis-decoding, and this script did not fix the reported
crash -- it produces exactly the bytes that were already shipping. The crash has no established
cause. See docs/diagnosis.md and WORKLOG.md Session 6.

So keep this script for the reason that survives -- nothing frozen should remain in the
pipeline, and Option B drops the upstream/ requirement for good -- not as a fix. And note the
shape of the error, which is now three deep: 2026-07-10 "export counts match, so the cook is
safe"; 2026-08-05 "no bytecode, so the cook is safe"; then 2026-08-05's own correction, a
mechanism that explained the symptom and was adopted without measuring whether it applied.
A mechanism that explains the symptom is not evidence that it occurred.

- 4 variants: AIDEF_Euruska_Stalker + _HK / _Pregnant_Quest / _Underground.
- DamageToStagger        20000.0 -> 1000.0  (float32)  = 20x easier to stun
- SyncKillMaxPlayerHealth 2000.0 -> 1000.0  (float32)  = no insta-kill grab above 1000 hp

Self-verifying, in the same spirit as patch_drifted.py: every expected base value must occur
EXACTLY ONCE in the file before anything is written, and the post-write state is re-checked.
Aborts loudly rather than guessing -- see _ABORT_HELP below for what an abort means.
"""
import struct, sys, os

STALKERS = [
    "AIDEF_Euruska_Stalker",
    "AIDEF_Euruska_Stalker_HK",
    "AIDEF_Euruska_Stalker_Pregnant_Quest",
    "AIDEF_Euruska_Stalker_Underground",
]

# (property name, base value, mod value). Both scalars are float32; see
# docs/rebalance-values.json -> stalker_aidef.
SCALARS = [
    ("DamageToStagger",         20000.0, 1000.0),
    ("SyncKillMaxPlayerHealth",  2000.0, 1000.0),
]

_ABORT_HELP = """
  What an abort here means:
    found 0  -> the devs changed this base default on the current build. The values in
                docs/rebalance-values.json were datamined on 24097213 and have NOT been
                re-datamined since. Re-datamine the AIDEF, update rebalance-values.json and
                the SCALARS table above, then re-run.
    found >1 -> the byte pattern is ambiguous in this file: some other float32 in the asset
                happens to share the value, so a blind patch could hit the wrong field.
                Locate the real property offset (decode the asset) before proceeding.
  Do NOT relax these assertions to get a build out. Shipping a wrong offset is silent -- it
  produces a pak that loads fine and rebalances the wrong thing.
"""


def f32(v):
    return struct.pack('<f', v)


def offsets_of(data, pat):
    """All occurrences of pat in data (non-overlapping is irrelevant at 4 bytes here)."""
    out, start = [], 0
    while True:
        i = data.find(pat, start)
        if i < 0:
            return out
        out.append(i)
        start = i + 1


def patch_aidef(path):
    name = os.path.basename(path)
    if not os.path.exists(path):
        sys.exit(f"ABORT {name}: not found at {path}")
    data = bytearray(open(path, 'rb').read())

    # The mod sets BOTH scalars to the same value (1000.0f), so a chained bytes.replace would
    # let the first substitution's output be re-matched by the second. Resolve every offset
    # against the UNMODIFIED buffer first, assert, and only then write.
    plan = []
    bad = False
    for prop, base, mod in SCALARS:
        hits = offsets_of(data, f32(base))
        if len(hits) != 1:
            print(f"  [aidef] FAIL {name}: {prop} expected 1x float32 {base:.0f}, found {len(hits)}")
            bad = True
            continue
        plan.append((hits[0], prop, base, mod))
    if bad:
        sys.exit(f"ABORT {name}: base scalars not found exactly once (see above)\n{_ABORT_HELP}")

    # Post-condition reference: the mod's payload is recognisable as 1000.0f x2, which is what
    # the old Option-A provenance gate asserted. Count what is already there so a file that
    # legitimately contains an unrelated 1000.0f still verifies exactly.
    pre_mod_hits = len(offsets_of(data, f32(1000.0)))

    for off, prop, base, mod in plan:
        data[off:off + 4] = f32(mod)

    post_mod_hits = len(offsets_of(data, f32(1000.0)))
    want = pre_mod_hits + len(plan)
    if post_mod_hits != want:
        sys.exit(f"ABORT {name}: after patching expected {want}x 1000.0f, found {post_mod_hits}")
    for _, _, base, _ in plan:
        if offsets_of(data, f32(base)):
            sys.exit(f"ABORT {name}: base value {base:.0f} still present after patching")

    open(path, 'wb').write(data)
    changes = ", ".join(f"{p} {b:.0f}->{m:.0f}" for _, p, b, m in plan)
    print(f"  [aidef] {name}: {changes}")


def main():
    root = sys.argv[1]  # build-legacy/ForeverWinter/Content/FW/AI/Characters
    for n in STALKERS:
        patch_aidef(os.path.join(root, "Euruska/Stalker", n + ".uexp"))
    print(f"  [aidef] {len(STALKERS)} Stalker AIDEF(s) patched from current base (Option B)")


if __name__ == "__main__":
    main()
