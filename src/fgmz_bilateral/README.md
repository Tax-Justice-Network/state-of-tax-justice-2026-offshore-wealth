# Owner × financial centre offshore wealth from the FGMZ (2025) code

Faye, Godar, Moura and Zucman (2025), *Global Offshore Wealth, 2001–2023*, publish two sets of figures. They give each owner country's offshore wealth split into four groups of financial centres (Switzerland; European, Asian and American centres), and they give the total held in each centre. Their code works centre by centre and only pools the centres at the end. The scripts here rerun their code and split each group across its centres, so that exchange of information can be modelled for each owner country and financial centre.

The pipeline uses the result, `data/raw/20261009_fgmz2025_owner_by_centre_unraked.csv`. Rebuilding it is optional. The values for single owner–centre pairs are an allocation built on FGMZ's data and assumptions. They are not estimates published by FGMZ, and they are less precise than the country and centre totals.

## What the scripts do

1. Rerun FGMZ's steps 03–07 unchanged, plus the GDP part of step 01, at commit `4d9c2c6` (30 September 2026) of [eutaxobservatory/global-offshore-wealth-2001-2023](https://github.com/eutaxobservatory/global-offshore-wealth-2001-2023). The global portfolio gap (steps 01–02) is taken from the published totals.
2. `8a-owner-by-centre.do` computes each owner's share of each centre's household-adjusted non-bank deposits. It applies FGMZ's redistribution of haven and shell-company deposits (their formula 7a) centre by centre, smooths the shares with FGMZ's five-year weights and allocates the published centre total. Switzerland comes directly from FGMZ (SNB fiduciary deposits). It writes the result to `work-data/tjn_owner_by_centre.csv`, the file shipped as `data/raw/20261009_fgmz2025_owner_by_centre_unraked.csv`.

## Running it

You need the FGMZ replication package, the full BIS bulk download `WS_LBS_D_PUB_csv_col.csv` and Stata 17 or later. A run takes about 10 minutes and about 10 GB of disk space.

```sh
src/fgmz_bilateral/setup_run_folder.sh <run_folder> <FGMZ package folder> <BIS WS_LBS_D_PUB_csv_col.csv> data/raw/20261006_atlas_offshore_wealth_FGMZ2025.csv
cd <run_folder>
stata-se -e do tjn_01_prep.do      # published global gap
stata-se -e do tjn_02_run.do       # FGMZ steps, then 8a
```

The setup script applies two patches to FGMZ's code so that it runs in batch mode on any system. Neither changes the analysis:
- Windows path separators are converted to `/`.
- The interactive `browse` commands are commented out.

Stata add-ons (`isocodes`, `fastreshape`, `mmerge`, `carryforward`, `gtools`, `wbopendata`) are installed into the run folder, not into your Stata. Step 05 (IMF direct-investment data) is skipped: it only feeds FGMZ's FDI-adjusted Swiss variant, not the published benchmark.
