"""Result tables for the offshore chapter of The State of Tax Justice 2026: what the CRS makes visible (covered),
owner-identified, taxed and untaxed wealth, globally, by owner income group and by owner country; the owners'
income groups; the share of each owner region's offshore wealth with exchange of information.

Input: the pair file written by the Stata pipeline (06_bilateral_output.do,
$data_final/pairs_owner_centre_year_<label>.csv, USD bn). The World Bank country file is
https://api.worldbank.org/v2/country?format=json&per_page=400.

Usage: python3 src/helpers/results_tables_crs.py <pairs.csv> <wb_countries.json> <out_dir>"""
import json
import sys

import pandas as pd

d = pd.read_csv(sys.argv[1])
wb = json.load(open(sys.argv[2]))[1]
inc = {c["id"]: c["incomeLevel"]["value"] for c in wb if c["region"]["value"] != "Aggregates"}
reg = {c["id"]: c["region"]["value"].strip() for c in wb if c["region"]["value"] != "Aggregates"}
inc.update({"TWN": "High income", "JEY": inc["CHI"], "GGY": inc["CHI"]})
reg.update({"TWN": "East Asia & Pacific", "JEY": reg["CHI"], "GGY": reg["CHI"]})
INC = ["High income", "Upper middle income", "Lower middle income", "Low income"]
out = sys.argv[3]
d["inc_o"], d["reg_o"] = d.o.map(lambda k: inc.get(k, "n.c.")), d.o.map(lambda k: reg.get(k, "n.c."))
V = ["W", "cov", "own", "taxed", "untaxed", "tax_loss"]
LAB = {"W": "offshore_wealth", "cov": "covered_by_crs", "own": "owner_identified", "taxed": "taxed", "untaxed": "untaxed",
       "tax_loss": "tax_loss"}

def table(by, name):
    t = d.groupby(["year"] + by)[V].sum().rename(columns=LAB).reset_index()
    t["covered_%"] = t.covered_by_crs / t.offshore_wealth * 100
    t["owner_identified_%"] = t.owner_identified / t.offshore_wealth * 100
    t["taxed_%"] = t.taxed / t.offshore_wealth * 100
    t["untaxed_%"] = t.untaxed / t.offshore_wealth * 100
    t.round(3).to_csv(f"{out}/{name}.csv", index=False)
    return t

g = table([], "global_by_year")
print("GLOBAL (USD bn)\n", g.set_index("year").round(1).to_string())
oi = table(["inc_o"], "owners_by_income_group")
oo = table(["o"], "owners_by_country")


# owner income groups (all owners in the pair file)
pd.DataFrame({"o": sorted(d.o.unique())}).assign(inc_o=lambda x: x.o.map(lambda k: inc.get(k, "n.c."))).to_csv(
    f"{out}/owner_income_groups.csv", index=False)

# exchange and coverage by owner region: share of the group's offshore wealth in a pair with
# active exchange (CRS active, or covered through FATCA), reported, and reported with an identified owner
d["exch"] = d.W.where((d.crs_in_effect == 1) | (d["cov"] > 0), 0.0)
for col, nm in [("reg_o", "reg")]:
    e = d.groupby(["year", col]).agg(W=("W", "sum"), E=("exch", "sum"), C=("cov", "sum"), O=("own", "sum")).reset_index()
    e = e[e[col] != "n.c."]                              # territories without a World Bank classification
    e = pd.DataFrame({"year": e.year, nm: e[col], "exch%": e.E / e.W * 100, "cov%": e.C / e.W * 100, "own%": e.O / e.W * 100})
    e.round(2).to_csv(f"{out}/exchange_and_coverage_by_{nm}.csv", index=False)

print("\nTables written to", out)
