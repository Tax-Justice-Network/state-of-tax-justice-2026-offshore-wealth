/*******************************************************************************
* main.do
*
* OFFSHORE WEALTH ANALYSIS - MASTER FILE
*
* Purpose: Run the complete offshore wealth analysis pipeline.
*          This file orchestrates all modules in sequence.
*
* Usage:   cd to src/ and run this file (do main.do). Paths: see 00_setup.do
*          (the repository's data/ and output/ folders).
*
* Modules:
*   00_setup.do                       - Configure paths and parameters
*   01_prepare_data.do                - Import and clean all data sources
*   03_fgmz_pairs.do                  - Owner x centre wealth from FGMZ (2025)
*   04_apply_crs.do                   - Exchange of information (CRS, FATCA):
*                                       reported, identified, taxed and untaxed
*                                       wealth, tax loss (coverage method)
*   05_generate_outputs.do            - Country, centre and global tables
*   06_bilateral_output.do            - Owner x centre pair file for the chapter
*
* Author: Tax Justice Network
* Last updated: October 2026
*******************************************************************************/

clear all
set more off

* Record start time
local start_time = c(current_time)
local start_date = c(current_date)

di as text ""
di as text "============================================================"
di as text "   OFFSHORE WEALTH ANALYSIS - TAX JUSTICE NETWORK"
di as text "   Started: `start_date' `start_time'"
di as text "============================================================"
di as text ""

/*------------------------------------------------------------------------------
* SET BASE PATH
*
* This should point to the directory containing all the .do files
------------------------------------------------------------------------------*/
* Run from the folder that holds this file (cd src, then do main.do; or
* stata-se -e do main.do in src/)
capture confirm file "`c(pwd)'/00_setup.do"
if _rc {
    di as error "Run main.do from the src/ folder of the repository (cd src, then do main.do)."
    exit 601
}
global base_path "`c(pwd)'"

/*------------------------------------------------------------------------------
* RUN MODULES IN SEQUENCE
------------------------------------------------------------------------------*/

di as text "Running 00_setup.do..."
do "$base_path/00_setup.do"

di as text "Running 01_prepare_data.do..."
do "$base_path/01_prepare_data.do"

di as text "Running 03_fgmz_pairs.do (owner x centre wealth from FGMZ 2025)..."
do "$base_path/03_fgmz_pairs.do"

di as text "Running 04_apply_crs.do..."
do "$base_path/04_apply_crs.do"

di as text "Running 05_generate_outputs.do..."
do "$base_path/05_generate_outputs.do"

di as text "Running 06_bilateral_output.do..."
do "$base_path/06_bilateral_output.do"

/*------------------------------------------------------------------------------
* COMPLETION SUMMARY
------------------------------------------------------------------------------*/
local end_time = c(current_time)
local end_date = c(current_date)

di as text ""
di as text "============================================================"
di as text "   ANALYSIS COMPLETE"
di as text "   Completed: `end_date' `end_time'"
di as text "============================================================"
di as text "   Key outputs (suffix $output_label):"
di as text "     - $tables/offshore_wealth_owned_$output_label.csv (by owner country)"
di as text "     - $tables/offshore_wealth_stored_$output_label.csv (by financial centre)"
di as text "     - $tables/global_by_year_$output_label.csv"
di as text "     - $data_final/pairs_owner_centre_year_$output_label.csv (USD bn, chapter figures)"
di as text "============================================================"
di as text ""
