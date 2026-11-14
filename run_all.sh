#!/usr/bin/env bash
# Run all six Section 6 BehaviorSpace experiments headless, one after another.
#
#   ./run_all.sh            start in the background (nohup), log to run_all.log
#   tail -f run_all.log     watch progress
#   ./run_all.sh            run again to resume: experiments whose CSV already exists are skipped
#
# Results are written to <experiment>.csv.partial while running and renamed to
# <experiment>.csv only when NetLogo exits successfully, so an interrupted run is
# never mistaken for a finished one (it is simply redone on resume).
#
# Environment overrides:
#   NETLOGO_HEADLESS  path to netlogo-headless.sh (auto-detected otherwise)
#   THREADS           parallel runs per experiment (default 2)

set -u
cd "$(dirname "$0")"
ROOT="$PWD"
LOG="$ROOT/run_all.log"

# Re-launch under nohup (and caffeinate on macOS so the machine does not sleep).
if [ -z "${RUN_ALL_CHILD:-}" ]; then
  export RUN_ALL_CHILD=1
  if command -v caffeinate >/dev/null 2>&1; then
    nohup caffeinate -i "$0" "$@" >>"$LOG" 2>&1 &
  else
    nohup "$0" "$@" >>"$LOG" 2>&1 &
  fi
  echo "Started in background (pid $!). Log: $LOG"
  exit 0
fi

MODEL="$ROOT/controlling-the-misinformation-diffusion-in-social-media-by-the-effect-of-different-classes-of-agents_v1.0.0/code/Controlling the misinformation diffusion.nlogo"
THREADS="${THREADS:-2}"
EXPERIMENTS="main sens_check_delay sens_r sens_skep_low sens_skep_normal sens_skep_high"

NL="${NETLOGO_HEADLESS:-}"
if [ -z "$NL" ]; then
  NL="$(command -v netlogo-headless.sh || true)"
  [ -z "$NL" ] && NL="$(ls -d /Applications/NetLogo*/netlogo-headless.sh /opt/NetLogo*/netlogo-headless.sh \
                         "$HOME"/NetLogo*/netlogo-headless.sh 2>/dev/null | sort -V | tail -1)"
fi
[ -x "$NL" ] || { echo "$(date '+%F %T') ERROR: netlogo-headless.sh not found; set NETLOGO_HEADLESS"; exit 1; }
[ -f "$MODEL" ] || { echo "$(date '+%F %T') ERROR: model not found: $MODEL"; exit 1; }

echo "$(date '+%F %T') === run_all start (threads=$THREADS, netlogo=$NL)"
failed=0
for exp in $EXPERIMENTS; do
  out="$ROOT/$exp.csv"
  if [ -s "$out" ]; then
    echo "$(date '+%F %T') skip $exp ($exp.csv exists)"
    continue
  fi
  echo "$(date '+%F %T') start $exp"
  start=$(date +%s)
  rm -f "$out.partial"
  # NetLogo prints the model's output-area text for every run; drop it to keep the log readable.
  "$NL" --model "$MODEL" --experiment "$exp" --table "$out.partial" --threads "$THREADS" 2>&1 \
    | grep -vE '^\* False-alarm|^ alarm type:|^ darker colors|^ orange = verifying|^$'
  status=${PIPESTATUS[0]}
  secs=$(( $(date +%s) - start ))
  if [ "$status" -eq 0 ] && [ -s "$out.partial" ]; then
    mv "$out.partial" "$out"
    echo "$(date '+%F %T') done  $exp in ${secs}s -> $exp.csv"
  else
    echo "$(date '+%F %T') FAIL  $exp (exit $status after ${secs}s); partial output left in $exp.csv.partial"
    failed=1
  fi
done
echo "$(date '+%F %T') === run_all finished (failed=$failed)"
exit $failed
