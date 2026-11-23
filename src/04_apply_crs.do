/*******************************************************************************
* 04_apply_crs.do
*
* Purpose: Step 4 of the offshore wealth methodology: for every owner country,
*          financial centre and year, split FGMZ offshore wealth into the part
*          that is reported to the owner's tax authority with an identified
*          owner and taxed, and the untaxed part on which tax is lost.
*          Coverage-based method (parameters in 00_setup.do, Section 6).
*
* Method:  1. Offshore wealth of the pair W = FGMZ global total x pair share
*          2. Owner country's top PIT rate (OECD, researched, KPMG, else group average)
*          3. Is information exchanged? Pair on from the first calendar year
*             whose account data the centre sent to the owner's authority
*             (directed activation table), off again in suspended or
*             non-reciprocal data years; the US never sends under the CRS;
*             US owners are covered through FATCA everywhere; wealth booked in
*             the US is covered for reciprocal FATCA partners, own-name only
*          4. Reported share: Denmark's coverage of FGMZ wealth in reporting
*             centres (by year), scaled by (1 - s_j r_jy) relative to Denmark's
*             own wealth-weighted s x r over its active pairs, capped at
*             1 - s_j r_jy (s: share held through self-reporting structures,
*             r: their non-reporting rate)
*          5. Owner-identified share by owner type (Danish or German path)
*          6. Taxed = identified x (1 - BJKLZ untaxed share), with a floor of
*             $pre_crs_declared_share x W per owner-year (declared wealth),
*             the top-up spread over the owner's centres by untaxed wealth
*          7. Untaxed = W - taxed; hidden income = untaxed x return; tax loss
*             = hidden income x top PIT rate. Counterfactuals: no exchange at
*             all (only the declared share taxed) and full coverage this year
*
* Inputs:  - $data_processed/share_of_deposits_in_sjs_all_years.dta
*          - $data_processed/2_deposits_secrecy.dta (global GDP)
*          - $data_processed/euto_offshore_wealth_totals.dta
*          - $data_processed/top_pit_rates.dta
*          - $data_processed/bis_household_share.dta
*          - $data_processed/crs_coverage_anchors.dta
*          - $data_processed/crs_structure_s.dta, crs_structure_r.dta
*          - $data_processed/crs_pair_activation.dta, crs_receiver_info.dta
*          - $data_processed/fatca_partners.dta
*          - $data_processed/crs_implementation_year.dta
*
* Outputs: - $data_processed/offshore_wealth_panel_v2.dta (owner x centre x year)
*
* Units:   USD millions unless stated otherwise.
*
* Author: Tax Justice Network
* Last updated: 20 October 2026
*******************************************************************************/

di as text ""
di as text "============================================================"
di as text "STEP 4: INFORMATION EXCHANGE COVERAGE AND UNTAXED OFFSHORE WEALTH"
di as text "============================================================"

/*------------------------------------------------------------------------------
* 4.1 LOAD PAIRS AND GLOBAL GDP
------------------------------------------------------------------------------*/
di as text "  Loading owner x centre data..."

use "$data_processed/share_of_deposits_in_sjs_all_years.dta", clear
drop if year == .

preserve
    use "$data_processed/2_deposits_secrecy.dta", clear
    keep if year != .
    collapse (sum) global_gdp_year = gdp, by(year)
    tempfile global_gdp_year
    save `global_gdp_year'
restore
merge m:1 year using `global_gdp_year', nogen keep(master match)
label variable global_gdp_year "Global GDP (USD), sum over countries in panel"

/*------------------------------------------------------------------------------
* 4.2 OFFSHORE WEALTH OF THE PAIR (FGMZ 2025)
------------------------------------------------------------------------------*/
di as text "  Applying the global offshore wealth total (FGMZ 2025)..."

merge m:1 year using "$data_processed/euto_offshore_wealth_totals.dta", keep(master match) nogen
assert offshore_wealth_usd_bn != .
gen double total_offshore_wealth = offshore_wealth_usd_bn * 1000
drop offshore_wealth_usd_bn
label variable total_offshore_wealth "Global offshore financial wealth (USD millions)"

* The pair file carries FGMZ's own USD figures, which sum to the global total
* (difference below 1e-6, checked here)
gen double offshore_wealth = abnormal_deposits_bilateral / 1e6
gen double chk = reldif(offshore_wealth, share_of_tot_abn_deps_bilateral * total_offshore_wealth)
sum chk, meanonly
di as text "  Max. relative difference, FGMZ pair figures vs. share x global total: " %9.2e r(max)
assert r(max) < 1e-5
drop chk
label variable offshore_wealth "Offshore wealth of the owner country held in the centre (USD millions)"

/*------------------------------------------------------------------------------
* 4.3 TOP PERSONAL INCOME TAX RATE OF THE OWNER COUNTRY
*
* OECD, else the researched rates, else KPMG (01_prepare_data.do); countries
* without a rate get the income-group average of the available rates, then the
* global average.
------------------------------------------------------------------------------*/
di as text "  Adding tax rates..."

rename country_owner_iso3 country_iso3
merge m:1 country_iso3 year using "$data_processed/top_pit_rates.dta", ///
    keep(master match) nogen keepusing(top_pit_rate source_top_pit_rate)
rename country_iso3 country_owner_iso3

bys country_owner_iso3 year: gen byte owner_first = (_n == 1)
gen double pit_country = top_pit_rate if owner_first == 1
bys country_owner_incomelevel year: egen double pit_avg_income = mean(pit_country)
replace pit_avg_income = . if country_owner_incomelevel == ""
bys year: egen double pit_avg_global = mean(pit_country)
replace source_top_pit_rate = "Income-group average" if top_pit_rate == . & pit_avg_income != .
replace top_pit_rate = pit_avg_income if top_pit_rate == .
replace source_top_pit_rate = "Global average" if top_pit_rate == . & pit_avg_global != .
replace top_pit_rate = pit_avg_global if top_pit_rate == .
drop pit_country pit_avg_income pit_avg_global owner_first
assert top_pit_rate != .
label variable top_pit_rate "Top statutory PIT rate of owner country (share)"

/*------------------------------------------------------------------------------
* 4.4 OWNER POSITION BETWEEN THE DANISH AND THE GERMAN IDENTIFICATION PATH
*
* w_german = weight on the German path (0 = Danish, 1 = German) under
* $owner_type_rule (00_setup.do). Default "measured_fitted":
* owners with their own CRS statistics get their measured position
* ($crs_owner_position_file); all others are placed by h, the households'
* share of their cross-border deposits with BIS reporting banks (households +
* non-financial corporations), averaged over the period: a straight line that
* starts at Denmark's h (position 0), with the slope fitted to the measured
* owners below the German end, capped at 1. Owners without BIS data: German.
------------------------------------------------------------------------------*/
di as text "  Placing owners between the Danish and German paths ($owner_type_rule)..."

rename country_owner_iso2 country_iso2
merge m:1 country_iso2 year using "$data_processed/bis_household_share.dta", ///
    keep(master match) nogen keepusing(hshare)
preserve
    use "$data_processed/bis_household_share.dta", clear
    keep if year >= $year_start & year <= $year_end
    collapse (mean) hshare_avg = hshare, by(country_iso2)
    sum hshare_avg if country_iso2 == "DK", meanonly
    global h_dk = r(mean)
    sum hshare_avg if country_iso2 == "DE", meanonly
    global h_de = r(mean)
    tempfile havg
    save `havg'
restore
merge m:1 country_iso2 using `havg', keep(master match) nogen
rename country_iso2 country_owner_iso2
if "$owner_type_rule" == "binary_yearly" {
    gen double w_german = cond(hshare != . & hshare < $owner_type_hh_threshold, 0, 1)
}
else if "$owner_type_rule" == "binary_average" {
    gen double w_german = cond(hshare_avg != . & hshare_avg < $owner_type_hh_threshold, 0, 1)
}
else if "$owner_type_rule" == "continuous_average" {
    assert $h_de > $h_dk
    gen double w_german = cond(hshare_avg == ., 1, min(1, max(0, (hshare_avg - $h_dk) / ($h_de - $h_dk))))
}
else if inlist("$owner_type_rule", "measured_line", "measured_fitted") {
    assert $h_de > $h_dk
    merge m:1 country_owner_iso3 using "$data_processed/crs_owner_position_measured.dta", ///
        keep(master match) nogen keepusing(position_measured)
    if "$owner_type_rule" == "measured_line" {
        local slope = 1 / ($h_de - $h_dk)
    }
    else {
        * Line through Denmark's point (h_DK, 0), slope by least squares on the
        * measured owners below the German end; measured owners at the German
        * end must lie where the fitted line has reached 1
        preserve
            keep country_owner_iso3 hshare_avg position_measured
            keep if position_measured != .
            duplicates drop
            isid country_owner_iso3
            assert hshare_avg != .
            gen double x = hshare_avg - $h_dk
            gen double xw = x * position_measured if position_measured < 1
            gen double xx = x^2 if position_measured < 1
            sum xw, meanonly
            local sxw = r(sum)
            sum xx, meanonly
            local sxx = r(sum)
            assert `sxx' > 0
            local slope = `sxw' / `sxx'
            assert `slope' * x >= 1 - 1e-9 if position_measured == 1
        restore
    }
    global owner_slope = `slope'
    di as text "    position = " %6.3f `slope' " x (h_avg - " %5.3f $h_dk "), German end reached at h_avg = " %5.3f ($h_dk + 1 / `slope')
    gen double w_german = cond(position_measured != ., position_measured, ///
        cond(hshare_avg == ., 1, min(1, max(0, `slope' * (hshare_avg - $h_dk)))))
}
else {
    di as error "Unknown owner_type_rule: $owner_type_rule"
    exit 198
}
gen owner_type = cond(w_german == 0, "A", cond(w_german == 1, "B", "A/B"))
capture confirm variable position_measured
if _rc gen double position_measured = .
gen owner_position_basis = cond(position_measured != ., "Own CRS statistics", ///
    cond(hshare_avg != ., "BIS household share", "No BIS data"))
label variable owner_position_basis "What sets the owner's position between the Danish and German path"
label variable hshare "Households' share of the owner country's cross-border deposits (BIS)"
label variable hshare_avg "Average household share over the analysis period"
label variable w_german "Weight on the German identification path (0 = Danish, 1 = German)"
label variable owner_type "Owner identification path: A = Danish, B = German, A/B = in between"

/*------------------------------------------------------------------------------
* 4.5 COVERAGE ANCHORS, IDENTIFICATION SHARES AND STRUCTURE PARAMETERS
------------------------------------------------------------------------------*/
di as text "  Adding coverage anchors and structure parameters..."

merge m:1 year using "$data_processed/crs_coverage_anchors.dta", keep(master match) nogen
assert coverage_dk != .
gen double ident_share = ident_A + w_german * (ident_B - ident_A)
gen double ownname_share = ownname_A + w_german * (ownname_B - ownname_A)
label variable ident_share "Owner-identified share of reported wealth (Danish/German paths by w_german)"
label variable ownname_share "Own-name share of reported wealth (Danish/German paths by w_german)"

rename country_stored_iso3 centre_iso3
merge m:1 centre_iso3 using "$data_processed/crs_structure_s.dta", keep(master match) nogen
merge m:1 centre_iso3 year using "$data_processed/crs_structure_r.dta", keep(master match) nogen
rename centre_iso3 country_stored_iso3
gen double sr = s * r
quietly count if sr == . & country_stored_iso3 != "USA"
if r(N) > 0 {
    di as error "Centres without s x r parameters:"
    tab country_stored_iso3 if sr == . & country_stored_iso3 != "USA"
    exit 459
}
label variable s "Share of the centre's wealth held through self-reporting structures"
label variable r "Non-reporting rate of self-reporting structures (centre, year)"
label variable sr "s x r: share of the centre's wealth invisible to the CRS"

/*------------------------------------------------------------------------------
* 4.6 IS INFORMATION EXCHANGED FOR THE PAIR?
------------------------------------------------------------------------------*/
di as text "  Determining exchange of information by pair and year..."

gen sender_iso3 = country_stored_iso3
gen receiver_iso3 = country_owner_iso3
merge m:1 sender_iso3 receiver_iso3 using "$data_processed/crs_pair_activation.dta", ///
    keep(master match) nogen keepusing(first_reportable_year status off_from off_to)
merge m:1 receiver_iso3 using "$data_processed/crs_receiver_info.dta", ///
    keep(master match) nogen keepusing(receiver_cutoff_year receiver_has_activation)
drop sender_iso3 receiver_iso3
replace receiver_has_activation = 0 if receiver_has_activation == .

gen byte crs_in_effect = (first_reportable_year != . & first_reportable_year <= year)
replace crs_in_effect = 0 if off_from != . & year >= off_from & year <= off_to
replace crs_in_effect = 0 if receiver_cutoff_year != . & year >= receiver_cutoff_year
* The United States does not send information under the CRS
replace crs_in_effect = 0 if country_stored_iso3 == "USA"

* Owner receives from at least one centre this year; centre sends to at least
* one owner this year
bys country_owner_iso3 year: egen byte owner_active = max(crs_in_effect)
bys country_stored_iso3 year: egen byte centre_sends = max(crs_in_effect)

* OECD first exchange years of owner and centre (account data of the year
* before), used for the US-owner flag and for the reasons in 4.9
rename country_owner country
joinby country using "$data_processed/crs_implementation_year.dta", unmatched(master)
drop _merge
rename country country_owner
rename year_of_crs_implementation year_of_crs_impl_owner
rename country_stored country
joinby country using "$data_processed/crs_implementation_year.dta", unmatched(master)
drop _merge
rename country country_stored
rename year_of_crs_implementation year_of_crs_impl_stored
label variable year_of_crs_impl_owner "First year of CRS exchange, owner country (OECD)"
label variable year_of_crs_impl_stored "First year of CRS exchange, centre (OECD)"

* US owners are covered through FATCA in every centre (4.7); the CRS flag
* records whether the centre has implemented the CRS (from its first data year)
if $us_fatca_owner_coverage == 1 {
    replace crs_in_effect = (year_of_crs_impl_stored != . & year >= year_of_crs_impl_stored - 1) ///
        if country_owner_iso3 == "USA" & country_stored_iso3 != "USA"
}

* Wealth booked in the US: reciprocal FATCA partners receive own-name reports
rename country_owner_iso3 iso3
merge m:1 iso3 using "$data_processed/fatca_partners.dta", keep(master match) nogen keepusing(fatca_first_year)
rename iso3 country_owner_iso3
gen byte fatca_covered = (country_stored_iso3 == "USA" & country_owner_iso3 != "USA" & ///
    fatca_first_year != . & fatca_first_year <= year)

label variable crs_in_effect "1 = centre sends CRS data on the owner's residents (US owners: centre has implemented the CRS)"
label variable owner_active "1 = owner country receives CRS data from at least one centre this year"
label variable centre_sends "1 = centre sends CRS data to at least one owner this year"
label variable fatca_covered "1 = wealth booked in the US, owner is a reciprocal FATCA partner"

/*------------------------------------------------------------------------------
* 4.7 REPORTED, OWNER-IDENTIFIED AND TAXED WEALTH
------------------------------------------------------------------------------*/
di as text "  Calculating reported, identified and taxed wealth..."

* Denmark's own wealth-weighted s x r over its active pairs (the anchor's
* structure share, against which every centre's s x r is measured)
gen double dk_w = offshore_wealth if country_owner_iso3 == "DNK" & crs_in_effect == 1 & country_stored_iso3 != "USA"
gen double dk_wsr = dk_w * sr
bys year: egen double dk_w_tot = total(dk_w)
bys year: egen double dk_wsr_tot = total(dk_wsr)
gen double sigma_dk = dk_wsr_tot / dk_w_tot
assert sigma_dk != . & sigma_dk < 1
drop dk_w dk_wsr dk_w_tot dk_wsr_tot
label variable sigma_dk "Denmark's wealth-weighted s x r over its active pairs (anchor)"

* Share of the pair's wealth reported to the owner's authority
gen double cov_share = 0
replace cov_share = min(coverage_dk * (1 - sr) / (1 - sigma_dk), 1 - sr) ///
    if crs_in_effect == 1 & country_stored_iso3 != "USA" & country_owner_iso3 != "USA"
if $us_fatca_owner_coverage == 1 {
    replace cov_share = 1 - sr if country_owner_iso3 == "USA" & country_stored_iso3 != "USA"
}
replace cov_share = coverage_dk * ownname_share if fatca_covered == 1
if $us_in_us_covered == 1 {
    replace cov_share = 1 if us_in_us_cell == 1
}
gen double covered = offshore_wealth * cov_share

* Owner identified in the report: own-name accounts plus identified controlling
* persons under the CRS; own-name accounts only in US reports
gen double owner_identified = covered * ident_share
replace owner_identified = covered if fatca_covered == 1 | us_in_us_cell == 1

* Of identified wealth, the part still unreported by the owner and not found
* in audits stays untaxed (BJKLZ 2026, Table 5)
global untaxed_of_identified = ($bjklz_unreported_dkk_bn - $bjklz_audited_dkk_bn) / $bjklz_matched_dkk_bn
gen double taxed_crs = owner_identified * (1 - $untaxed_of_identified)

* Floor: declared share of wealth, per owner and year, absorbed by coverage;
* the top-up is spread over the owner's centres in proportion to untaxed wealth
bys country_owner_iso3 year: egen double w_owner = total(offshore_wealth)
bys country_owner_iso3 year: egen double taxed_crs_owner = total(taxed_crs)
gen double untaxed_crs = offshore_wealth - taxed_crs
bys country_owner_iso3 year: egen double untaxed_crs_owner = total(untaxed_crs)
gen double floor_gap = max(0, $pre_crs_declared_share * w_owner - taxed_crs_owner)
gen double taxed = taxed_crs + cond(untaxed_crs_owner > 0, floor_gap * untaxed_crs / untaxed_crs_owner, 0)
drop w_owner taxed_crs_owner untaxed_crs untaxed_crs_owner floor_gap

gen double untaxed = offshore_wealth - taxed
assert untaxed >= -1e-6
replace untaxed = 0 if untaxed < 0
gen double hidden_income = untaxed * $offshore_return_rate
gen double tax_loss = hidden_income * top_pit_rate

label variable cov_share "Share of the pair's wealth reported to the owner's tax authority"
label variable covered "Wealth reported to the owner's tax authority (USD millions)"
label variable owner_identified "Reported wealth with an identified owner (USD millions)"
label variable taxed_crs "Wealth taxed through information exchange (USD millions)"
label variable taxed "Taxed offshore wealth, incl. declared floor (USD millions)"
label variable untaxed "Untaxed offshore wealth (USD millions)"
label variable hidden_income "Income on untaxed offshore wealth (USD millions)"
label variable tax_loss "Tax loss on untaxed offshore wealth (USD millions)"

/*------------------------------------------------------------------------------
* 4.8 COUNTERFACTUALS
*
* no exchange: only the declared share is taxed
* hypothetical: the pair exchanges this year at the Danish coverage level
*               (US rules for wealth booked in the US), pair-level floor
------------------------------------------------------------------------------*/
gen double untaxed_noaeoi = offshore_wealth * (1 - $pre_crs_declared_share)
gen double hidden_income_noaeoi = untaxed_noaeoi * $offshore_return_rate
gen double tax_loss_noaeoi = hidden_income_noaeoi * top_pit_rate
label variable untaxed_noaeoi "Untaxed wealth without any exchange of information (USD millions)"
label variable hidden_income_noaeoi "Hidden income without exchange (USD millions)"
label variable tax_loss_noaeoi "Tax loss without exchange (USD millions)"

gen double cov_share_hyp = min(coverage_dk * (1 - sr) / (1 - sigma_dk), 1 - sr) if country_stored_iso3 != "USA"
replace cov_share_hyp = coverage_dk * ownname_share if country_stored_iso3 == "USA"
if $us_fatca_owner_coverage == 1 {
    replace cov_share_hyp = 1 - sr if country_owner_iso3 == "USA" & country_stored_iso3 != "USA"
}
replace cov_share_hyp = 1 if us_in_us_cell == 1 & $us_in_us_covered == 1
gen double owner_identified_hyp = offshore_wealth * cov_share_hyp * ident_share
replace owner_identified_hyp = offshore_wealth * cov_share_hyp if country_stored_iso3 == "USA"
gen double taxed_hyp = max(owner_identified_hyp * (1 - $untaxed_of_identified), $pre_crs_declared_share * offshore_wealth)
gen double untaxed_hyp = offshore_wealth - taxed_hyp
gen double hidden_income_hyp = untaxed_hyp * $offshore_return_rate
gen double tax_loss_hyp = hidden_income_hyp * top_pit_rate
drop cov_share_hyp owner_identified_hyp
label variable taxed_hyp "Taxed wealth if the pair exchanged this year (USD millions)"
label variable untaxed_hyp "Untaxed wealth if the pair exchanged this year (USD millions)"
label variable hidden_income_hyp "Hidden income if the pair exchanged this year (USD millions)"
label variable tax_loss_hyp "Tax loss if the pair exchanged this year (USD millions)"

/*------------------------------------------------------------------------------
* 4.9 WHY NO INFORMATION REACHES THE OWNER (FOR PAIRS WITHOUT COVERAGE)
------------------------------------------------------------------------------*/
* In this order: the owner is cut off by its partners; the owner only sends
* (jurisdictions without income tax); the pair is booked in the US and the
* owner is not a reciprocal FATCA partner; the pair is in a non-reciprocal
* period; the owner receives from other centres but not (yet) from this one;
* the owner does not receive at all
gen reason_no_exchange = ""
replace reason_no_exchange = "Owner cut off by partners (" + cond(country_owner_iso3 == "RUS", "Russia", country_owner) + ///
    ", from " + string(receiver_cutoff_year) + ")" ///
    if covered == 0 & receiver_cutoff_year != . & year >= receiver_cutoff_year
* (no income tax, or tax only on some residents' business income, as in Qatar,
* Saudi Arabia and Oman): from the first data year the owner
* sends, it receives nothing; before that it is not yet exchanging
replace reason_no_exchange = "Owner sends but does not receive (no or little income tax)" ///
    if covered == 0 & reason_no_exchange == "" & year_of_crs_impl_owner != . & ///
    receiver_has_activation == 0 & year >= year_of_crs_impl_owner - 1
replace reason_no_exchange = "US does not send (owner not a FATCA reciprocal partner)" ///
    if covered == 0 & reason_no_exchange == "" & country_stored_iso3 == "USA" & country_owner_iso3 != "USA"
replace reason_no_exchange = "Both in the CRS, pair not active (non-reciprocal period)" ///
    if covered == 0 & reason_no_exchange == "" & off_from != . & year >= off_from & year <= off_to
replace reason_no_exchange = "Both in the CRS, pair not yet active (centre joined later)" ///
    if covered == 0 & reason_no_exchange == "" & owner_active == 1
replace reason_no_exchange = "Owner not (yet) exchanging under the CRS" ///
    if covered == 0 & reason_no_exchange == ""
label variable reason_no_exchange "Why no report reaches the owner's authority (empty if covered)"

/*------------------------------------------------------------------------------
* 4.10 SAVE AND DIAGNOSTICS
------------------------------------------------------------------------------*/
drop status off_from off_to
order year country_owner country_owner_iso3 country_stored country_stored_iso3 ///
      offshore_wealth covered owner_identified taxed untaxed hidden_income tax_loss
save "$data_processed/offshore_wealth_panel_v2.dta", replace

di as text ""
di as text "  Global offshore wealth and its taxation (USD bn):"
di as text "  Year   Wealth  Reported  Identified   Taxed  Untaxed  Tax loss  Loss w/o AEOI"
forvalues y = $year_start / $year_end {
    foreach v in offshore_wealth covered owner_identified taxed untaxed tax_loss tax_loss_noaeoi {
        sum `v' if year == `y', meanonly
        local `v' = r(sum) / 1000
    }
    di as text "  `y' " %8.0f `offshore_wealth' %9.0f `covered' %11.0f `owner_identified' ///
        %8.0f `taxed' %8.0f `untaxed' %9.1f `tax_loss' %13.1f `tax_loss_noaeoi'
}
di as text ""
di as text "  Output: $data_processed/offshore_wealth_panel_v2.dta"
di as text "============================================================"
di as text ""
