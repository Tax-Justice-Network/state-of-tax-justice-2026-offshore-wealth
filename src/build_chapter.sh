#!/bin/sh
# Rebuild the tables and figures of the offshore chapter (chapter 4 of the report) from the pipeline outputs.
# Run from the repository root after src/main.do. Output: output/chapter/
set -e
OUT=output/chapter
mkdir -p "$OUT/figures" "$OUT/blocs"
cp data/final/pairs_owner_centre_year_sotj2026.csv "$OUT/pairs_owner_centre_year.csv"
cp data/raw/chapter_inputs/fgmz_global_offshore_wealth_2001_2023.csv "$OUT/"
python3 src/helpers/us_owner_wealth_2014_2015.py data/raw/20261009_fgmz2025_owner_by_centre_unraked.csv \
    "$OUT/us_owner_wealth_by_centre_2014_2015.csv"
python3 src/helpers/results_tables_crs.py "$OUT/pairs_owner_centre_year.csv" data/raw/wb_countries_20261026.json "$OUT"
python3 src/helpers/figures_crs_results.py "$OUT" "$OUT/figures"
python3 src/helpers/figure_blocs_tax_loss.py output/tables/offshore_wealth_owned_sotj2026.csv \
    data/raw/chapter_inputs/bloc_members.csv data/raw/chapter_inputs/oecd_global_revenue_statistics_2016_2024.csv \
    "$OUT/blocs" 2023 pit
python3 src/helpers/table_a2_offshore.py "$OUT/pairs_owner_centre_year.csv" output/tables/offshore_wealth_owned_sotj2026.csv \
    output/tables/offshore_wealth_stored_sotj2026.csv "$OUT/table_a2_offshore_losses_2023.csv"
