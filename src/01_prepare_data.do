/*******************************************************************************
* 01_prepare_data.do
*
* Purpose: Import and prepare all input data sources for offshore wealth analysis.
*          Creates intermediate .dta files for use by subsequent modules.
*
* Inputs:  - BIS locational banking statistics, bilateral ($bis_file)
*          - World Bank WDI (GDP, GDP per capita, population, income level)
*          - Personal income tax rates (OECD, KPMG)
*          - CRS implementation years (OECD)
*          - CRS coverage inputs (00_setup.do, Section 6): Danish coverage
*            anchors, self-reporting structure shares and non-reporting rates,
*            FATCA reciprocal partners, directed CRS activation table
*
* Outputs: - $data_processed/bis_bilateral.dta
*          - $data_processed/bis_household_share.dta
*          - $data_processed/total deposits to merge.dta
*          - $data_processed/bis_reporting.dta
*          - $data_processed/gdp_population_incomelevel.dta
*          - $data_processed/top_pit_rates.dta
*          - $data_processed/crs_coverage_anchors.dta
*          - $data_processed/crs_structure_s.dta, crs_structure_r.dta
*          - $data_processed/fatca_partners.dta
*          - $data_processed/crs_pair_activation.dta, crs_receiver_info.dta
*          - $data_processed/crs_implementation_year.dta
*          - $data_processed/1_deposits.dta
*          - $data_processed/2_deposits_secrecy.dta
*          - $data_processed/counterparty_details.dta
*          - $data_processed/host_details.dta
*
* Author: Tax Justice Network
* Last updated: 20 October 2026
*******************************************************************************/

di as text ""
di as text "============================================================"
di as text "STEP 1: PREPARING DATA"
di as text "============================================================"

/*------------------------------------------------------------------------------
* 1.1 IMPORT BIS BILATERAL BANKING DATA & BUILD COUNTRY BANKING-POSITION PROXY
*
* Series kept: stocks (S), all instruments (A), all currencies (TO1), all
* reporting banks (A), all parent countries (5J), counterparty sector non-banks
* (N), cross-border positions (N). Values are in USD millions.
* The sector and instrument filters are independent: N selects non-bank
* counterparties; A includes loans/deposits, debt securities and other bank
* balance-sheet instruments. Loans/deposits alone would be instrument G.
* Securities held purely in custody for customers are outside bank positions.
------------------------------------------------------------------------------*/
di as text "  Importing BIS bilateral data..."

import delimited using "$data_raw/$bis_file", clear

* Owner type for the CRS coverage rule (04): share of a country's cross-border
* deposits held by households, H / (H + C), from the liabilities of all BIS
* reporting banks (5A) to households (H) and non-financial corporations (C) of
* the counterparty country, all instruments, end of year
preserve
    keep if l_measure == "S" & l_position == "L" & l_instr == "A" & ///
            l_denom == "TO1" & l_curr_type == "A" & l_pos_type == "N" & ///
            l_rep_bank_type == "A" & l_parent_cty == "5J" & l_rep_cty == "5A" & ///
            inlist(l_cp_sector, "H", "C") & regexm(l_cp_country, "^[A-Z][A-Z]$")
    local kv l_cp_sector l_cp_country
    ds v*
    foreach v of varlist `r(varlist)' {
        local lab : variable label `v'
        local lab = strtrim(`"`lab'"')
        if regexm(`"`lab'"', "^([0-9][0-9][0-9][0-9])-Q4$") {
            local yr = regexs(1)
            rename `v' amt`yr'
            local kv `kv' amt`yr'
        }
    }
    keep `kv'
    reshape long amt, i(l_cp_sector l_cp_country) j(year)
    reshape wide amt, i(l_cp_country year) j(l_cp_sector) string
    gen double hshare = amtH / (amtH + amtC) if amtH != . & amtC != . & amtH + amtC > 0
    rename l_cp_country country_iso2
    rename amtH dep_households
    rename amtC dep_nonfin_corp
    keep country_iso2 year hshare dep_households dep_nonfin_corp
    label variable hshare "Households' share of cross-border deposits, H / (H + C), BIS LBS"
    label variable dep_households "BIS reporting banks' liabilities to the country's households (USD m)"
    label variable dep_nonfin_corp "BIS reporting banks' liabilities to the country's non-financial corporations (USD m)"
    save "$data_processed/bis_household_share.dta", replace
restore

keep if l_measure == "S" & l_instr == "A" & l_denom == "TO1" & ///
        l_curr_type == "A" & l_cp_sector == "N" & ///
        l_pos_type == "N" & l_rep_bank_type == "A" & l_parent_cty == "5J"

* Keep only individual reporting countries and individual counterparty
* countries (two-letter ISO codes). The file also contains BIS aggregates such
* as "5A" (all reporting countries) as reporters and e.g. "5J" (all countries)
* as counterparties. Summing these together with the individual countries
* double counts every position.
keep if regexm(l_rep_cty, "^[A-Z][A-Z]$") & regexm(l_cp_country, "^[A-Z][A-Z]$")

* All values are in million USD -> convert to USD
foreach var of varlist v* {
    replace `var' = `var' * 1e6
}

* Keep end-of-year (Q4) observations only
local keepvars l_rep_cty l_cp_country l_position
ds
foreach v of varlist `r(varlist)' {
    local lab : variable label `v'
    if strpos("`lab'", "Q4") {
        local keepvars `keepvars' `v'
    }
}

keep `keepvars'
rename l_rep_cty country_iso2
rename l_cp_country counterpart_country_iso2

ds v*
foreach v of varlist `r(varlist)' {
    local lab : variable label `v'
    local lab = strtrim(`"`lab'"')

    if regexm(`"`lab'"', "^([0-9][0-9][0-9][0-9])") {
        local yr  = regexs(1)
        local new = "nonbank`yr'"

        cap confirm new variable `new'
        if _rc==0 rename `v' `new'
        else di as error "SKIP: target `new' already exists"
    }
}

keep country_iso2 counterpart_country_iso2 l_position nonbank*
reshape wide nonbank*, i(country_iso2 counterpart_country_iso2) j(l_position) string

rename nonbank*L liabilities_nonbank*
rename nonbank*C claims_nonbank*

reshape long claims_nonbank liabilities_nonbank, i(country_iso2 counterpart_country_iso2) j(year)

* Variable meaning (reporter = country_iso2, counterparty = counterpart_country_iso2):
*   claims_nonbank      - claims of banks in the reporting country on non-banks
*                         in the counterparty country, across all instruments
*   liabilities_nonbank - liabilities of banks in the reporting country to
*                         non-banks in the counterparty country, across all
*                         instruments (deposits and other bank liabilities)
label variable claims_nonbank "All-instrument bank claims on counterparty non-banks (USD)"
label variable liabilities_nonbank "All-instrument bank liabilities to counterparty non-banks (USD)"

* Create derived liabilities and claims from the mirror position (kept for
* reference; the analysis uses reported liabilities only)
preserve
    keep country_iso2 counterpart_country_iso2 year claims_nonbank liabilities_nonbank

    rename country_iso2            reporter_iso2
    rename counterpart_country_iso2 partner_iso2

    * Swap sides (A,B) -> (B,A)
    rename reporter_iso2  counterpart_country_iso2
    rename partner_iso2   country_iso2

    * Claims(A in B) become derived liabilities(B on A)
    rename claims_nonbank dliabilities_nonbank

    * Liabilities(A vis-a-vis B) become derived claims(B on A)
    rename liabilities_nonbank dclaims_nonbank

    tempfile derived
    save `derived', replace
restore

merge 1:1 country_iso2 counterpart_country_iso2 year using `derived', nogen

save "$data_processed/bis_bilateral.dta", replace

di as text "  Calculating total inward deposits..."

* Historical variable name tot_inward_dep: sum over individual BIS reporters
* of their banks' all-instrument claims on the country's non-banks. This is a
* banking-position proxy, not a measure of customer deposits or custody
* portfolios. Missing when no reporting country provides a value.
keep if claims_nonbank != .
bys counterpart_country_iso2 year: egen tot_inward_dep = total(claims_nonbank)
bys counterpart_country_iso2 year: egen n_reporters = count(claims_nonbank)

* Keep one observation per country-year
duplicates drop counterpart_country_iso2 year, force
keep counterpart_country_iso2 year tot_inward_dep n_reporters
rename counterpart_country_iso2 country_iso2
label variable tot_inward_dep "Foreign reporting banks' claims on country's non-banks (USD)"
label variable n_reporters "Number of BIS reporting countries with data on this country"
save "$data_processed/total deposits to merge.dta", replace

/*------------------------------------------------------------------------------
* 1.2 IDENTIFY BIS REPORTING COUNTRIES
*
* Create a flag for countries that report bilateral positions to the BIS.
* This is used later to assess data coverage.
------------------------------------------------------------------------------*/
di as text "  Identifying BIS reporting countries..."
use "$data_processed/bis_bilateral.dta", clear
keep country_iso2 counterpart_country_iso2 year claims_nonbank
keep if claims_nonbank != .
duplicates drop country_iso2, force
keep country_iso2
gen bis_reporting = "Yes"
label variable bis_reporting "BIS reporting"
save "$data_processed/bis_reporting.dta", replace

/*------------------------------------------------------------------------------
* 1.3 IMPORT GDP, POPULATION, AND INCOME LEVEL FROM WORLD BANK (WDI API)
*     Output: long country-year panel with GDP, GDP per capita, population,
*             and World Bank income level classification.
*     The download is skipped when a cached file exists and $wb_refresh == 0.
------------------------------------------------------------------------------*/
capture confirm file "$data_processed/gdp_population_incomelevel.dta"
local wb_cached = (_rc == 0)
* Without a cache, the download behind the published results serves as one
if `wb_cached' == 0 {
    capture confirm file "$data_raw/$wb_frozen_file"
    if _rc == 0 {
        copy "$data_raw/$wb_frozen_file" "$data_processed/gdp_population_incomelevel.dta"
        local wb_cached 1
    }
}

if $wb_refresh == 1 | `wb_cached' == 0 {
    di as text "  Downloading GDP, GDP per capita, population, and income level from World Bank (WDI API)..."

    cap which wbopendata
    if _rc ssc install wbopendata, replace

    * NOTE: multiple indicators must be separated by ';'
    wbopendata, indicator(NY.GDP.MKTP.CD;NY.GDP.PCAP.CD;SP.POP.TOTL) clear

    * Keep only what we need
    keep countrycode countryname incomelevel incomelevelname indicatorcode yr*

    * --- Save country-level metadata (unique by countrycode) ---
    preserve
        keep countrycode countryname incomelevel incomelevelname
        duplicates drop countrycode, force
        tempfile wbmeta
        save `wbmeta'
    restore

    * --- Reshape years wide -> long (countrycode x indicatorcode x year) ---
    reshape long yr, i(countrycode indicatorcode) j(year)
    rename yr value

    * Make indicator codes Stata-name-safe
    gen indicator_safe = subinstr(indicatorcode, ".", "_", .)

    * Drop metadata before reshaping wide (avoids r(9))
    drop countryname incomelevel incomelevelname indicatorcode

    * --- Reshape indicators -> wide (countrycode x year) ---
    reshape wide value, i(countrycode year) j(indicator_safe) string

    rename valueNY_GDP_MKTP_CD gdp
    rename valueNY_GDP_PCAP_CD gdp_pc
    rename valueSP_POP_TOTL    population

    * Merge income group back in
    merge m:1 countrycode using `wbmeta', nogen

    * Standardize identifier
    rename countrycode country_iso3

    * Final structure
    keep country_iso3 year gdp gdp_pc population incomelevel incomelevelname
    order country_iso3 year gdp gdp_pc population incomelevel incomelevelname

    save "$data_processed/gdp_population_incomelevel.dta", replace
}
else {
    di as text "  Using cached World Bank data: $data_processed/gdp_population_incomelevel.dta"
}

/*------------------------------------------------------------------------------
* 1.5 IMPORT PERSONAL INCOME TAX RATES
*
* Top statutory personal income tax rates: OECD where available, otherwise the
* researched rates, otherwise KPMG (2016-2020); missing years are filled with
* the latest earlier value.
------------------------------------------------------------------------------*/
di as text "  Importing tax rate data..."

* ------------------------------------------------------------
* OECD top PIT rates (MANUAL DOWNLOAD in raw folder)
* ------------------------------------------------------------
di as text "    - OECD top PIT rates (manual CSV)..."

import delimited using "$data_raw/OECD.CTP.TPS,DSD_TAX_PIT@DF_PIT_TOP_EARN_THRESH,1.0+all.csv", ///
    clear varnames(1) encoding(UTF-8) bindquotes(strict)

keep if measure == "TS_PIT"

* Standardize identifiers + keep country-year panel
rename ref_area country_iso3
rename time_period year
rename obs_value top_pit_rate

* Ensure numeric year and rate
destring year, replace force
destring top_pit_rate, replace force

keep country_iso3 year top_pit_rate

gen pit_rate_oecd = top_pit_rate / 100
drop top_pit_rate

save "$data_processed/pit_rate_oecd.dta", replace

* ------------------------------------------------------------
* KPMG PIT rates (panel format)
* ------------------------------------------------------------
import delimited using "$data_raw/pit_rate_kpmg.csv", clear
rename country c_x
run "$code_github/helpers/Harmonizing country names.do"
drop c_x

gen pit_rate_kpmg = top_individual_income / 100
drop top_individual_income
save "$data_processed/pit_rate_kpmg.dta", replace

* ------------------------------------------------------------
* Researched top PIT rates ($pit_research_file)
* ------------------------------------------------------------
import delimited using "$data_raw/$pit_research_file", clear varnames(1) ///
    stringcols(1) bindquote(strict) maxquotedrows(unlimited)
keep country_iso3 year pit_rate_research source source_url confidence
rename source source_research
rename source_url url_research
rename confidence confidence_research
isid country_iso3 year
save "$data_processed/pit_rate_research.dta", replace

* Build country-year panel of top PIT rates
use "$data_raw/country_iso_tjn.dta", clear
keep country_iso3 country country_iso2
replace country_iso3 = "XKX" if inlist(country_iso3, "KSV", "XKV")
* Add owners with researched rates that TJN's country list lacks (the US Minor
* Outlying Islands, an owner in the FGMZ table), so that they do not fall
* through to the global average in 04_apply_crs.do
preserve
    use "$data_processed/pit_rate_research.dta", clear
    keep country_iso3
    duplicates drop
    tempfile rescodes
    save `rescodes'
restore
merge 1:1 country_iso3 using `rescodes', nogen
replace country = country_iso3 if country == ""
local T = $year_end - $year_start + 1
assert `T' > 0

expand `T'
bysort country_iso3: gen year = $year_start + _n - 1

order country_iso3 year
sort country_iso3 year

merge 1:1 country_iso3 year using "$data_processed/pit_rate_oecd.dta", ///
          nogen keep(master match)
merge 1:1 country year using "$data_processed/pit_rate_kpmg.dta", ///
          nogen keep(master match)
merge 1:1 country_iso3 year using "$data_processed/pit_rate_research.dta", ///
          nogen keep(master match)

rename source source_top_pit_rate

* Order: OECD, researched rates, KPMG (2016-2020), then the manual values and
* carry-forward below; owners still without a rate get the income-group
* average in 04_apply_crs.do (last resort)
gen top_pit_rate = pit_rate_oecd
replace source_top_pit_rate = "OECD" if pit_rate_oecd != .
replace source_url = "https://data-explorer.oecd.org" if pit_rate_oecd != .
replace source_top_pit_rate = source_research if top_pit_rate == . & pit_rate_research != .
replace source_url = url_research if top_pit_rate == . & pit_rate_research != .
replace top_pit_rate = pit_rate_research if top_pit_rate == . & pit_rate_research != .
replace top_pit_rate = pit_rate_kpmg if top_pit_rate == .

* Fill in jurisdictions missing from both sources with known values (applied
* to the panel, so they take effect even when the jurisdiction has no row in
* the KPMG file)
local manual_pit `" "British Virgin Islands" 0 "Monaco" 0 "Cook Islands" 0.30 "Andorra" 0.10 "Liechtenstein" 0.224 "Marshall Islands" 0.12 "'
local n : word count `manual_pit'
forvalues i = 1(2)`n' {
    local c : word `i' of `manual_pit'
    local r : word `=`i'+1' of `manual_pit'
    replace source_top_pit_rate = "Manual search" if country == "`c'" & top_pit_rate == .
    replace top_pit_rate = `r' if country == "`c'" & top_pit_rate == .
}

* Carry the latest available earlier value forward (sequential replace fills
* chains of missing years)
sort country_iso3 year
order country_iso3 country year top_pit_rate source_top_pit_rate source_url confidence_research
bysort country_iso3: replace source_top_pit_rate = "Year before" if top_pit_rate[_n-1] != . & top_pit_rate == .
bysort country_iso3: replace top_pit_rate = top_pit_rate[_n-1] if top_pit_rate == .
replace source_top_pit_rate = "Earlier years" if source_top_pit_rate == "" & top_pit_rate != .
label variable top_pit_rate "Top statutory personal income tax rate (share)"
save "$data_processed/top_pit_rates.dta", replace

/*------------------------------------------------------------------------------
* 1.6 IMPORT CRS COVERAGE INPUTS
*
* See 00_setup.do, Section 6.
------------------------------------------------------------------------------*/
di as text "  Importing CRS coverage inputs..."

* ---- 1.6a Danish coverage anchors and identification shares by year ----------
import delimited using "$data_raw/$crs_anchors_file", clear varnames(1) asdouble
rename dk_reports_dkk_bn dk_reports
rename dk_wealth_dkk_bn dk_wealth
rename dk_identified_share ident_A
rename dk_ownname_share ownname_A
rename de_identified_share ident_B
rename de_ownname_share ownname_B
assert year == $crs_anchor_year1 | year == $crs_anchor_year2 if dk_reports != .
gen double coverage_dk = dk_reports / dk_wealth
tempfile anchors
save `anchors'

clear
local T = $year_end - $year_start + 1
set obs `T'
gen year = $year_start + _n - 1
merge 1:1 year using `anchors', nogen keep(master match)
sort year

* Coverage: measured in the anchor years, linear in between, constant after
* the last anchor, and before the first anchor scaled by the Danish banks'
* reporting path (BJKLZ 2026) relative to the first anchor year
assert $year_start >= 2016
local y1 = $crs_anchor_year1
local y2 = $crs_anchor_year2
sum coverage_dk if year == `y1', meanonly
local c1 = r(mean)
sum coverage_dk if year == `y2', meanonly
local c2 = r(mean)
replace coverage_dk = `c1' + (`c2' - `c1') * (year - `y1') / (`y2' - `y1') if year > `y1' & year < `y2'
replace coverage_dk = `c2' if year > `y2'
forvalues y = 2016/2018 {
    replace coverage_dk = `c1' * min(1, ${bjklz_report_`y'} / $bjklz_report_2019) if year == `y'
}
assert coverage_dk != .

* Identification shares: first available value before the first data year,
* last available value after the last one
foreach v in ident_A ownname_A ident_B ownname_B {
    gsort -year
    replace `v' = `v'[_n-1] if `v' == . & _n > 1
    sort year
    replace `v' = `v'[_n-1] if `v' == . & _n > 1
    assert `v' != .
}
* German path: Germany publishes no share of passive-entity (shell-company)
* wealth whose report names the owner, so the German path uses Denmark's value
* of the same year (39% to 2019, 32% 2020, 28% 2021, 26% from 2022):
* identified = own name + Denmark's share x (1 - own name). The file's
* de_identified_share column is not used.
gen double shell_owner_share = (ident_A - ownname_A) / (1 - ownname_A)
replace ident_B = ownname_B + shell_owner_share * (1 - ownname_B)
assert ident_B >= ownname_B & ident_B <= 1

keep year coverage_dk ident_A ownname_A ident_B ownname_B shell_owner_share
label variable coverage_dk "Denmark: CRS-reported share of FGMZ offshore wealth in reporting centres"
label variable ident_A "Owner-identified share of reported wealth, Danish path (own name + shell accounts naming the owner)"
label variable shell_owner_share "Denmark: share of passive-entity wealth whose report names the owner (both paths)"
label variable ownname_A "Own-name share of reported wealth, Danish path"
label variable ident_B "Owner-identified share of reported wealth, German path (own name + Danish shell share)"
label variable ownname_B "Own-name share of reported wealth, German path"
save "$data_processed/crs_coverage_anchors.dta", replace

* ---- 1.6b Self-reporting structures: share s by centre, non-reporting r ----
import delimited using "$data_raw/$crs_s_file", clear varnames(1) asdouble stringcols(1 2)
keep centre_iso3 $crs_s_column
rename $crs_s_column s
isid centre_iso3
label variable s "Share of the centre's offshore wealth held through self-reporting structures"
save "$data_processed/crs_structure_s.dta", replace

import delimited using "$data_raw/$crs_r_file", clear varnames(1) asdouble stringcols(1)
isid centre_iso3 year
label variable r "Non-reporting rate of self-reporting structures, by booking centre and year"
save "$data_processed/crs_structure_r.dta", replace

* ---- 1.6c FATCA reciprocal partners (owners that receive from the US) --------
import delimited using "$data_raw/$fatca_partners_file", clear varnames(1) stringcols(1)
isid iso3
rename first_data_year fatca_first_year
label variable fatca_first_year "First calendar year of account data received from the US under FATCA"
save "$data_processed/fatca_partners.dta", replace

* ---- 1.6d Directed, dated CRS activation table ------------------------------
import delimited using "$data_raw/$crs_activation_file", clear varnames(1) ///
    stringcols(_all) bindquote(strict) maxquotedrows(unlimited)
destring first_reportable_year, replace force
isid sender_iso3 receiver_iso3

* Data years without exchange named in the status:
*   "non-reciprocal for 2018-2021 data"   -> off 2018-2021
*   "(2020-2021 data not received)"       -> off 2020-2021
*   "(2021 data not received)"            -> off 2021
*   "(2022 data was the last received)"   -> off from 2023
*   "reciprocal 2016-2019 data (DAC2)" names years WITH exchange under the EU
*   directive: a non-reciprocal period under the MCAA starts only after them
*   ("non-reciprocal under MCAA until YYYY" -> off from the year after the DAC2
*   years to YYYY - 1)
* ("non-reciprocal-period-until-YYYY" is already reflected in
* first_reportable_year)
gen off_from = .
gen off_to = .
local yy "([0-9][0-9][0-9][0-9])"
replace off_from = real(regexs(1)) if regexm(status, "non-reciprocal for `yy'-`yy' data")
replace off_to   = real(regexs(2)) if regexm(status, "non-reciprocal for `yy'-`yy' data")
replace off_from = real(regexs(1)) if off_from == . & regexm(status, "`yy'-`yy' data not received")
replace off_to   = real(regexs(2)) if off_to == . & regexm(status, "`yy'-`yy' data not received")
replace off_from = real(regexs(1)) if off_from == . & regexm(status, "\(`yy' data not received")
replace off_to   = off_from        if off_to == . & off_from != .
replace off_from = real(regexs(1)) + 1 if off_from == . & regexm(status, "`yy' data was the last received")
replace off_to   = 9999 if off_to == . & off_from != .
gen dac2_to = .
replace dac2_to = real(regexs(2)) if regexm(status, "reciprocal `yy'-`yy' data \(DAC2\)")
replace off_from = max(off_from, dac2_to + 1) if dac2_to != . & off_from != .
replace off_from = dac2_to + 1 if dac2_to != . & regexm(status, "non-reciprocal under MCAA until `yy'")
replace off_to = real(regexs(1)) - 1 if dac2_to != . & regexm(status, "non-reciprocal under MCAA until `yy'")
drop dac2_to

* Suspension by the partners ("suspended from YYYY exchanges" = data years
* from YYYY - 1), applied to every pair of that receiver
gen cut = real(regexs(1)) - 1 if regexm(status, "suspended from ([0-9][0-9][0-9][0-9]) exchanges")
bys receiver_iso3: egen receiver_cutoff_year = min(cut)
drop cut

* Receivers with at least one activated relationship (the others only send)
gen byte act = first_reportable_year != .
bys receiver_iso3: egen byte receiver_has_activation = max(act)
drop act

label variable first_reportable_year "First calendar year of account data sent by the centre to the owner's authority"
label variable off_from "First data year without exchange (status)"
label variable off_to "Last data year without exchange (status)"
label variable receiver_cutoff_year "Owner cut off by its partners from this data year"
label variable receiver_has_activation "1 = owner has at least one activated receiving relationship"
keep sender_iso3 receiver_iso3 receiver_name first_reportable_year status off_from off_to ///
     receiver_cutoff_year receiver_has_activation
save "$data_processed/crs_pair_activation.dta", replace

keep receiver_iso3 receiver_cutoff_year receiver_has_activation
duplicates drop
isid receiver_iso3
save "$data_processed/crs_receiver_info.dta", replace

* ---- 1.6e Owner positions measured from the owners' own CRS statistics ------
* Position between the Danish (0) and German (1) identification path from the
* own-name share of reported individual + passive-entity wealth (sources and
* arithmetic in the file)
import delimited using "$data_raw/$crs_owner_position_file", clear varnames(1) ///
    asdouble stringcols(1 6 7) bindquote(strict)
keep iso3 position_german
rename iso3 country_owner_iso3
rename position_german position_measured
isid country_owner_iso3
assert position_measured >= 0 & position_measured <= 1
label variable position_measured "Position between Danish (0) and German (1) path, owner's own CRS statistics"
save "$data_processed/crs_owner_position_measured.dta", replace

/*------------------------------------------------------------------------------
* 1.7 IMPORT CRS IMPLEMENTATION YEAR
*
* Source: OECD CRS by Jurisdiction table (first year of information exchange)
------------------------------------------------------------------------------*/
di as text "  Importing CRS implementation years..."

import excel "$data_raw/241018 crs implementation year.xlsx", sheet("Sheet3") firstrow clear
run "$code_github/helpers/Harmonizing country names.do"
drop c_x
isid country
save "$data_processed/crs_implementation_year.dta", replace

/*------------------------------------------------------------------------------
* 1.7b IMPORT EUTO GLOBAL OFFSHORE WEALTH TOTALS
*
* Source: Faye, Godar, Moura and Zucman (2025), "Global Offshore Wealth,
* 2001-2023", via the Atlas of the Offshore World ($euto_file in $data_raw).
* The global total is the sum over owner countries of offshore financial wealth.
------------------------------------------------------------------------------*/
di as text "  Importing EUTO global offshore wealth totals..."

import delimited using "$data_raw/$euto_file", clear varnames(1)
keep if indicator == "total"
collapse (sum) offshore_wealth_usd_bn = value, by(year)
label variable offshore_wealth_usd_bn "Global household offshore financial wealth (USD bn), FGMZ 2025 / Atlas"
save "$data_processed/euto_offshore_wealth_totals.dta", replace

/*------------------------------------------------------------------------------
* 1.8 BUILD MAIN COUNTRY-YEAR PANEL
*
* Merge all data sources into a single panel dataset.
------------------------------------------------------------------------------*/
di as text "  Building main country-year panel..."

* Build panel
use "$data_raw/country_iso_tjn.dta", clear
local T = $year_end - $year_start + 1
assert `T' > 0

expand `T'
bysort country_iso3: gen year = $year_start + _n - 1

order country_iso3 year
sort country_iso3 year

* Fix Kosovo ISO3 code (the TJN list uses XKV, older files KSV; World Bank uses XKX)
replace country_iso3 = "XKX" if inlist(country_iso3, "KSV", "XKV")

* Merge with BIS deposits data
joinby country_iso2 year using "$data_processed/total deposits to merge.dta", unmatched(master)
drop _merge

* Merge with WB GDP, population and income level
joinby country_iso3 year using "$data_processed/gdp_population_incomelevel.dta", unmatched(master)
drop _merge

* Income level from the World Bank classification file ($wb_classification_file),
* the same one the chapter tables use; Taiwan, Jersey and Guernsey high income
preserve
    import delimited using "$data_raw/$wb_classification_file", clear varnames(1) stringcols(_all)
    keep iso3 income_code
    rename iso3 country_iso3
    isid country_iso3
    tempfile wbclass
    save `wbclass'
restore
merge m:1 country_iso3 using `wbclass', keep(master match) nogen
replace incomelevel = income_code if income_code != ""
replace incomelevel = "HIC" if inlist(country_iso3, "TWN", "JEY", "GGY")
drop income_code

save "$data_processed/1_deposits.dta", replace

/*------------------------------------------------------------------------------
* 1.9 PREPARE DERIVED VARIABLES
------------------------------------------------------------------------------*/
di as text "  Preparing derived variables..."

use "$data_processed/1_deposits.dta", clear
sort country year

* Fill in GDP for jurisdictions without World Bank data (single values used for
* all years; GBP amounts converted at 0.75 GBP per USD)
* Guernsey: official GDP of GBP 3,272 million (gov.gg)
replace gdp = 3272 * 1000000 / 0.750 if country == "Guernsey" & gdp == .

* Jersey: GBP 5,002.9 million in 2021 prices (opendata.gov.je), deflated to 2018
* with the UK GDP deflator and converted at the 2018 USD/GBP rate
replace gdp = 5002.9 * 1000000 * (105.5/114.1) * 1.3349 if country == "Jersey" & gdp == .

* Gibraltar
replace gdp = 2344 * 1000000 * (1/0.75) if country == "Gibraltar" & gdp == .

* Taiwan: not in the World Bank data. Nominal GDP in current USD by year from
* the IMF World Economic Outlook (series NGDPD, datamapper API, downloaded
* 19 Oct 2026)
local twn_gdp_2001 299.3
local twn_gdp_2002 307.4
local twn_gdp_2003 317.4
local twn_gdp_2004 346.9
local twn_gdp_2005 374.1
local twn_gdp_2006 386.4
local twn_gdp_2007 406.9
local twn_gdp_2008 415.9
local twn_gdp_2009 390.8
local twn_gdp_2010 444.3
local twn_gdp_2011 484.0
local twn_gdp_2012 495.6
local twn_gdp_2013 512.9
local twn_gdp_2014 535.3
local twn_gdp_2015 534.5
local twn_gdp_2016 543.1
local twn_gdp_2017 591.7
local twn_gdp_2018 610.7
local twn_gdp_2019 613.5
local twn_gdp_2020 676.9
local twn_gdp_2021 777.0
local twn_gdp_2022 765.6
local twn_gdp_2023 757.4
local twn_gdp_2024 801.5
forvalues y = 2001/2024 {
    replace gdp = `twn_gdp_`y'' * 1000000000 if country == "Taiwan" & year == `y' & gdp == .
}

* Bonaire, Sint Eustatius and Saba
replace gdp = (505 + 128 + 48) * 1000000 if country == "Bonaire, Sint Eustatius and Saba" & gdp == .

* Falkland Islands
replace gdp = 254.7 * 1000000 * (1/0.75) if country == "Falkland Islands" & gdp == .

* British Virgin Islands: USD 1,539 million (UN National Accounts)
replace gdp = 1539 * 1000000 if country == "British Virgin Islands" & gdp == .

* Anguilla: approx. USD 300 million (UN National Accounts)
replace gdp = 300 * 1000000 if country == "Anguilla" & gdp == .

* Extrapolate missing GDP from the previous year assuming $gdp_growth_fill
* growth (sequential replace, so chains of missing years are filled)
sort country_iso3 year
bysort country_iso3 (year): replace gdp = gdp[_n-1] * (1 + $gdp_growth_fill) ///
    if gdp == . & gdp[_n-1] != . & year > $year_start
bysort country_iso3 (year): replace gdp_pc = gdp_pc[_n-1] * (1 + $gdp_growth_fill) ///
    if gdp_pc == . & gdp_pc[_n-1] != . & year > $year_start

* Calculate inward deposits as share of GDP
gen inward_dep_over_gdp = tot_inward_dep / gdp
label variable inward_dep_over_gdp "Inward deposits / GDP"

save "$data_processed/2_deposits_secrecy.dta", replace

/*------------------------------------------------------------------------------
* 1.10 PREPARE COUNTERPART (OWNER) AND HOST COUNTRY DETAILS
*
* Versions of the country details for merging onto counterpart (owner) and
* reporting (host) countries in the bilateral data.
------------------------------------------------------------------------------*/
di as text "  Preparing counterpart and host country details..."

use "$data_processed/2_deposits_secrecy.dta", clear
keep country country_iso2 country_iso3 year gdp gdp_pc incomelevel

* Rename with counter_ prefix for merging onto counterpart
rename country counter_country
rename incomelevel counter_incomelevel
rename country_iso3 counterpart_country_iso3
rename country_iso2 counterpart_country_iso2
rename gdp counter_gdp
rename gdp_pc counter_gdp_pc

save "$data_processed/counterparty_details.dta", replace

use "$data_raw/country_iso_tjn.dta", clear
keep country country_iso2 country_iso3
replace country_iso3 = "XKX" if inlist(country_iso3, "KSV", "XKV")
rename country country_stored
rename country_iso3 country_stored_iso3
save "$data_processed/host_details.dta", replace

di as text ""
di as text "  Data preparation complete."
di as text "============================================================"
di as text ""
