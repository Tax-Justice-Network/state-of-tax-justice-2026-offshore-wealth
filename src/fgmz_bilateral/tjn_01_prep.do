do "__RUN__/tjn_00_setup.do"
* (1) Global portfolio gap implied by the published FGMZ totals (Atlas export, sum of owner totals):
*     7c sets deposits = 1500 in 2013 and lets them grow with portfolio assets, so
*     portfolio_t = ofw_t * (ofw_2013 - 1500) / ofw_2013. Units of gapport_total: USD millions.
import delimited using "__ATLAS__", clear stringcols(_all)
destring year, replace
replace value = subinstr(value, ",", "", .)
destring value, replace
keep if indicator == "total"
collapse (sum) ofw = value, by(year)
summarize ofw if year == 2013, meanonly
local ofw13 = r(mean)
gen gapport_total = ofw * (`ofw13' - 1500) / `ofw13' * 1000
keep year gapport_total
save "$work/global_portfolio_gap.dta", replace
* (2) Placeholder for the IMF direct-investment file (step 05): it only feeds FGMZ's
*     FDI-adjusted Swiss variant, not the published benchmark (Russia-adjusted) series.
clear
set obs 23
gen year = 2000 + _n
gen country_iso3 = "ZZZ"
gen receiving_iso3 = "CHE"
gen share = .
gen inward = .
gen receiving = ""
gen country = ""
save "$work/fdi-havens.dta", replace
