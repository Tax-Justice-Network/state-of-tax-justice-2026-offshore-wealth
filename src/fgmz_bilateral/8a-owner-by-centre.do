//----------------------------------------------------------------------------//
// TJN extension to Faye, Godar, Moura and Zucman (2025), Global Offshore Wealth
//
// Purpose: owner x financial-centre offshore wealth, using FGMZ's own data and
//          corrections, without pooling centres into the four groups.
//
// Method:  FGMZ step 7a computes, per reporting centre, each depositor
//          country's share of the centre's household-adjusted non-bank
//          deposits, after redistributing deposits held by haven residents
//          and by shell companies (CH, IE, GB, NL, BE, US) to non-haven owners.
//          FGMZ step 7c then uses only the pooled group shares (Swiss,
//          European, Asian, American centres). Here we:
//          (1) recompute FGMZ's corrected share for every centre (the same
//              formula as 7a, also for centres 7a does not loop over);
//          (2) smooth each centre's shares over time with FGMZ's weights
//              (0.1, 0.2, 0.4, 0.2, 0.1; FGMZ's edge-year formulas);
//          (3) rescale each centre-year to sum to one;
//          (4) allocate each centre's published total (7c) by these shares.
//          Switzerland is taken directly from FGMZ (SNB fiduciary deposits,
//          Russia-adjusted benchmark), as published.
//
// Inputs:  $work/offshore`year'.dta (7a), $work/countries.dta (7c)
// Outputs: $work/tjn_owner_by_centre.dta, $work/tjn_owner_by_centre.csv
//----------------------------------------------------------------------------//

local centres "KY PA US HK SG MO MY BH BS BM AN CW AE GG JE IM LU CY GB AT BE"

**----------------------- 1. corrected shares per centre ---------------------**
tempfile shares
forvalues t = 2001/2023 {
	use "$work/offshore`t'.dta", clear
	keep saver iso3saver namesaver bank amt_bis sh_bis haven
	gen keepbank = 0
	foreach b of local centres {
		replace keepbank = 1 if bank == "`b'"
	}
	keep if keepbank == 1
	drop keepbank
	gen year = `t'
	replace amt_bis = 0 if amt_bis == .
	bysort bank: egen double tot = total(amt_bis)
	bysort bank: egen double tothaven = total(cond(haven == 1, amt_bis, 0))
	* FGMZ 7a: rawsh = amt / tot; sh = rawsh * (1 + tothaven / (tot - tothaven)) for non-havens
	gen double sh_c = cond(haven != 1 & tot > 0 & tot > tothaven, ///
		amt_bis / tot * (1 + tothaven / (tot - tothaven)), 0)
	* check against FGMZ where 7a computed the share itself
	gen double dev = abs(sh_c - sh_bis) if sh_bis != . & sh_bis != 0
	quietly summarize dev
	if r(N) > 0 & r(max) > 1e-6 {
		di as error "year `t': recomputed shares differ from FGMZ sh_bis (max " r(max) ")"
	}
	keep year bank iso3saver namesaver sh_c
	if `t' > 2001 append using `shares'
	save `shares', replace
}

**----------------------- 2. FGMZ smoothing, per centre ----------------------**
use `shares', clear
drop if iso3saver == ""
collapse (sum) sh_c (first) namesaver, by(bank iso3saver year)
reshape wide sh_c, i(bank iso3saver) j(year)
forvalues x = 2003/2021 {
	local a = `x' - 2
	local b = `x' - 1
	local c = `x' + 1
	local d = `x' + 2
	gen double s`x' = (sh_c`a' + sh_c`d') * 0.1 + (sh_c`b' + sh_c`c') * 0.2 + sh_c`x' * 0.4
	replace s`x' = sh_c`x' if s`x' == .
}
gen double s2001 = (sh_c2003 * 0.1 + sh_c2002 * 0.2 + sh_c2001 * 0.4) / 0.7
replace s2001 = sh_c2001 if s2001 == .
gen double s2002 = (sh_c2004 * 0.1 + (sh_c2003 + sh_c2001) * 0.2 + sh_c2002 * 0.4) / 0.9
replace s2002 = (sh_c2002 * 0.4 + sh_c2004 * 0.1) / 0.5 if s2002 == .
replace s2002 = sh_c2002 if s2002 == .
gen double s2022 = (sh_c2020 * 0.1 + (sh_c2023 + sh_c2021) * 0.2 + sh_c2022 * 0.4) / 0.9
replace s2022 = sh_c2022 if s2022 == .
gen double s2023 = (sh_c2021 * 0.1 + sh_c2022 * 0.2 + sh_c2023 * 0.4) / 0.7
replace s2023 = sh_c2023 if s2023 == .
drop sh_c*
reshape long s, i(bank iso3saver) j(year)
replace s = 0 if s == .
bysort bank year: egen double s_tot = total(s)
gen double share = cond(s_tot > 0, s / s_tot, 0)
drop s s_tot

tempfile shares_smoothed
save `shares_smoothed'

**----------------------- 3. centre totals and published owner figures (7c) -**
use "$work/countries.dta", clear
keep year iso3 indicator value
replace value = 0 if value == .
tempfile published
save `published'
keep if indicator == "total_attracted" & value > 0
rename iso3 centre_iso3
rename value centre_total_usd_bn
keep year centre_iso3 centre_total_usd_bn
tempfile centretot
save `centretot'

**----------------------- 4. allocation --------------------------------------**
use `shares_smoothed', clear
gen centre_iso3 = ""
foreach pair in KY:CYM PA:PAN US:USA HK:HKG SG:SGP MO:MAC MY:MYS BH:BHR BS:BHS BM:BMU ///
	AN:ANT CW:CUW AE:ARE GG:GGY JE:JEY IM:IMN LU:LUX CY:CYP GB:GBR AT:AUT BE:BEL {
	gettoken b rest : pair, parse(":")
	local c = substr("`rest'", 2, .)
	replace centre_iso3 = "`c'" if bank == "`b'"
}
merge m:1 year centre_iso3 using `centretot', keep(3) nogenerate
gen double wealth_usd_bn = centre_total_usd_bn * share
gen group = ""
replace group = "americ" if inlist(bank, "KY", "PA", "US")
replace group = "europe" if inlist(bank, "GG", "JE", "IM", "LU", "CY", "GB", "AT", "BE")
replace group = "asian" if group == ""
rename iso3saver owner_iso3
keep year owner_iso3 centre_iso3 group share wealth_usd_bn
* Switzerland as published by FGMZ (SNB fiduciary deposits, Russia-adjusted benchmark)
tempfile nonswiss
save `nonswiss'
use `published', clear
keep if indicator == "swiss_russia_adjustment" & value > 0
rename iso3 owner_iso3
rename value wealth_usd_bn
gen centre_iso3 = "CHE"
gen group = "swiss"
bysort year: egen double tot = total(wealth_usd_bn)
gen double share = wealth_usd_bn / tot
drop tot indicator
append using `nonswiss'
drop if wealth_usd_bn == 0
* shell-company pseudo-owners carry no wealth after FGMZ's redistribution
drop if inlist(owner_iso3, "BEH", "CHH", "GBH", "IEH", "NLH", "USH", "TWH")
assert owner_iso3 != centre_iso3
order year owner_iso3 centre_iso3 group wealth_usd_bn share
sort year owner_iso3 centre_iso3
label var wealth_usd_bn "Offshore wealth of owner held in centre, USD bn"
label var share "Owner's share of the centre's offshore wealth (smoothed)"
save "$work/tjn_owner_by_centre.dta", replace
export delimited using "$work/tjn_owner_by_centre.csv", replace

