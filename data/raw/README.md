# Input data

This folder holds every input of the pipeline, as used for the published SOTJ 2026 results. Files named `YYYYMMDD_...` were compiled or downloaded on that date. Data compiled by the Tax Justice Network are licensed under CC BY 4.0. Third-party data stay under their providers' terms (see `LICENSE-DATA.md`).

## Offshore wealth

| File | Content | Source and terms |
|---|---|---|
| `20261006_atlas_offshore_wealth_FGMZ2025.csv` | Offshore financial wealth, 2001–2023, in USD billions. Columns: `iso3`, `year`, `indicator`, `value`. The indicator `total` is the wealth owned by the residents of `iso3`. The indicators `americ`, `asian`, `europe` and `swiss` are the parts of it held in American, Asian, European and Swiss centres. The indicator `total_attracted` is the wealth booked in `iso3` (financial centres only). | Faye, Godar, Moura and Zucman (2025), *Global Offshore Wealth, 2001–2023*, EU Tax Observatory Working Paper No. 41. Export of the Atlas of the Offshore World (atlas-offshore-world.org), 6 October 2026 |
| `20261009_fgmz2025_owner_by_centre_unraked.csv` | Offshore wealth by owner country, financial centre and year (`wealth_usd_bn`), with the centre's group | Tax Justice Network calculation with FGMZ's replication code on public BIS data. Built by `src/fgmz_bilateral/` (see its README). CC BY 4.0 |
| `bis_lbs_extract_20260218.csv` | BIS locational banking statistics: stocks of cross-border positions of all reporting banks vis-à-vis non-banks, by reporting and counterparty country, and liabilities to households and non-financial corporations, by counterparty country. 12,436 of the 608,020 rows of the bulk download of 18 February 2026, copied unchanged. | BIS, [bis.org/statistics/full_data_sets.htm](https://www.bis.org/statistics/full_data_sets.htm) (`WS_LBS_D_PUB_csv_col.csv`); BIS terms of use |

## Exchange of information

| File | Content | Source and terms |
|---|---|---|
| `20261015_crs_sender_partner_years.csv` | For each of 21 financial centres (`sender_iso3`) and each partner (`receiver_iso3`): the first calendar year of account data the centre sent under the CRS (`first_reportable_year`), the partner's status (non-reciprocal periods, suspensions, not activated), and the source of each row (`source_type`, `source_url`, `note`) | Compiled by the Tax Justice Network from the centres' published partner lists, laws and decrees, the OECD register of activated relationships and Global Forum confidentiality clearances. Where no list or date is published, the later of the two countries' first exchange years. CC BY 4.0 |
| `241018 crs implementation year.xlsx` | First year of CRS exchanges by jurisdiction | Compiled by the Tax Justice Network from the OECD's AEOI commitments. CC BY 4.0 |
| `20261116_fatca_reciprocal_partners.csv` | Jurisdictions that receive FATCA information from the United States, with the first data year | Compiled by the Tax Justice Network from IRS Revenue Procedure 2024-42 and the intergovernmental agreements (Kazakhstan from its 2022 data, Argentina from its 2023 data, the years their agreements entered into force). CC BY 4.0 |
| `20261020_crs_coverage_anchors.csv` | Denmark: CRS reports received (`dk_reports_dkk_bn`) and FGMZ offshore wealth in the same centres (`dk_wealth_dkk_bn`) for 2019 and 2022; the shares of reported wealth held in the owner's own name and with an identified owner, for Denmark and Germany, by year. The pipeline recomputes the German identified share with Denmark's owner-coded share of the same year. | Boas, Collin, Godar, Moura and Økland (2025, 2026), from the Danish and German CRS statistics. CC BY 4.0 |
| `20261021_crs_owner_position_measured.csv` | Position between the Danish (0) and the German (1) identification path for the 8 countries that publish CRS statistics, from their own-name share of reported wealth in 2022 | Tax Justice Network calculation from those countries' statistics (sources in the `source` column). CC BY 4.0 |
| `20261020_crs_structure_share_by_centre.csv` | Share of each centre's offshore wealth held through structures that report on themselves (`s_low`, `s_central`, `s_high`; the pipeline uses `s_central`): 2–5% in bank-centred places to 30–45% in trust hubs and Switzerland | Tax Justice Network estimates by type of centre. CC BY 4.0 |
| `20261020_crs_structure_nonreporting_by_centre_year.csv` | Share of that wealth that goes unreported (`r`), by centre and year: 40%, 60% or 80%. The share depends on whether the jurisdictions where such structures are managed require all reporting institutions to register and to file nil returns, and on their Global Forum ratings. | Tax Justice Network estimates from the Global Forum's peer reviews and national rules. CC BY 4.0 |

## Tax rates

| File | Content | Source and terms |
|---|---|---|
| `OECD.CTP.TPS,DSD_TAX_PIT@DF_PIT_TOP_EARN_THRESH,1.0+all.csv` | Top statutory personal income tax rates, OECD countries | OECD Tax Database (CC BY 4.0) |
| `20261021_top_pit_rates_researched.csv` | Top personal income tax rate by country and year, 2016–2023, for all owner countries the OECD does not cover. Sources, links, confidence and notes for each row. | Tax Justice Network research from the EY Worldwide Personal Tax and Immigration Guide edition current in each year, official sources (laws, tax authorities) and other dated professional guides. CC BY 4.0 |
| `pit_rate_kpmg.csv` | Top individual income tax rates, 2016–2020 (used where no researched rate exists) | KPMG individual income tax rates table, as published |

The researched rates follow these conventions:
- the rate of the national tax on overall or general income where one exists, otherwise the top of the employment-income schedule;
- permanent national surcharges on top incomes included (for example India's surcharge and cess, and Bangladesh's net-wealth surcharge at its top band);
- municipal taxes, social contributions, payroll and employer taxes, and temporary levies excluded;
- the default regime where taxpayers can choose;
- the rate in force for most of the year where it changed during the year.

Gulf states that tax neither wages nor investment income (Qatar, Saudi Arabia, Oman, Kuwait and Brunei) have a rate of zero.

## Countries

| File | Content | Source and terms |
|---|---|---|
| `country_iso_tjn.dta` | Country names, ISO codes and groupings | Tax Justice Network. CC BY 4.0 |
| `20261020_world_bank_country_classification.csv` | World Bank income groups and regions (classification of July 2026) | World Bank (CC BY 4.0) |
| `wb_gdp_population_incomelevel_20260218.dta` | GDP, GDP per capita and population, download of 18 February 2026. It is used as the cache; set `$wb_refresh 1` in `src/00_setup.do` to download again. | World Bank World Development Indicators (CC BY 4.0) |
| `wb_countries_20261026.json` | World Bank country list (income groups and regions), used by the chapter tables | World Bank API (CC BY 4.0) |

## Inputs of the chapter figures

`chapter_inputs/` holds the files that the chapter's figures use besides the pipeline outputs:
- `fgmz_global_offshore_wealth_2001_2023.csv`: global offshore wealth by year, from the Atlas file above (Figures 4.1 and 4.3);
- `bloc_members.csv`: the members of the negotiation blocs (OECD, G77, Latin America, African Group, EU), as in Figure 2.3 of the report (Figure 4.6). Compiled by the Tax Justice Network from the member lists of the OECD and the G77 and the African member states of the UN. CC BY 4.0;
- `oecd_global_revenue_statistics_2016_2024.csv`: tax revenue by country and year, general government (Figure 4.6). OECD Global Revenue Statistics Database (CC BY 4.0).

`src/build_chapter.sh` also derives US owners' offshore wealth by financial centre in 2014 and 2015, the first years of FATCA reports, from the owner × centre file above (for Figure 4.3).

## Not included

The full BIS bulk download (about 540 MB) is not included. It is only needed for rebuilding the owner × centre table in `src/fgmz_bilateral/`.
