#!/usr/bin/env python3
"""Patch the 3 structurally-drifted assets = CURRENT base cooked BPs with ONLY the
mod's rebalanced scalars changed (Option B). Keeps current 0.9.3.9.2 structure so we
don't ship stale 0.9.2.2 bytecode / revert base content.

- MotherCourage / Opal: FWHealthComponent DefaultHealth+DefaultMaxHealth (float32, 2 each)
  1e9 -> mod value.
- BPC_IncomingDamageMod: 19 ordered Kismet double constants (armour/body-zone HP).
  Self-verifying: the base double sequence (in file/offset order) MUST equal the order
  datamined from the mod (docs/rebalance-values.json indices 20-38) before any write.

Idempotent-safe: aborts if the expected base values aren't found in the expected counts.
"""
import struct, sys, os

def f32(v): return struct.pack('<f', v)
def f64(v): return struct.pack('<d', v)

def patch_health(path, base, mod):
    data = bytearray(open(path, 'rb').read())
    n = data.count(f32(base))
    if n != 2:
        sys.exit(f"ABORT {os.path.basename(path)}: expected 2x float32 {base}, found {n}")
    data = data.replace(f32(base), f32(mod))
    open(path, 'wb').write(data)
    print(f"  [health] {os.path.basename(path)}: {base:.0f} -> {mod:.0f}  (2 sites)")

# BPC ordered constant map (base -> mod), indices 20..38 from rebalance-values.json
BPC_BASE = [168700,168700,168700,168700,168700,168700,210000,168700,168700,168700,
            168700,168700,126000,126000,210000,283500,283500,330000,210000]
BPC_MOD  = [ 61870, 61870, 61870, 61870,108700,108700, 72000,108700,108700,108700,
            108700,108700, 86870, 86870, 43000,128000,128000,128000, 43000]

def patch_bpc(path):
    data = bytearray(open(path, 'rb').read())
    # collect (offset, value) for every occurrence of each distinct base double
    hits = []
    for v in set(BPC_BASE):
        pat = f64(float(v)); start = 0
        while True:
            i = data.find(pat, start)
            if i < 0: break
            hits.append((i, v)); start = i + 1
    hits.sort()
    got = [v for _, v in hits]
    if got != BPC_BASE:
        print("  [bpc] EXPECTED base seq:", BPC_BASE)
        print("  [bpc] ACTUAL   base seq:", got)
        sys.exit("ABORT BPC: base double sequence != datamined order (see above)")
    for (off, _), newv in zip(hits, BPC_MOD):
        data[off:off+8] = f64(float(newv))
    open(path, 'wb').write(data)
    print(f"  [bpc] {os.path.basename(path)}: patched {len(hits)} ordered doubles (verified order)")

def main():
    root = sys.argv[1]  # build-legacy/ForeverWinter/Content/FW/AI/Characters
    patch_health(os.path.join(root, "Eurasia/MotherCourage/BP_AI_Eurasia_MotherCourage.uexp"), 1e9, 372000.0)
    patch_health(os.path.join(root, "Eurasia/Opal/BP_AI_Eurasia_Opal.uexp"), 1e9, 213000.0)
    patch_bpc(os.path.join(root, "Shared/BPC_IncomingDamageMod.uexp"))

if __name__ == "__main__":
    main()
