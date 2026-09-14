#!/usr/bin/env bash
# Mutual exclusion for fwextract runs. Source it to hold the lock for a whole script, or use it
# as a wrapper to run one command under it.
#
# WHY THIS EXISTS
#   2026-09-11: SylDesk hard-froze and had to be killed by the power button. A full
#   verify_build.sh run went into the background at 14:07:42 (PAKDIR=work/prev-dist, still in
#   its decode stages at 14:14) and an ad-hoc `fwextract dumptree ... oldmapall` was launched
#   on top of it at 14:09:33. The desktop stopped responding 26 seconds later. Nothing
#   crashed -- no bugcheck, no dump, and the System event log has a 2h21m hole because the
#   Event Log service could not get a write in. The second decoder finished cleanly at 14:19
#   (ok=27 fail=0) WHILE the UI was dead, which is the tell: input starved, disk work did not.
#
#   Two decoders is all it takes. The mount itself is cheap -- the 30 .utoc index files total
#   22 MB -- but the payload behind them is 45 GB of .ucas, and two processes random-reading
#   that blows out the page cache and saturates a drive that has 14 GB free of 466. Everything
#   else on the machine then has to fault back in from C:.
#
#   So: one fwextract at a time, machine-wide.
#
# USE
#   as a wrapper -- for ad-hoc decoder calls, which is the case that caused the freeze:
#       bash tools/fwlock.sh "$DEC" dumptree "$FILTER" oldmapall
#   sourced -- for a script that owns the decoder across several stages:
#       . "$(dirname "$0")/fwlock.sh"
#       fw_lock_acquire "verify_build.sh" || exit 2
#   The lock releases itself on exit, including on Ctrl-C and on a failed check.
#
# KNOBS
#   FW_LOCK       lock directory (default /tmp/fwextract.lock.d -- per-user, outside every
#                 repo, so a decoder run from forever-winter-datamine or another mod repo
#                 contends for the same lock rather than sailing past it)
#   FW_LOCK_WAIT  seconds to wait for the holder before giving up. Default 1800; a verify run
#                 takes roughly 7-12 minutes, so the default tolerates a queue of two.
#                 FW_LOCK_WAIT=0 fails immediately instead of waiting.
#
# There is no flock on Git Bash (checked on SylDesk, MSYS 3.6.6), so this is an atomic
# `mkdir` lock. A holder that died without releasing is detected by its recorded pid being
# gone and the lock is taken over -- which is what recovers the 2026-09-11 case, where the
# power button left no chance to clean up.

FW_LOCK="${FW_LOCK:-/tmp/fwextract.lock.d}"
FW_LOCK_WAIT="${FW_LOCK_WAIT:-1800}"

_FW_LOCK_HELD=0

fw_lock_acquire() {
  local who="${1:-$(basename "${0:-shell}")}"
  local waited=0 races=0 announced=0
  local hpid howner hsince

  while :; do
    if mkdir "$FW_LOCK" 2>/dev/null; then
      # Won it. Populate before anyone can read, then arm the release.
      printf '%s\n' "$$"                          > "$FW_LOCK/pid"
      printf '%s\n' "$who"                        > "$FW_LOCK/owner"
      printf '%s\n' "$(date '+%Y-%m-%d %H:%M:%S')" > "$FW_LOCK/since"
      _FW_LOCK_HELD=1
      trap fw_lock_release EXIT
      trap 'exit 130' INT
      trap 'exit 143' TERM
      return 0
    fi

    hpid="$(cat "$FW_LOCK/pid" 2>/dev/null || true)"
    howner="$(cat "$FW_LOCK/owner" 2>/dev/null || echo '?')"
    hsince="$(cat "$FW_LOCK/since" 2>/dev/null || echo '?')"

    if [ -z "$hpid" ]; then
      # The winner is between mkdir and writing pid. Retry without spending the wait budget,
      # but not forever -- an empty lock dir that never fills is a lock dir someone made by
      # hand, and that should surface as a timeout rather than spin.
      races=$((races + 1))
      if [ "$races" -gt 10 ]; then
        echo "STUCK: $FW_LOCK exists but records no pid. If no decoder is running, remove it."
        return 1
      fi
      sleep 1
      continue
    fi

    if ! kill -0 "$hpid" 2>/dev/null; then
      echo "      stale fwextract lock: $howner (pid $hpid, held since $hsince) is gone -- taking it"
      rm -rf "$FW_LOCK"
      continue
    fi

    if [ "$FW_LOCK_WAIT" -eq 0 ]; then
      echo "BUSY: fwextract is already running -- $howner (pid $hpid, since $hsince)"
      return 1
    fi

    if [ "$announced" -eq 0 ]; then
      echo "waiting for fwextract: $howner (pid $hpid) has held the lock since $hsince"
      echo "      (one decoder at a time -- see tools/fwlock.sh. FW_LOCK_WAIT=0 to fail instead.)"
      announced=1
    fi

    if [ "$waited" -ge "$FW_LOCK_WAIT" ]; then
      echo "TIMEOUT: waited ${waited}s for the fwextract lock held by $howner (pid $hpid, since $hsince)."
      echo "         If that process is gone, remove: $FW_LOCK"
      return 1
    fi

    sleep 5
    waited=$((waited + 5))
  done
}

fw_lock_release() {
  [ "$_FW_LOCK_HELD" -eq 1 ] || return 0
  # Only drop a lock we still own. If ours was judged stale and taken over, the pid on disk is
  # someone else's and removing it would hand the decoder to two runs at once.
  local hpid
  hpid="$(cat "$FW_LOCK/pid" 2>/dev/null || true)"
  [ "$hpid" = "$$" ] || { _FW_LOCK_HELD=0; return 0; }
  _FW_LOCK_HELD=0
  rm -rf "$FW_LOCK"
}

# ---------------------------------------------------------------------------
# Wrapper mode: executed rather than sourced.
# ---------------------------------------------------------------------------
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  if [ "$#" -eq 0 ]; then
    echo "usage: bash tools/fwlock.sh <command> [args...]"
    echo "       runs <command> with the machine-wide fwextract lock held."
    exit 2
  fi
  fw_lock_acquire "$(basename "$1")" || exit 2
  "$@"
  exit $?
fi
