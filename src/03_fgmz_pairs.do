/*******************************************************************************
* 03_fgmz_pairs.do
*
* Purpose: Offshore wealth by owner country and financial centre from Faye,
*          Godar, Moura and Zucman (2025).
*
* Method:  The owner x centre table is built outside the pipeline from FGMZ's
*          replication code (src/fgmz_bilateral, see its README): FGMZ's
*          method applied centre by centre on current public BIS data, with
*          FGMZ's global and centre totals.
*
*          Variable names with "abnormal" come from an earlier version of the
*          pipeline (abnormal bank deposits); here they refer to FGMZ offshore
*          wealth.
*
* Inputs:  - $data_raw/$fgmz_pairs_file (year, owner_iso3, centre_iso3,
*            group, wealth_usd_bn)
*          - $data_processed/2_deposits_secrecy.dta (names, GDP, income level)
*
* Outputs: - $data_processed/share_of_deposits_in_sjs_all_years.dta
*
* Author: Tax Justice Network
* Last updated: October 2026
*******************************************************************************/

di as text ""
di as text "============================================================"
di as text "STEP 2-3: OWNER x CENTRE OFFSHORE WEALTH FROM FGMZ (2025)"
di as text "============================================================"

* Country names, GDP and income level by ISO3 and year
use country_iso3 year country country_iso2 gdp gdp_pc incomelevel ///
    using "$data_processed/2_deposits_secrecy.dta", clear
keep if year >= $year_start & year <= $year_end
isid country_iso3 year
tempfile countries
save `countries'

* Owner x centre table
import delimited using "$data_raw/$fgmz_pairs_file", clear varnames(1) ///
    stringcols(2 3 4) asdouble
keep if year >= $year_start & year <= $year_end
drop if wealth_usd_bn == . | wealth_usd_bn <= 0

* US Minor Outlying Islands: no permanent population, government or tax law of
* their own (US federal law applies), and not a jurisdiction in TJN's country
* list; their FGMZ wealth is counted with US residents' wealth, which keeps
* FGMZ's global total
replace owner_iso3 = "USA" if owner_iso3 == "UMI"
collapse (sum) wealth_usd_bn, by(year owner_iso3 centre_iso3 group)
isid year owner_iso3 centre_iso3

* Owner attributes
rename owner_iso3 country_iso3
merge m:1 country_iso3 year using `countries', keep(master match)
quietly count if _merge == 1
if r(N) > 0 {
    di as text "  Owners without country data (kept, named by ISO3):"
    tab country_iso3 if _merge == 1
}
replace country = country_iso3 if country == ""
drop _merge
rename country_iso3 country_owner_iso3
rename country country_owner
rename country_iso2 country_owner_iso2
rename gdp country_owner_gdp
rename gdp_pc country_owner_gdp_pc
rename incomelevel country_owner_incomelevel

* Centre attributes
rename centre_iso3 country_iso3
merge m:1 country_iso3 year using `countries', keep(master match) ///
    keepusing(country country_iso2)
assert _merge == 3 | country_iso3 == "ANT"
replace country = "Netherlands Antilles" if country_iso3 == "ANT"
drop _merge
rename country_iso3 country_stored_iso3
rename country country_stored
rename country_iso2 country_stored_iso2

* Shares used downstream (04 multiplies the share by the global total)
bysort year: egen double global_total = total(wealth_usd_bn)
bysort year country_stored_iso3: egen double centre_total = total(wealth_usd_bn)
gen double share_of_tot_abn_deps_bilateral = wealth_usd_bn / global_total
gen double sh_of_tot_abnormal_deposits = centre_total / global_total
gen double owner_share_in_host = wealth_usd_bn / centre_total
gen double abnormal_deposits = centre_total * 1e9
gen double abnormal_deposits_bilateral = wealth_usd_bn * 1e9

* Owner mix not observed in public bilateral BIS data (FGMZ step 4b): global
* residual, 2006-07 shares (Cayman, Panama), assumptions (Cyprus) or FDI and
* real-estate data (UAE); Hong Kong, Macao and Austria before bilateral data
gen byte owner_distribution_imputed = 0
foreach c in CYM PAN SGP BHS BHR BMU MYS CUW ANT CYP ARE {
    replace owner_distribution_imputed = 1 if country_stored_iso3 == "`c'"
}
replace owner_distribution_imputed = 1 if country_stored_iso3 == "HKG" & year < 2014
replace owner_distribution_imputed = 1 if country_stored_iso3 == "MAC" & year < 2013
replace owner_distribution_imputed = 1 if country_stored_iso3 == "AUT" & year < 2007

gen byte us_in_us_cell = (country_owner_iso3 == "USA" & country_stored_iso3 == "USA")

keep year country_stored country_stored_iso2 country_stored_iso3 ///
     country_owner country_owner_iso2 country_owner_iso3 ///
     country_owner_gdp country_owner_gdp_pc country_owner_incomelevel ///
     abnormal_deposits sh_of_tot_abnormal_deposits owner_share_in_host ///
     abnormal_deposits_bilateral share_of_tot_abn_deps_bilateral ///
     owner_distribution_imputed us_in_us_cell group

* Checks: shares sum to one by year; owner shares sum to one by centre
bysort year: egen double chk = total(share_of_tot_abn_deps_bilateral)
assert abs(chk - 1) < 1e-9
drop chk
bysort year country_stored_iso3: egen double chk = total(owner_share_in_host)
assert abs(chk - 1) < 1e-9
drop chk

label variable share_of_tot_abn_deps_bilateral ///
    "Share of global offshore wealth (FGMZ) held in 'country stored' by residents of 'country owner'"
label variable sh_of_tot_abnormal_deposits "Centre's share of global offshore wealth (FGMZ)"
label variable owner_share_in_host "Owner's share of the centre's offshore wealth"
label variable abnormal_deposits "Offshore wealth held in the centre (USD), FGMZ"
label variable abnormal_deposits_bilateral "Offshore wealth of owner in centre (USD), FGMZ-based split"
label variable owner_distribution_imputed "1 = centre's owner mix not observed in bilateral BIS data"
label variable us_in_us_cell "US residents' wealth held in the US, implied by FGMZ's figures"
label variable group "FGMZ group of financial centres"
label variable country_owner "Country of residence of wealth owners"
label variable country_stored "Financial centre where the wealth is held"

sort year country_owner country_stored
save "$data_processed/share_of_deposits_in_sjs_all_years.dta", replace

di as text "  Pairs: " _N
di as text "  Output: $data_processed/share_of_deposits_in_sjs_all_years.dta"
