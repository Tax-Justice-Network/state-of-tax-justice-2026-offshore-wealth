/*******************************************************************************
* 00_setup.do
*
* Purpose: Configure paths, parameters, and global settings for offshore wealth
*          analysis. This file must be run first before any other modules.
*
* Author: Tax Justice Network
* Last updated: October 2026
*******************************************************************************/

clear all
set more off

* Store new numeric variables as doubles: the data hold USD values around 1e12,
* for which Stata's default float (7 significant digits) loses precision.
set type double

/*------------------------------------------------------------------------------
* SECTION 1: PATH CONFIGURATION
*
* Run main.do from the src/ folder of the repository; the repository root is
* the folder above it. Inputs are read from data/raw; intermediate files go to
* data/processed and data/final, tables and figures to output/tables and
* output/figures.
------------------------------------------------------------------------------*/

global root_github = subinstr("`c(pwd)'", "\", "/", .)
if substr("$root_github", -4, .) == "/src" global root_github = substr("$root_github", 1, length("$root_github") - 4)
global code_github "$root_github/src"
mata: st_local("repo_data", strofreal(direxists(st_global("root_github") + "/data/raw")))


* Derived paths (do not edit). Forward slashes work on all platforms in Stata.
if `repo_data' == 1 {
    global data "$root_github/data"
    global data_raw "$data/raw"
    global data_processed "$data/processed"
    global data_final "$data/final"
    global tables "$root_github/output/tables"
    foreach d in "$data_processed" "$data_final" "$root_github/output" "$tables" {
        capture mkdir "`d'"
    }
}
else {
    di as error "Input data not found: put the input files in $root_github/data/raw (see data/raw/README.md)."
    exit 601
}

/*------------------------------------------------------------------------------
* SECTION 2: DATA VERSION SETTINGS
------------------------------------------------------------------------------*/

* Date stamp for this analysis run (format: YYYYMMDD)
global today "20261020"

* BIS data file date (download of WS_LBS_D_PUB_csv_col.csv in $data_raw)
global bis_data_date "20260218"

* BIS locational banking statistics: the full bulk download (about 540 MB) or,
* where only that is available, the extract of the rows step 01 uses (shipped
* with the public repository; same rows, same columns)
global bis_file "WS_LBS_D_PUB_csv_col.csv"
capture confirm file "$data_raw/$bis_file"
if _rc global bis_file "bis_lbs_extract_$bis_data_date.csv"

* Re-download World Bank GDP/population data (1) or use the cached file in
* $data_processed if it exists (0). The download needs internet access and
* the user-written command wbopendata.
global wb_refresh 0

* The World Bank download behind the published results (shipped with the
* public repository in $data_raw; used as the cache when none exists)
global wb_frozen_file "wb_gdp_population_incomelevel_20260218.dta"

* World Bank income groups and regions (download of 20 Oct 2026; one
* classification for the pipeline and the chapter tables; overrides the income
* level in the cached WDI download)
global wb_classification_file "20261020_world_bank_country_classification.csv"

* Researched top personal income tax rates (EY Worldwide Personal Tax and
* Immigration Guide editions, official sources, other dated guides): they fill
* the years the KPMG table does not cover (from 2021), the owner countries
* neither OECD nor KPMG covers, and KPMG values found wrong. Sources by
* country and year in the file.
global pit_research_file "20261021_top_pit_rates_researched.csv"

/*------------------------------------------------------------------------------
* SECTION 3: ANALYSIS PARAMETERS
------------------------------------------------------------------------------*/

* Annual GDP growth assumed when extrapolating missing GDP from the previous year
global gdp_growth_fill 0.03

/*------------------------------------------------------------------------------
* SECTION 4: YEAR RANGE
*
* Define the years to include in the panel analysis.
* For testing, set both to the same year (e.g., 2021) for a quick run.
------------------------------------------------------------------------------*/

* Full analysis (all years)
global year_start 2016
global year_end 2023

* Suffix of all output files in $tables and $data_final (e.g.
* offshore_wealth_owned_sotj2026.csv)
global output_label "sotj2026"

* Uncomment below for quick test run (single year)
* global year_start 2021
* global year_end 2021

/*------------------------------------------------------------------------------
* SECTION 5: GLOBAL OFFSHORE WEALTH AND ITS ALLOCATION
*
* The most recent offshore wealth series of the EU Tax Observatory: Faye,
* Godar, Moura and Zucman (2025), "Global Offshore Wealth, 2001-2023", EUTO
* Working Paper No. 41 (December 2025). USD billion totals by owner country
* from the Atlas of the Offshore World, file $euto_file in $data_raw; 01 sums
* them by year (2021: USD 13,083bn, 13.3% of world GDP).
------------------------------------------------------------------------------*/

global euto_file "20261006_atlas_offshore_wealth_FGMZ2025.csv"

* Owner x financial-centre table derived from FGMZ's replication code
* (src/fgmz_bilateral, see its README): FGMZ's method applied centre by centre
* on current public BIS data, with FGMZ's global and centre totals.
global fgmz_pairs_file "20261009_fgmz2025_owner_by_centre_unraked.csv"

/*------------------------------------------------------------------------------
* SECTION 6: AUTOMATIC EXCHANGE OF INFORMATION (CRS AND FATCA): COVERAGE METHOD
*
* For every owner-centre-year
* the untaxed part of offshore wealth is W minus the part that is reported to
* the owner's tax authority with an identified owner and taxed, minus a small
* declared share. Three steps (04_apply_crs.do):
*   1. Is information exchanged? A pair is on from the first calendar year
*      whose account data the centre actually sent to the owner's authority
*      ($crs_activation_file: senders' partner lists, OECD register, Global
*      Forum clearances), with non-reciprocal periods and suspensions.
*      US owners are covered through FATCA in every centre. Wealth booked in
*      the US is covered only for the reciprocal FATCA partners in
*      $fatca_partners_file, own-name accounts only.
*   2. How much is reported? Denmark's coverage of FGMZ wealth in CRS centres
*      ($crs_anchors_file: 2019 and 2022, interpolated; 2016-18 scaled by the
*      Danish banks' reporting path), scaled for the centre's share of wealth
*      held through self-reporting structures (s, $crs_s_file) and their
*      non-reporting rate (r, $crs_r_file) relative to Denmark's own s x r,
*      and capped at 1 - s x r.
*   3. Which part can be matched to a taxpayer? Owner-identified share between
*      the Danish path (own name + Denmark's owner-coded share of shell-company
*      accounts) and the German path (German own-name share), by the owner's
*      position: from its own CRS statistics where published
*      ($crs_owner_position_file), otherwise from the household share of its
*      BIS cross-border deposits ($owner_type_rule). Of identified wealth, the
*      BJKLZ share that stays unreported and is not found in audits remains
*      untaxed.
------------------------------------------------------------------------------*/

* Input files in $data_raw
global crs_activation_file "20261015_crs_sender_partner_years.csv"
global crs_anchors_file "20261020_crs_coverage_anchors.csv"
global crs_s_file "20261020_crs_structure_share_by_centre.csv"
global crs_r_file "20261020_crs_structure_nonreporting_by_centre_year.csv"
global fatca_partners_file "20261116_fatca_reciprocal_partners.csv"
global crs_owner_position_file "20261021_crs_owner_position_measured.csv"

* Column of $crs_s_file to use for the structure share (s_low, s_central, s_high)
global crs_s_column "s_central"

* Danish coverage anchors: years with measured coverage (Report No. 7, 2019
* and 2022 accounts); years in between are interpolated, later years keep the
* last value
global crs_anchor_year1 2019
global crs_anchor_year2 2022

* Danish banks' reporting path before the first anchor year (BJKLZ 2026):
* share of accounts reported in 2016, 2017, 2018 against the 2019 level.
* Coverage in those years = anchor-year coverage x min(1, path / path_2019).
global bjklz_report_2016 26
global bjklz_report_2017 75
global bjklz_report_2018 87
global bjklz_report_2019 83

* Owner type for the binary rules: Danish identification shares if the
* household share of the owner's BIS cross-border deposits (households /
* (households + non-financial corporations), BIS LBS liabilities of all
* reporting banks, Q4) is below this threshold; German shares otherwise (and
* when no BIS data exist)
global owner_type_hh_threshold 0.10

* How owners are placed between the Danish (0) and the German (1)
* identification path. h = households' share of the owner's cross-border
* deposits (BIS), h_avg its average over $year_start-$year_end, h_DK and h_DE
* Denmark's and Germany's h_avg (8.2% and 36.7%).
*   "measured_fitted"    - default.
*                          Owners with their own CRS statistics
*                          ($crs_owner_position_file: Denmark, Germany, UK,
*                          Norway, Finland, Japan, Slovenia, South Africa) get
*                          their measured position. All others: a straight
*                          line in h_avg that starts at Denmark (0 at h_DK),
*                          with the slope fitted by least squares to the
*                          measured owners below the German end (Norway,
*                          Finland), capped at 1 (reached at h_avg = 11.4%).
*                          Owners with Denmark's h_avg are placed like Denmark.
*   "measured_line"      - measured positions; others on the straight line
*                          from h_DK (0) to h_DE (1), clamped to [0, 1]
*   "continuous_average" - all owners on the straight line from h_DK to h_DE
*   "binary_yearly"      - Danish if h < $owner_type_hh_threshold in that year,
*                          else German (owners near the threshold switch
*                          path from year to year)
*   "binary_average"     - the same test on h_avg (one path per owner)
* Owners without BIS data get the German path.
global owner_type_rule "measured_fitted"

* Of the wealth reported with an identified owner, the part that stays
* unreported by the owner and is not found in audits remains untaxed.
* BJKLZ (2026), Table 5, Denmark: DKK 53.1bn matched, 3.6bn still unreported,
* of which 1.0bn detected in audits -> (3.6 - 1.0) / 53.1 = 4.9% untaxed
global bjklz_matched_dkk_bn 53.1
global bjklz_unreported_dkk_bn 3.6
global bjklz_audited_dkk_bn 1.0

* Share of offshore wealth declared without any exchange of information
* (pre-CRS evidence: 90-95% undeclared; midpoint of the 5-10% band). Enters as
* a floor on taxed wealth per owner and year that the
* CRS coverage absorbs: taxed = max(CRS-taxed, d x W), the top-up spread over
* the owner's centres in proportion to untaxed wealth.
global pre_crs_declared_share 0.075

* US residents' wealth abroad: FATCA coverage of 100% in every centre from the
* start of the sample (all FGMZ centres have FATCA agreements; reporting since
* 2014), before the self-reporting-structure ceiling, with owner identification
* as for the owner's type
global us_fatca_owner_coverage 1

* Owner x centre tables fitted to FGMZ's published owner figures contain a cell
* "US residents' wealth held in the US"; the table used here has none. If such a
* cell is present and this is 1, it counts as covered by US domestic information
* reporting (own-name accounts, owner identified)
global us_in_us_covered 1

* Assumed rate of return on offshore wealth (Zucman methodology)
global offshore_return_rate 0.05

/*------------------------------------------------------------------------------
* SECTION 7: DISPLAY CONFIGURATION SUMMARY
------------------------------------------------------------------------------*/

di as text ""
di as text "============================================================"
di as text "OFFSHORE WEALTH ANALYSIS - CONFIGURATION LOADED"
di as text "============================================================"
di as text "Analysis date stamp: $today"
di as text "BIS data date: $bis_data_date"
di as text "Year range: $year_start - $year_end"
di as text "Owner x centre table: $fgmz_pairs_file"
di as text "CRS method: coverage (activation table $crs_activation_file)"
di as text "Pre-CRS declared share: $pre_crs_declared_share"
di as text "------------------------------------------------------------"
di as text "Paths configured:"
di as text "  GitHub root: $root_github"
di as text "  Data folder: $data"
di as text "  Raw data: $data_raw"
di as text "  Processed data: $data_processed"
di as text "  Final data: $data_final"
di as text "  Output tables: $tables"
di as text "============================================================"
di as text ""
