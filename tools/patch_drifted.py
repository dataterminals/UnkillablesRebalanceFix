#!/usr/bin/env python3
"""Patch the CURRENT base cooked assets with ONLY the mod's rebalanced scalars changed
(Option B). Keeps whatever structure the CURRENT base cook has so we don't ship stale bytecode /
revert base content / crash with ObjectSerializationError.

Covers all 6 boss BPs + BPC. (The 4 Stalker AIDEF DataAssets stay Option-A rebased in
build_fix.sh — DataAssets carry no bytecode, so no serialization-crash surface.)

The 4 "low-risk" boss BPs (MeatMan/OrgaMech/ShieldOfficer/Toothy) were MOVED here from
Option A after the mod's stale 0.9.2.2 MeatMan cook crashed on 0.9.3.9.2 (community-confirmed
`ObjectSerializationError: .../BP_AI_Euruska_MeatMan ... Bad export index`, 2026-07-10).
Export-count parity did NOT guarantee the stale cook loads: current base MeatMan is a small
superset (gained a "Sync Kill in Log" element post-0.9.2.2), so the mod's cooked references
desync at runtime. Shipping the current base + patched scalar avoids it entirely.

- Boss BPs: FWHealthComponent DefaultHealth+DefaultMaxHealth (float32, 2 sites each) -> mod
  value (MeatMan 330k, OrgaMech 286870, ShieldOfficer 328k, Toothy 9e8->308700,
  MotherCourage 372k, Opal 213k).
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
    # 4 boss BPs moved from Option A -> B (mod's stale cooks crash on 0.9.3.9.2; MeatMan confirmed)
    patch_health(os.path.join(root, "Euruska/MeatMan/BP_AI_Euruska_MeatMan.uexp"), 1e9, 330000.0)
    patch_health(os.path.join(root, "Euruska/OrgaMech/BP_AI_Euruska_OrgaMech.uexp"), 1e9, 286870.0)
    patch_health(os.path.join(root, "Euruska/ShieldOfficer/BP_AI_Euruska_ShieldOfficer.uexp"), 1e9, 328000.0)
    patch_health(os.path.join(root, "Euruska/Toothy/BP_Mech_Toothy.uexp"), 9e8, 308700.0)
    # originally-drifted 3 (base grew exports since 0.9.2.2)
    patch_health(os.path.join(root, "Eurasia/MotherCourage/BP_AI_Eurasia_MotherCourage.uexp"), 1e9, 372000.0)
    patch_health(os.path.join(root, "Eurasia/Opal/BP_AI_Eurasia_Opal.uexp"), 1e9, 213000.0)
    patch_bpc(os.path.join(root, "Shared/BPC_IncomingDamageMod.uexp"))

if __name__ == "__main__":
    main()
