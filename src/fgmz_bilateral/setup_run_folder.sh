#!/bin/bash
# Prepare a run folder for the FGMZ (2025) replication code, steps 03-07, plus the TJN
# owner-by-centre extension (8a). Nothing is written into the FGMZ package folder.
#
# Usage: setup_run_folder.sh <run_folder> <fgmz_package_folder> <bis_lbs_csv> <atlas_csv>
#   run_folder           new folder for code, intermediate data and outputs (needs ~10 GB)
#   fgmz_package_folder  local copy of the FGMZ replication package (its raw-data/ is used read-only)
#   bis_lbs_csv          BIS locational banking statistics bulk file WS_LBS_D_PUB_csv_col.csv
#   atlas_csv            FGMZ country file (Atlas of the Offshore World export), for the published totals
set -euo pipefail
RUN="$1"; PKG="$2"; BIS="$3"; ATLAS="$4"
COMMIT="4d9c2c6649dc2bc99edfddbf8961fb75e79b91d3"   # eutaxobservatory/global-offshore-wealth-2001-2023, 30 Sep 2026
HERE="$(cd "$(dirname "$0")" && pwd)"

mkdir -p "$RUN"/{code,raw-data,work-data,temp,figures/adjustments,tables,ado/plus,ado/personal}

# 1. FGMZ code at the pinned commit (GDP part of step 01, steps 03-07)
for f in 01-gravity-data-build/1b_import_gdp.do 03-uae-deposits/3-uae-deposits.do \
         04-bis-deposits-build/4a-import-bis.do 04-bis-deposits-build/4b-build-bis-01-23.do \
         06-swiss-fiduciary-build/6a-build-fiduciary.do \
         07-offshore-wealth-analysis/7a-build-offshore.do \
         07-offshore-wealth-analysis/7b-build-offshore_switzerland.do \
         07-offshore-wealth-analysis/7c-build-countries.do; do
  mkdir -p "$RUN/code/$(dirname "$f")"
  curl -sfL "https://raw.githubusercontent.com/eutaxobservatory/global-offshore-wealth-2001-2023/$COMMIT/code/$f" -o "$RUN/code/$f"
done
mkdir -p "$RUN/code/08-tjn-bilateral"
cp "$HERE/8a-owner-by-centre.do" "$RUN/code/08-tjn-bilateral/"

# 2. Portability patches (no analytical change):
#    Windows path separators -> "/" (Stata for Mac/Unix only accepts "/");
#    interactive data-browser commands (br/browse) commented out (not available in batch mode)
for f in "$RUN"/code/0[1-7]*/*.do; do
  sed -i.bak -E 's#\$(raw|work|temp|fig|tables|do)\\#$\1/#g; s#(\$fig/adjustments)\\#\1/#g; s#(\$raw/(dta|zucman|ewn|input))\\#\1/#g' "$f"
  sed -i.bak -E 's/^([[:space:]]*)(br|browse)([[:space:]]|$)/\1* [batch] \2\3/' "$f"
  rm -f "$f.bak"
done

# 3. Raw data: link the package's raw-data read-only, but copy the two files the code writes to
for e in "$PKG"/raw-data/*; do
  n="$(basename "$e")"
  case "$n" in
    "AJZ2017DataUpdated.xlsx"|"CDIS_12-11-2024 21-24-20-45_timeSeries_UAE_IOW_BP6_USD.dta") cp -p "$e" "$RUN/raw-data/$n" ;;
    *) ln -sfn "$e" "$RUN/raw-data/$n" ;;
  esac
done
mkdir -p "$RUN/raw-data/BIS_full_lbs_d_pub_csv"
ln -sfn "$BIS" "$RUN/raw-data/BIS_full_lbs_d_pub_csv/WS_LBS_D_PUB_csv_col.csv"

# 4. Stata driver files with this run folder's path
sed "s#__RUN__#$RUN#g" "$HERE/tjn_00_setup.do" > "$RUN/tjn_00_setup.do"
for f in tjn_01_prep.do tjn_02_run.do; do sed -e "s#__RUN__#$RUN#g" -e "s#__ATLAS__#$ATLAS#g" "$HERE/$f" > "$RUN/$f"; done
echo "Run folder ready: $RUN"
echo "Next: run tjn_01_prep.do, then tjn_02_run.do in Stata (batch: stata-se -e do <file>). The result is work-data/tjn_owner_by_centre.csv."
