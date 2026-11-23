"""Tax revenue lost to offshore wealth by negotiation bloc, 2023: the counterpart of Figure 3 of the corporate chapter
(Figure 2.3 of the report), with the same blocs and order: the loss in
US$ bn (current prices, as in this chapter, or 2025 prices). Writes the figure, the bloc table and the losses by year.
Usage: python3 src/helpers/figure_blocs_tax_loss.py <offshore_wealth_owned csv> <bloc_members csv>
           <OECD revenue csv> <out_dir> [year] [comparator] [deflator]
comparator: none (default: one panel), or a second panel with the loss as % of the taxes the same
countries collect, over the members with revenue data (OECD Global Revenue Statistics, general government):
capital (corporate income tax T_1200 plus taxes on property T_4000) or pit (personal income tax T_1100). These two get
the suffixes _capital and _pit. Figure 4.6 of the report is the pit version.
deflator: the factor that converts the year's US$ into 2025 US$ (US GDP deflator, 1.053849 for 2023). With it, the bars
of the losses show 2025 prices, like the report's world total, and the comparison panel keeps the shares of the
current-price amounts, which the conversion does not change.
"""
import sys
from pathlib import Path

import matplotlib
import pandas as pd

matplotlib.use("Agg")
import matplotlib.pyplot as plt

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _brand import INK, PURPLE, apply_tjn_style  # noqa: E402

apply_tjn_style()
OWN, MEM, REV, OUT = sys.argv[1:5]
Y = int(sys.argv[5]) if len(sys.argv) > 5 else 2023
CMP = sys.argv[6] if len(sys.argv) > 6 else "none"
DEFL = float(sys.argv[7]) if len(sys.argv) > 7 else None
PRICES = " at 2025 prices" if DEFL else ""
RIGHT = {"none": None,
         "capital": ("loss_pct_taxes_on_capital", "% of corporate income and property taxes",
                     "Tax revenue lost, % of taxes on capital"),
         "pit": ("loss_pct_pit", "% of personal income tax", "Tax revenue lost, % of personal income tax")}[CMP]
SUFFIX = "" if CMP == "none" else f"_{CMP}"
INK2, GRID = "#4A4A4A", "#E8E8E8"
WORLD = "World"
BLOCS = {"OECD": "oecd", "G77": "g77", "Latin America": "latin_america", "African Group": "african_group", "EU": "eu27"}

o = pd.read_csv(OWN).rename(columns={"country_iso3": "iso3"})
m = pd.read_csv(MEM, comment="#").set_index("iso3")
r = pd.read_csv(REV, comment="#")
r = r[r.unit == "USD_million"].pivot_table(index=["iso3", "year"], columns="code", values="value").reset_index()
d = o[o.year == Y].merge(r, on=["iso3", "year"], how="left")
d["cap"] = d["T_1200"] + d["T_4000"]
d["has_rev"] = d["cap"].notna() & d["_T"].notna()

masks = {WORLD: pd.Series(True, index=d.index)}
masks.update({b: d.iso3.map(m[c]).fillna(0).astype(bool) for b, c in BLOCS.items()})
masks["G77 without China"] = masks["G77"] & (d.iso3 != "CHN")      # table only
rows = []
for b, k in masks.items():
    x = d[k]
    c = x[x.has_rev]
    rows.append(dict(bloc=b, members=int(m[BLOCS[b]].sum()) if b in BLOCS else None, owners_in_data=len(x),
                     owners_with_revenue_data=len(c), tax_loss_bn=x.tax_loss.sum() / 1e3,
                     tax_loss_with_revenue_data_bn=c.tax_loss.sum() / 1e3,
                     cit_bn=c["T_1200"].sum() / 1e3, property_taxes_bn=c["T_4000"].sum() / 1e3,
                     taxes_on_capital_bn=c["cap"].sum() / 1e3, pit_bn=c["T_1100"].sum() / 1e3, total_tax_bn=c["_T"].sum() / 1e3,
                     untaxed_wealth_bn=x.untaxed.sum() / 1e3, offshore_wealth_bn=x.offshore_wealth.sum() / 1e3))
t = pd.DataFrame(rows).set_index("bloc")
t["loss_covered_pct"] = 100 * t.tax_loss_with_revenue_data_bn / t.tax_loss_bn
for col, base in [("pct_taxes_on_capital", "taxes_on_capital_bn"), ("pct_property_taxes", "property_taxes_bn"),
                  ("pct_pit", "pit_bn"), ("pct_total_tax", "total_tax_bn")]:
    t[f"loss_{col}"] = 100 * t.tax_loss_with_revenue_data_bn / t[base]
Path(OUT).mkdir(parents=True, exist_ok=True)
t.round(3).to_csv(f"{OUT}/blocs_{Y}.csv")

# losses by year, all members
by = {}
for b in [WORLD] + list(BLOCS):
    k = pd.Series(True, index=o.index) if b == WORLD else o.iso3.map(m[BLOCS[b]]).fillna(0).astype(bool)
    by[b] = o[k].groupby("year").tax_loss.sum() / 1e3
pd.DataFrame(by).round(3).to_csv(f"{OUT}/blocs_tax_loss_by_year.csv")

# figure: bars as in Figure 2.3 of the report, one sign only, so they point up. Without a comparator one panel
# and no title, as for the other chapter figures
order = [WORLD] + list(BLOCS)
xs = range(len(order))
ticks = [b.replace(" ", "\n") for b in order]
cols = [INK if b == WORLD else PURPLE for b in order]
panels = [(t.loc[order, "tax_loss_bn"] * (DEFL or 1), "{:,.1f}", f"US$ billion{PRICES}, {Y}",
           f"Tax revenue lost, US$ billion{PRICES}")]
if RIGHT:
    panels.append((t.loc[order, RIGHT[0]], "{:.1f}%", f"{RIGHT[1]}, {Y}", RIGHT[2]))
# The two-panel figure is wider than the one-panel figure but printed at the same width, so its text is larger by the
# ratio of the scales at which the two are printed (1.2, so that it prints at about 7.5pt like the other chapter
# figures). Its panel titles carry the units instead of the axis labels.
fs = 1.2 if RIGHT else 1.0
fig, axes = plt.subplots(1, len(panels), figsize=(11, 5.4) if RIGHT else (8, 4.6), squeeze=False)
for ax, (vals, fmt, ylab, title) in zip(axes[0], panels):
    bars = ax.bar(xs, vals, 0.58, color=cols, edgecolor="white", linewidth=0.4)
    for b, v in zip(bars, vals):
        ax.annotate(fmt.format(v), (b.get_x() + b.get_width() / 2, v), xytext=(0, 3), textcoords="offset points",
                    ha="center", va="bottom", fontsize=9.5 * fs, fontweight="bold", color=INK)
    ax.set_xticks(list(xs), ticks, fontsize=9.5 * fs)
    ax.tick_params(axis="y", labelsize=11 * fs)
    if RIGHT:
        ax.set_title(title, loc="left", fontsize=10.5 * fs, fontweight="bold", color=INK)
    else:
        ax.set_ylabel(ylab, color=INK2)
    for s in ("top", "right"):
        ax.spines[s].set_visible(False)
    ax.yaxis.grid(True, color=GRID, linewidth=0.8)
    ax.set_axisbelow(True)
    ax.tick_params(length=0)
    ax.set_ylim(0, vals.max() * 1.15)
fig.tight_layout()
fig.savefig(f"{OUT}/fig_blocs_tax_loss_{Y}{SUFFIX}.png", dpi=200, facecolor="white", bbox_inches="tight")
plt.close(fig)

