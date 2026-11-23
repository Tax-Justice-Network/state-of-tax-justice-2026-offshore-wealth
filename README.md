<!-- TITLE AND SUBTITLE -->
<br />
<p align="center">
  <h1 align="center">State of Tax Justice 2026: Offshore wealth</h1>
</p>
<p align="center">Replication package for the estimates of offshore wealth and related tax revenue losses in<br /><b>The State of Tax Justice 2026</b>, chapter 4 ("What the world loses to tax abuse by individuals hiding wealth offshore")</p>
<p align="center">How much financial wealth households hold offshore, how much of it escapes tax after the automatic exchange of information, and how much tax revenue each country loses, 2016–2023</p>

<p align="center">
  <a href="https://taxjustice.net/reports/the-state-of-tax-justice-2026/"><b>📄 Report and methodology note</b></a> &nbsp;·&nbsp; <a href="https://taxjustice.net/the-state-of-tax-justice-2026-interactive"><b>📊 Results</b></a> &nbsp;·&nbsp; <a href="data/raw/README.md"><b>🗂 Data sources</b></a>
</p>

<br />

<!-- TABLE OF CONTENTS -->
<details open="open">
  <summary><h2 style="display: inline-block">Contents</h2></summary>
  <ol>
    <li><a href="#about-the-project">About the project</a></li>
    <li><a href="#installation">Installation</a></li>
    <li><a href="#data-sources">Data sources</a></li>
    <li><a href="#running-it">Running it</a></li>
    <li><a href="#output-layout">Output layout</a></li>
    <li><a href="#repository-layout">Repository layout</a></li>
    <li><a href="#built-with">Built with</a></li>
    <li><a href="#acknowledgements">Acknowledgements</a></li>
    <li><a href="#licence">Licence</a></li>
    <li><a href="#citation">Citation</a></li>
  </ol>
</details>

<br />

<!-- ABOUT -->
## About the project

This repository reproduces the Tax Justice Network's estimates of undeclared offshore wealth and the resulting tax revenue losses in *The State of Tax Justice 2026* (chapter 4). It holds what is needed to reproduce the chapter and its methodology note, and nothing else: every figure and table of the chapter (Figures 4.1–4.6 and the offshore columns of the annex Table A2), the tables from which the numbers in its text are taken, and every parameter of the note. Every input is in `data/raw/`, and a run reproduces the published results in `results/` exactly.

The method is described in the methodology note, published with the report on [taxjustice.net](https://taxjustice.net/reports/the-state-of-tax-justice-2026/). The results are presented in the report and in the [interactive report](https://taxjustice.net/the-state-of-tax-justice-2026-interactive). The estimates build on the offshore wealth estimates and the replication code of Faye, Godar, Moura and Zucman (2025): see [Acknowledgements](#acknowledgements).

<br />

<!-- INSTALLATION -->
## Installation

The pipeline needs **Stata 17 or later** (SE or MP). The chapter tables and figures need **Python 3.10 or later**:

```sh
pip install -r requirements.txt
```

No other downloads are needed to reproduce the published results. The published figures were made with Python 3.14, pandas 3.0, NumPy 2.5 and Matplotlib 3.11.1. With other versions, the figure files may differ in rendering details.

<br />

<!-- DATA SOURCES -->
## Data sources

All inputs are in [`data/raw/`](data/raw/README.md), which lists each file with its source and terms.

| Data | Source |
|---|---|
| Offshore financial wealth by owner country and financial centre, 2001–2023 | Faye, Godar, Moura and Zucman (2025), EU Tax Observatory (Atlas of the Offshore World) |
| Cross-border bank positions (owner shares within centres, household share of deposits) | BIS locational banking statistics, download of 18 February 2026 (extract of the rows used) |
| When each financial centre first sent CRS data to each partner | Compiled by the Tax Justice Network from the centres' partner lists, laws and decrees, the OECD register of activated exchange relationships and Global Forum records |
| How much offshore wealth is reported, how much names the owner, how much is then taxed | Boas, Collin, Godar, Moura and Økland (2025, 2026); Boas, Johannesen, Kreiner, Larsen and Zucman (2026) |
| Top personal income tax rates | OECD Tax Database; rates researched year by year from the EY Worldwide Personal Tax and Immigration Guides, official sources and other dated guides; KPMG (2016–2020) |
| Income groups, regions, GDP | World Bank |
| Negotiation blocs and tax revenue (Figure 4.6) | Bloc members compiled by the Tax Justice Network; OECD Global Revenue Statistics |

<br />

<!-- RUNNING -->
## Running it

1. Run the pipeline in Stata from the `src/` folder:

   ```stata
   cd src
   do main.do
   ```

   Or, from a terminal in `src/`, run `stata-se -b do main.do`. A run takes less than a minute. It writes intermediate files to `data/processed/`, the owner × centre file to `data/final/` and the result tables to `output/tables/`.

2. Rebuild the chapter's tables and figures from the repository root:

   ```sh
   sh src/build_chapter.sh
   ```

   They are written to `output/chapter/`. This also takes less than a minute.

3. Compare with the published results. Every file in `results/pipeline_outputs/` is reproduced byte for byte in `output/tables/` or `data/final/`, and every file in `results/chapter/` in `output/chapter/`. The PDF figures differ only in the creation date stored in each file.

Optional: rebuild the owner × centre input from the EU Tax Observatory's replication code, as described in [`src/fgmz_bilateral/README.md`](src/fgmz_bilateral/README.md).

To use newer data, replace the relevant files in `data/raw/` and update their names in `src/00_setup.do`. For newer BIS data, put the full bulk download `WS_LBS_D_PUB_csv_col.csv` in `data/raw/`; the pipeline then uses it in place of the shipped extract.

<br />

<!-- OUTPUT -->
## Output layout

The pipeline writes these files. Amounts are in USD millions in `output/tables/`; the owner × centre file and the chapter tables are in USD billions. `results/` holds them, with the chapter's tables and figures (see [`results/README.md`](results/README.md)).

| File | Content |
|---|---|
| `offshore_wealth_owned_sotj2026.csv` | By owner country and year: offshore wealth, reported, owner-identified, taxed and untaxed wealth, tax loss, tax loss without any exchange |
| `offshore_wealth_stored_sotj2026.csv` | By financial centre and year: wealth booked, reported and untaxed wealth, tax loss caused |
| `global_by_year_sotj2026.csv` | World totals by year |
| `data/final/pairs_owner_centre_year_sotj2026.csv` | Owner × centre × year file used for the chapter tables and figures (USD bn) |

<br />

<!-- REPO LAYOUT -->
## Repository layout

```
src/
  main.do                  <- runs the pipeline (steps 00–06)
  00_setup.do              <- paths and all parameters
  01_prepare_data.do       <- imports and cleans the inputs
  03_fgmz_pairs.do         <- offshore wealth by owner country and financial centre
  04_apply_crs.do          <- exchange of information: reported, identified, taxed and untaxed wealth, tax loss
  05_generate_outputs.do   <- country, centre and global tables
  06_bilateral_output.do   <- owner × centre files
  fgmz_bilateral/          <- builds the owner × centre input from the EU Tax Observatory's code
  helpers/                 <- country-name harmonisation; the chapter's tables (with Table A2) and figures (Figures 4.1–4.6)
  build_chapter.sh         <- rebuilds the chapter's tables and figures
data/raw/                  <- every input, with sources and terms (README.md)
results/                   <- the published results: pipeline outputs, the chapter's tables and figures
assets/fonts/              <- Work Sans (SIL Open Font License), used in the figures
```

<br />

<!-- BUILT WITH -->
## Built with

* [Stata 17](https://www.stata.com/) · [Python 3](https://www.python.org/) · [pandas](https://pandas.pydata.org/) · [NumPy](https://numpy.org/) · [Matplotlib](https://matplotlib.org/)

<br />

<!-- ACKNOWLEDGEMENTS -->
## Acknowledgements

This package builds on the work of Faye, Godar, Moura and Zucman (2025), *Global Offshore Wealth, 2001–2023* (EU Tax Observatory Working Paper No. 41), and on their replication package, [eutaxobservatory/global-offshore-wealth-2001-2023](https://github.com/eutaxobservatory/global-offshore-wealth-2001-2023). Their estimates of the offshore wealth of each owner country and of the wealth held in each financial centre, from the EU Tax Observatory's [Atlas of the Offshore World](https://atlas-offshore-world.org), are the starting point of every estimate here. `src/fgmz_bilateral/` reruns their code to split each owner country's wealth across the financial centres. We thank the authors for making their data and code public.

<br />

<!-- LICENCE -->
## Licence

The code is released under the [MIT licence](LICENSE). The data compiled by the Tax Justice Network and the results are released under [CC BY 4.0](LICENSE-DATA.md). Third-party data remain under their providers' terms, listed in [`data/raw/README.md`](data/raw/README.md).

<br />

<!-- CITATION -->
## Citation

Tax Justice Network (2026). *The State of Tax Justice 2026*, chapter 4 (offshore wealth): replication package. https://github.com/Tax-Justice-Network/state-of-tax-justice-2026-offshore-wealth

The report and its methodological note (Schultz, A. (2026). *Offshore tax abuse: Methodological note for the State of Tax Justice 2026*): https://taxjustice.net/reports/the-state-of-tax-justice-2026/

Main sources:
- Faye, S., Godar, S., Moura, C. and Zucman, G. (2025). *Global Offshore Wealth, 2001–2023*. EU Tax Observatory Working Paper No. 41. Replication package: https://github.com/eutaxobservatory/global-offshore-wealth-2001-2023
- Boas, H., Collin, M., Godar, S., Moura, C. and Økland, A. (2025). *Assessing the coverage of the automatic exchange of information under the CRS*. EU Tax Observatory Report No. 7.
- Boas, H. F., Collin, M., Godar, S., Moura, C. and Økland, A. (2026). *Did Automatic Exchange of Information End Bank Secrecy? Evidence from Aggregate Administrative Data*. Skatteforsk Working Paper No. 32.
- Boas, H. F., Johannesen, N., Kreiner, C. T., Larsen, L. and Zucman, G. (2026). *Taxing Capital in a Globalized World: The Effects of Automatic Information Exchange*.
- Bomare, J. and Collin, M. (2025). *When Bankers Become Informants: Behavioral Effects of Automatic Exchange of Information*. EU Tax Observatory Working Paper No. 33.
- Johannesen, N. and Zucman, G. (2014). The End of Bank Secrecy? An Evaluation of the G20 Tax Haven Crackdown. *American Economic Journal: Economic Policy* 6(1).
- Alstadsæter, A., Johannesen, N. and Zucman, G. (2019). Tax Evasion and Inequality. *American Economic Review* 109(6).
