Unkillables Rebalance — Fix  (rebuilt for The Forever Winter build 24501089, 2026-08-01)
=========================================================================================

Original mod: "Unkillables Rebalance" (Nexus #68). This is a community compatibility
rebuild that reapplies the exact same rebalance on the current game build.

WHAT IT DOES (unchanged from the original mod)
  - 6 "unkillable" bosses get finite, killable HP instead of the 1e9/9e8 invincibility pool:
      MeatMan 330,000 · OrgaMech 286,870 · ShieldOfficer 328,000 · Toothy 308,700 ·
      Mother Courage 372,000 · Opal 213,000   (non-Hunter-Killer variants)
  - Grabber/Stalker (all 4 variants): 20x easier to stagger (DamageToStagger 20000 -> 1000)
    and no insta-kill grab unless you're already below 1000 HP (it does a ~600-dmg swipe and
    disengages instead).
  - Armour/body-zone HP thresholds on the armoured bosses scaled down so zones are destroyable.

WHY A REBUILD
  The original was cooked for game 0.9.2.2. On the current build its boss blueprints no longer
  load: an out-of-date copy of the Meatman crashed the game on startup (ObjectSerializationError).
  This build rebuilds all six bosses from the CURRENT game files with only their health numbers
  changed, so they load cleanly while keeping the exact same rebalance. (The 4 Grabber/Stalker
  data files are simple value tables with no crash risk, so they carry over unchanged.)

INSTALL
  Copy the three files
      153_UnkillablesRebalance_P.pak
      153_UnkillablesRebalance_P.ucas
      153_UnkillablesRebalance_P.utoc
  into your pak-mods folder, the same place the original mod's 153_ files went:
      ...\The Forever Winter\Windows\ForeverWinter\Content\Paks\Mods\
  (create the Mods\ folder if it doesn't exist). Keep the pak-mod loader you already use
  (Signature Bypass + UE4SS) current for 0.9.3.x. After a game hotfix, a clean reinstall of the
  loader + this pak is the community-standard step (remove, don't just toggle).

  Remove the ORIGINAL mod's 153_ files first — don't run both.

TEST CHECKLIST (build 24501089)
  1. Reaches main menu and loads a mission without crashing.
  2. Each rebalanced boss can be staggered and killed by weapons (not just the DetPack loop);
     no ObjectSerializationError for any BP_AI_* / BP_Mech_Toothy / BPC_IncomingDamageMod.
  3. Grabber/Stalker swipes for ~600 and disengages instead of insta-grabbing (above 1000 HP).
  4. ...\Saved\Crashes\ stays empty.

KNOWN (pre-existing, from the original mod — not introduced here)
  - Mother Courage / OrgaMech sometimes freeze to an idle pose on death before despawning
    (the original author documents this). Not a crash.

Original mod by its Nexus #68 author. This compatibility rebuild is redistributed on that basis
and remains subject to the original author's permission.
