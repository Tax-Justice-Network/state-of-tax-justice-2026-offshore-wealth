/*******************************************************************************
* 06_bilateral_output.do
*
* Purpose: Step 6 - the owner country x financial centre x year file read by the
*          table and figure scripts of the chapter (src/helpers/results_tables_crs.py,
*          src/helpers/figures_crs_results.py), in USD billions
*
* Inputs:  - $data_processed/offshore_wealth_panel_v2.dta
*
* Outputs: - $data_final/pairs_owner_centre_year_<label>.csv (USD billions)
*
* Author: Tax Justice Network
* Last updated: 20 October 2026
*******************************************************************************/

di as text ""
di as text "============================================================"
di as text "STEP 6: GENERATING BILATERAL OUTPUT"
di as text "============================================================"

local L "$output_label"

/*------------------------------------------------------------------------------
* 6.1 PAIR FILE FOR THE CHAPTER FIGURES AND TABLES (USD BILLIONS)
*
* Columns: o owner, j centre,
* W offshore wealth, cov reported, own owner-identified, taxed, untaxed,
* tax_loss (USD bn); share = owner's share of the centre's wealth; type =
* owner identification path; rate_*: Danish coverage (rate_B_c) and coverage
* x identified share by path (rate_A_k, rate_B_k); reason = why no report
* reaches the owner's authority; w_german = weight on the German identification
* path (0 = Danish). Note: crs_in_effect is the CRS flag (for US owners: the
* centre has implemented the CRS).
------------------------------------------------------------------------------*/
use "$data_processed/offshore_wealth_panel_v2.dta", clear

rename country_owner_iso3 o
rename country_stored_iso3 j
gen double W = offshore_wealth / 1000
gen double cov = covered / 1000
gen double own = owner_identified / 1000
replace taxed = taxed / 1000
replace untaxed = untaxed / 1000
replace tax_loss = tax_loss / 1000
rename owner_share_in_host share
rename owner_type type
gen double rate_A_k = coverage_dk * ident_A
gen double rate_B_k = coverage_dk * ident_B
gen double rate_B_c = coverage_dk
rename reason_no_exchange reason

keep year o j group W share crs_in_effect us_in_us_cell type cov own taxed untaxed ///
     top_pit_rate tax_loss rate_A_k rate_B_k rate_B_c reason w_german
order year o j group W share crs_in_effect us_in_us_cell type cov own taxed untaxed ///
      top_pit_rate tax_loss rate_A_k rate_B_k rate_B_c reason w_german
sort year o j
export delimited using "$data_final/pairs_owner_centre_year_`L'.csv", replace
di as text "  Pair file (USD bn): $data_final/pairs_owner_centre_year_`L'.csv"

di as text "============================================================"
di as text ""
