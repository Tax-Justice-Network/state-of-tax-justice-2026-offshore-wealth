# Results: offshore wealth and tax revenue losses, 2016–2023

The files behind the results of the offshore chapter (chapter 4) of [*The State of Tax Justice 2026*](https://taxjustice.net/reports/the-state-of-tax-justice-2026/). The results themselves are presented in the report and in the [interactive report](https://taxjustice.net/the-state-of-tax-justice-2026-interactive), and the method in the methodology note published with the report. A run of `src/main.do` and `src/build_chapter.sh` reproduces every file in this folder byte for byte, except that the PDF figures carry the date on which they were made.

Amounts are in current US dollars, in billions unless stated. Table A2 is at 2025 prices, as in the report.

## Files

- `pipeline_outputs/`: the files of `src/main.do` that the report uses (USD millions; the owner × centre file `pairs_owner_centre_year_sotj2026.csv` in USD billions): offshore wealth, tax loss and the other results by owner country (`offshore_wealth_owned_sotj2026.csv`) and by financial centre (`offshore_wealth_stored_sotj2026.csv`), and world totals by year (`global_by_year_sotj2026.csv`)
- `chapter/`: the chapter tables (USD billions; `*_%` shares of offshore wealth) and `table_a2_offshore_losses_2023.csv`, the offshore columns of Table A2 (losses suffered and caused, 2023, US$ million at 2025 prices). The comparisons in Table A2 (health spending, job training, wages) come from the companion package on corporate tax abuse.
- `chapter/figures/`: the report's Figures 4.1 to 4.5 (`fig7`, `fig10w`, `fig7b`, `fig10` and `fig13`) and the data of Figures 4.2–4.4 (`*_data.csv`)
- `chapter/blocs/`: Figure 4.6 (losses by negotiation bloc, `fig_blocs_tax_loss_2023_pit`) and its tables
