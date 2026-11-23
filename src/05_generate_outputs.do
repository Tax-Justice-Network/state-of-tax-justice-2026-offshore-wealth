/*******************************************************************************
* 05_generate_outputs.do
*
* Purpose: Step 5 - country-level and global results of the coverage method
*          (04_apply_crs.do): offshore wealth, the part reported to the owner's
*          tax authority, owner-identified, taxed and untaxed wealth, and the
*          tax loss on untaxed wealth
*          - by owner country (who suffers the tax loss)
*          - by financial centre where the wealth is booked (who causes it)
*          - globally by year
*
* Inputs:  - $data_processed/offshore_wealth_panel_v2.dta
*
* Outputs (suffix $output_label):
*          - $tables/offshore_wealth_owned_<label>.csv
*          - $tables/offshore_wealth_stored_<label>.csv
*          - $tables/global_by_year_<label>.csv
*
* Units:   wealth, income and tax losses in USD millions; *_pct in % of the
*          offshore wealth concerned; *_sogdp in % of GDP; *_soglob shares of
*          the global total (0-1).
*
* Author: Tax Justice Network
* Last updated: 20 October 2026
*******************************************************************************/

di as text ""
di as text "============================================================"
di as text "STEP 5: GENERATING COUNTRY AND GLOBAL OUTPUTS"
di as text "============================================================"

local L "$output_label"

/*------------------------------------------------------------------------------
* 5.1 BY OWNER COUNTRY (WHO SUFFERS THE TAX LOSS)
------------------------------------------------------------------------------*/
di as text "  Collapsing by owner country..."

use "$data_processed/offshore_wealth_panel_v2.dta", clear
gen double no_information = offshore_wealth * (reason_no_exchange != "")

collapse (sum) offshore_wealth reported = covered owner_identified taxed untaxed ///
               no_information hidden_income tax_loss tax_loss_noaeoi ///
         (first) top_pit_rate source_top_pit_rate owner_type w_german owner_position_basis hshare hshare_avg year_of_crs_impl_owner, ///
         by(country_owner country_owner_iso3 year global_gdp_year country_owner_gdp country_owner_incomelevel)

rename country_owner country
rename country_owner_iso3 country_iso3
rename country_owner_gdp gdp
rename country_owner_incomelevel incomelevel

foreach v in reported owner_identified taxed untaxed no_information {
    gen double `v'_pct = `v' / offshore_wealth * 100
}
gen double tax_loss_avoided = tax_loss_noaeoi - tax_loss
gen double offshore_wealth_sogdp = offshore_wealth * 1e6 / gdp * 100
gen double untaxed_sogdp = untaxed * 1e6 / gdp * 100
gen double tax_loss_sogdp = tax_loss * 1e6 / gdp * 100
bysort year: egen double global_offshore_wealth = total(offshore_wealth)
bysort year: egen double global_tax_loss = total(tax_loss)
gen double offshore_wealth_soglob = offshore_wealth / global_offshore_wealth
gen double tax_loss_soglob = tax_loss / global_tax_loss
bysort year: egen rank_tax_loss = rank(tax_loss), field

label variable country "Country of residence of the wealth owners"
label variable country_iso3 "ISO3 code, owner country"
label variable gdp "GDP of the owner country (USD)"
label variable incomelevel "World Bank income group (WDI)"
label variable offshore_wealth "Offshore wealth owned (USD millions), FGMZ 2025"
label variable reported "Reported to the owner's tax authority (USD millions)"
label variable owner_identified "Reported with an identified owner (USD millions)"
label variable taxed "Taxed (USD millions), incl. declared share"
label variable untaxed "Untaxed (USD millions)"
label variable no_information "In pairs where no report reaches the owner's authority (USD millions)"
label variable hidden_income "Income on untaxed wealth (USD millions)"
label variable tax_loss "Tax loss suffered (USD millions)"
label variable tax_loss_noaeoi "Tax loss without any exchange of information (USD millions)"
label variable tax_loss_avoided "Tax loss avoided through exchange of information (USD millions)"
label variable reported_pct "Reported (% of offshore wealth)"
label variable owner_identified_pct "Owner identified (% of offshore wealth)"
label variable taxed_pct "Taxed (% of offshore wealth)"
label variable untaxed_pct "Untaxed (% of offshore wealth)"
label variable no_information_pct "No information received (% of offshore wealth)"
label variable offshore_wealth_sogdp "Offshore wealth owned (% of GDP)"
label variable untaxed_sogdp "Untaxed offshore wealth owned (% of GDP)"
label variable tax_loss_sogdp "Tax loss suffered (% of GDP)"
label variable global_offshore_wealth "Global offshore wealth (USD millions)"
label variable global_tax_loss "Global tax loss (USD millions)"
label variable offshore_wealth_soglob "Share of global offshore wealth"
label variable tax_loss_soglob "Share of the global tax loss"
label variable rank_tax_loss "Rank by tax loss suffered (1 = largest)"
label variable year_of_crs_impl_owner "First year of CRS exchange, owner country (OECD)"

order country country_iso3 year incomelevel gdp offshore_wealth reported owner_identified ///
      taxed untaxed no_information hidden_income tax_loss tax_loss_noaeoi tax_loss_avoided
sort year rank_tax_loss
export delimited using "$tables/offshore_wealth_owned_`L'.csv", replace
di as text "    Saved: offshore_wealth_owned_`L'"

/*------------------------------------------------------------------------------
* 5.2 BY FINANCIAL CENTRE (WHERE THE WEALTH IS BOOKED)
------------------------------------------------------------------------------*/
di as text "  Collapsing by financial centre..."

use "$data_processed/offshore_wealth_panel_v2.dta", clear
gen double no_information = offshore_wealth * (reason_no_exchange != "")

collapse (sum) wealth_booked = offshore_wealth reported = covered untaxed no_information ///
               hidden_income_caused = hidden_income tax_loss_caused = tax_loss ///
               tax_loss_caused_noaeoi = tax_loss_noaeoi ///
         (first) owner_distribution_imputed year_of_crs_impl_stored s r, ///
         by(country_stored country_stored_iso3 year global_gdp_year)

rename country_stored country
rename country_stored_iso3 country_iso3

foreach v in reported untaxed no_information {
    gen double `v'_pct = `v' / wealth_booked * 100
}
bysort year: egen double global_offshore_wealth = total(wealth_booked)
bysort year: egen double global_tax_loss = total(tax_loss_caused)
gen double wealth_booked_soglob = wealth_booked / global_offshore_wealth
gen double tax_loss_caused_soglob = tax_loss_caused / global_tax_loss
bysort year: egen rank_tax_loss_caused = rank(tax_loss_caused), field

label variable country "Financial centre where the wealth is booked"
label variable country_iso3 "ISO3 code, financial centre"
label variable wealth_booked "Offshore wealth booked in the centre (USD millions), FGMZ 2025"
label variable reported "Reported to the owners' tax authorities (USD millions)"
label variable untaxed "Untaxed (USD millions)"
label variable no_information "In pairs where no report reaches the owner's authority (USD millions)"
label variable hidden_income_caused "Income on untaxed wealth booked here (USD millions)"
label variable tax_loss_caused "Tax loss caused (USD millions)"
label variable tax_loss_caused_noaeoi "Tax loss caused without any exchange of information (USD millions)"
label variable reported_pct "Reported (% of wealth booked)"
label variable untaxed_pct "Untaxed (% of wealth booked)"
label variable no_information_pct "No information sent (% of wealth booked)"
label variable wealth_booked_soglob "Share of global offshore wealth booked here"
label variable tax_loss_caused_soglob "Share of the global tax loss caused"
label variable rank_tax_loss_caused "Rank by tax loss caused (1 = largest)"
label variable s "Share of wealth held through self-reporting structures"
label variable r "Non-reporting rate of self-reporting structures"

order country country_iso3 year wealth_booked reported untaxed no_information ///
      hidden_income_caused tax_loss_caused tax_loss_caused_noaeoi
sort year rank_tax_loss_caused
export delimited using "$tables/offshore_wealth_stored_`L'.csv", replace
di as text "    Saved: offshore_wealth_stored_`L'"

/*------------------------------------------------------------------------------
* 5.3 GLOBAL BY YEAR
------------------------------------------------------------------------------*/
di as text "  Global totals by year..."

use "$data_processed/offshore_wealth_panel_v2.dta", clear
gen double no_information = offshore_wealth * (reason_no_exchange != "")
collapse (sum) offshore_wealth reported = covered owner_identified taxed untaxed no_information ///
               hidden_income tax_loss tax_loss_noaeoi (first) global_gdp_year, by(year)
foreach v in reported owner_identified taxed untaxed no_information {
    gen double `v'_pct = `v' / offshore_wealth * 100
}
foreach v in offshore_wealth taxed untaxed tax_loss tax_loss_noaeoi {
    gen double `v'_sogdp = `v' * 1e6 / global_gdp_year * 100
}
gen double tax_loss_avoided = tax_loss_noaeoi - tax_loss
label variable offshore_wealth "Global offshore wealth (USD millions), FGMZ 2025"
label variable tax_loss "Global tax loss (USD millions)"
label variable tax_loss_noaeoi "Global tax loss without any exchange of information (USD millions)"
label variable tax_loss_avoided "Tax loss avoided through exchange of information (USD millions)"
label variable global_gdp_year "Global GDP (USD)"
export delimited using "$tables/global_by_year_`L'.csv", replace

di as text ""
di as text "  Global results (USD bn):"
di as text "  Year   Wealth  Untaxed (%)  Tax loss  Without exchange  Avoided"
forvalues i = 1/`=_N' {
    di as text "  " year[`i'] " " %8.0f offshore_wealth[`i']/1000 %9.0f untaxed[`i']/1000 ///
        " (" %4.1f untaxed_pct[`i'] ")" %9.1f tax_loss[`i']/1000 %14.1f tax_loss_noaeoi[`i']/1000 ///
        %12.1f tax_loss_avoided[`i']/1000
}

di as text ""
di as text "  Output generation complete."
di as text "============================================================"
di as text ""
