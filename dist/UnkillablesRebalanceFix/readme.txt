Unkillables Rebalance — Fix  (v1.3, for The Forever Winter build 24536482)
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
  The original was cooked for game 0.9.2.2. On newer builds its copies of the game's files no
  longer line up with what the game expects. That caused two crashes:
    - an out-of-date Meatman crashed the game on startup (fixed in v1.1);
    - out-of-date Grabber/Stalker data crashed the game when you SHOT a Grabber (fixed in v1.3).
  Every one of the 11 files this mod replaces is now rebuilt from the CURRENT game files with
  only the rebalance numbers changed, so they load exactly like the game's own files. Nothing
  left over from the old game version ships any more.

  Earlier versions kept the 4 Grabber/Stalker files as-is, on the assumption that plain data
  files couldn't cause a crash. That was wrong — the game matches data to fields by position,
  so an out-of-date file quietly reads the wrong values and crashes when one gets used.

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

TEST CHECKLIST (build 24536482)
  1. Reaches main menu and loads a mission without crashing.
  2. Each rebalanced boss can be staggered and killed by weapons (not just the DetPack loop);
     no ObjectSerializationError for any BP_AI_* / BP_Mech_Toothy / BPC_IncomingDamageMod.
  3. Shoot a Grabber/Stalker repeatedly until it staggers — no crash. (This is the v1.3 fix.)
  4. Grabber/Stalker swipes for ~600 and disengages instead of insta-grabbing (above 1000 HP).
  5. ...\Saved\Crashes\ stays empty.

NOTE ON GAME UPDATES
  This mod ships whole copies of game files, so every game patch makes it out of date and it
  has to be rebuilt. If a patch has landed and there's no newer release here, assume this one
  is stale — that is the usual cause of a sudden crash or of the mod appearing to do nothing.

KNOWN (pre-existing, from the original mod — not introduced here)
  - Mother Courage / OrgaMech sometimes freeze to an idle pose on death before despawning
    (the original author documents this). Not a crash.

Original mod by its Nexus #68 author. This compatibility rebuild is redistributed on that basis
and remains subject to the original author's permission.
