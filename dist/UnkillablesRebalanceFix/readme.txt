Unkillables Rebalance — Fix  (v1.4, for The Forever Winter build 25071553)
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
  longer line up with what the game expects — an out-of-date Meatman crashed the game on
  startup back in v1.1. Every one of the 11 files this mod replaces is now rebuilt from the
  CURRENT game files with only the rebalance numbers changed, so they load exactly like the
  game's own files. Nothing left over from the old game version ships any more.

WHAT v1.4 FIXES — DO NOT RUN v1.3 ON BUILD 25071553
  The 2026-09-10 patch (build 25071553) changed the internal layout of the boss character
  class. The game stores these files as a bare list of values with no names attached, matched
  up by position, so when the layout moves, an older file is read WRONG rather than rejected.

  Measured against the live game, that is exactly what happens to the v1.3 boss files: on all
  six bosses the values slide onto the wrong settings partway through (on Meatman, its
  "far distance" reads 150 instead of 750, and 750 lands on the close-range setting), and then
  the read runs off the rails and 19 of its 35 settings are simply gone — including which
  skeletal mesh, collision capsule, movement component and AI controller the boss uses. A boss
  missing those is the same shape of breakage as the v1.1 Meatman startup crash.

  The check that proves it is the game patch and not a bad pak: the very same v1.3 files, read
  with the PREVIOUS build's layout, come out perfect — every setting present and correct.

  This build re-takes all 11 files from build 25071553 and re-applies the rebalance, so
  everything lines up again. Verified against the live game: nothing dropped, every reference
  resolves. The rebalance numbers themselves have not moved since v1.1.

  The four Grabber/Stalker files are byte-for-byte identical to v1.3 — that class did not move
  in this patch. The shared damage component did not lose anything either this time.

  ABOUT THE "CRASH WHEN SHOOTING THE GRABBER" REPORT
  Still open, and still needs a crash log. The suspected cause (the Grabber data files being
  out of date) was ruled out by measurement back in v1.3 and nothing here changes that. If you
  crash when you shoot a Grabber on this build, please send:
      ...\Saved\Crashes\   and   ...\Saved\Logs\ForeverWinter.log

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

TEST CHECKLIST (build 25071553)
  1. Reaches main menu and loads a mission without crashing.
  2. Each rebalanced boss can be staggered and killed by weapons (not just the DetPack loop);
     no ObjectSerializationError for any BP_AI_* / BP_Mech_Toothy / BPC_IncomingDamageMod.
  3. Bosses spawn with their normal model, collision and behaviour — no T-pose, no invisible
     or inert boss. (That is what the v1.3-on-25071553 breakage would look like.)
  4. Shoot a Grabber/Stalker repeatedly until it staggers — no crash. (Still an open report;
     if it happens, send the crash log.)
  5. Grabber/Stalker swipes for ~600 and disengages instead of insta-grabbing (above 1000 HP).

A NOTE ON UPDATES
  This mod ships whole copies of game files, so it has to be rebuilt after EVERY game patch.
  If a patch lands and there is no new release here yet, assume this one is out of date.
