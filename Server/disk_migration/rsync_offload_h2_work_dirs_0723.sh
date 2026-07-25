#!/bin/bash
# Migrate dormant nextflow work/ dirs of CLOSED/delivered projects_2026H2 projects
# to the mechanical HDD /srv/external_data/gao_projects_offload/, freeing space on
# the full ex_8T_SSD. See reference_ex8tssd_disk_migration_plan memory for full context.
# Ordered smallest-first for incremental relief. Each dir: rsync -> verify -> rm original -> symlink.
#
# RUN RECORD (2026-07-23): executed as an emergency fix after ex_8T_SSD hit 0 bytes
# available (df showed 6.9T/7.3T used — actually 100% of the non-reserved space; see
# disk_monitor/README.md for the ext4 5%-reserved-blocks explanation of that "0 available"
# reading), which crashed project 19's nextflow run overnight with "No space left on device".
# All 7 DIRS below completed successfully, ~3.28 TiB freed total. Full log alongside this
# script: migration_run_0723.txt. DIRS is a one-off candidate list for THIS run — reusing
# this script for a future migration requires editing DIRS to the new candidate set (see
# reference_ex8tssd_disk_migration_plan memory / facilities/software_pitfalls if a similar
# situation recurs); don't run as-is expecting it to find new candidates automatically.
#
# ⚠ IMPORTANT GITIGNORE GOTCHA hit during this run: after rsync+rm+symlink, git started
# showing these paths as untracked. Root cause: .gitignore patterns ending in a trailing
# `/` (e.g. `work/`, `work_*/`) only match real directories, NOT symlinks — once a work/
# dir becomes a symlink, those rules silently stop matching it. Fix applied same day:
# dropped the trailing `/` from the relevant .gitignore rules in projects_2026H2/.gitignore
# (commit 11e4a77). Apply the same fix to any other repo before migrating its work/ dirs.

DEST_BASE="/srv/external_data/gao_projects_offload/projects_2026H2_offload"
SRC_BASE="/home/gao/projects_2026H2"
LOG="/tmp/claude-1001/-home-gao/d25ae087-30e1-4a29-a13c-afbf2326e477/scratchpad/migration_run.log"

# smallest first, for incremental space relief
DIRS=(
  "17_Daniel_Mendes_gut_metagenomics/work_taxprofiler"
  "17_Daniel_Mendes_gut_metagenomics/work_mag"
  "1_opossum_YuFan/script_opposum/work"
  "9_Lijian_Wu_Mouse/scripts/work"
  "6_jinlong_mouse/scripts/work"
  "16_Wenliang_Pan_wgs/work"
  "13_Ellen_knockin_wgs/work"
)

ts() { date '+%Y-%m-%d %H:%M:%S'; }

for rel in "${DIRS[@]}"; do
  SRC="$SRC_BASE/$rel"
  DST="$DEST_BASE/$rel"

  echo "[$(ts)] ══ START $rel ══" | tee -a "$LOG"

  if [ ! -e "$SRC" ]; then
    echo "[$(ts)] ⚠️  SRC missing, skipping: $SRC" | tee -a "$LOG"
    continue
  fi

  mkdir -p "$(dirname "$DST")"

  echo "[$(ts)] rsync starting..." | tee -a "$LOG"
  if ! rsync -a --stats "$SRC/" "$DST/" >> "$LOG" 2>&1; then
    echo "[$(ts)] ❌ RSYNC FAILED for $rel — leaving source untouched, moving to next dir" | tee -a "$LOG"
    continue
  fi

  SRC_SIZE=$(du -sb "$SRC" | cut -f1)
  DST_SIZE=$(du -sb "$DST" | cut -f1)
  SRC_COUNT=$(find "$SRC" | wc -l)
  DST_COUNT=$(find "$DST" | wc -l)

  echo "[$(ts)] verify: src_size=$SRC_SIZE dst_size=$DST_SIZE src_count=$SRC_COUNT dst_count=$DST_COUNT" | tee -a "$LOG"

  if [ "$SRC_COUNT" != "$DST_COUNT" ]; then
    echo "[$(ts)] ❌ FILE COUNT MISMATCH for $rel — ABORTING deletion of source, needs manual review" | tee -a "$LOG"
    continue
  fi

  DIFF_PCT=$(awk -v s="$SRC_SIZE" -v d="$DST_SIZE" 'BEGIN{ if (s==0) print 0; else printf "%.3f", ((s-d)/s)*100 }')
  echo "[$(ts)] size diff = ${DIFF_PCT}%" | tee -a "$LOG"

  ABS_DIFF=$(awk -v x="$DIFF_PCT" 'BEGIN{print (x<0)?-x:x}')
  if awk -v x="$ABS_DIFF" 'BEGIN{exit !(x>1)}'; then
    echo "[$(ts)] ❌ size diff >1% for $rel — ABORTING deletion of source, needs manual review" | tee -a "$LOG"
    continue
  fi

  rm -rf "$SRC"
  ln -s "$DST" "$SRC"
  FREED_GB=$(awk -v s="$SRC_SIZE" 'BEGIN{printf "%.1f", s/1024/1024/1024}')
  echo "[$(ts)] ✅ DONE $rel — verified, original removed, symlink created -> $DST (~${FREED_GB} GiB freed)" | tee -a "$LOG"
  df -h /mnt/ex_8T_SSD | tee -a "$LOG"
done

echo "[$(ts)] ALL_MIGRATIONS_DONE" | tee -a "$LOG"
