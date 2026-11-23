"""The figures of the offshore chapter (Figures 4.1-4.5 of the report: fig7, fig10w, fig7b, fig10, fig13) and their data,
from the chapter tables written by results_tables_crs.py.
Usage: python3 src/helpers/figures_crs_results.py <results_dir> <figures_dir> (see src/build_chapter.sh)
"""
import sys

import sys as _sys
from pathlib import Path as _Path

import matplotlib
import pandas as pd

matplotlib.use("Agg")
import matplotlib.pyplot as plt

_sys.path.insert(0, str(_Path(__file__).resolve().parent))
from _brand import (BLUE, BROWN, EARTH_GREEN, GOLD, INK, PURPLE, RED, TEAL, apply_tjn_style, shade, tint)  # noqa: E402

apply_tjn_style()                       # Work Sans, brand palette, white background, light y-grid
R, F = sys.argv[1], sys.argv[2]
M = 2.6 / 53.1                          # reported, owner-identified wealth that stays untaxed (BJKLZ 2026, Table 5)
INK2, MUTED, SURFACE, GRID = "#4A4A4A", "#8A8A8A", "#FFFFFF", "#E8E8E8"
# Visible wealth in earth green, hidden wealth in purple, in shades; textures (colour-blind redundancy) distinguish
# sub-categories within a shade. (colour, hatch)
TX = {"crs": (EARTH_GREEN, None), "self": (EARTH_GREEN, "////")}
UN = {"id": (tint(PURPLE, 0.3), None), "noowner": (tint(PURPLE, 0.3), ".."), "hidden": (tint(PURPLE, 0.65), None), "fatca": (tint(PURPLE, 0.65), "////"),
      "choose": (PURPLE, ".."), "cutoff": (PURPLE, "xx"), "usnosend": (PURPLE, "////"),
      "notactive": (PURPLE, "\\\\"), "outside": (PURPLE, None)}
C = {"taxed": EARTH_GREEN, "untaxed_id": tint(PURPLE, 0.3), "cov_unid": GOLD, "uncov": tint(PURPLE, 0.65)}   # gold only in filled bands
GROUPS = ["High income", "Upper middle income", "Lower middle income", "Low income"]
# low income in a darkened gold, which fits the purple and green design of the report and stands apart from the red
# of lower middle income
GC = {"High income": PURPLE, "Upper middle income": EARTH_GREEN, "Lower middle income": RED, "Low income": shade(GOLD, 0.25)}   # lines and labels
GCB = {**GC, "Lower middle income": GOLD}                                                                               # filled bars
# colour-blind redundancy (brand guide): every line series also carries its own dash pattern and marker
GS = {"High income": ("-", "o"), "Upper middle income": ("--", "s"), "Lower middle income": ("-.", "^"), "Low income": (":", "D")}
RS_LIST = [("-", "o"), ("--", "s"), ("-.", "^"), (":", "D"), ((0, (5, 1, 1, 1)), "v"), ((0, (1, 1)), "P"), ((0, (3, 1, 3, 1, 1, 1)), "X")]
def lsm(i):
    return RS_LIST[i % len(RS_LIST)]
def paint(polys, keys):
    for poly, k in zip(polys, keys):
        col, h = ({**TX, **UN})[k]
        poly.set_facecolor(col); poly.set_alpha(1)
        if h:
            poly.set_hatch(h); poly.set_edgecolor("white"); poly.set_linewidth(0)
plt.rcParams.update({"font.size": 9, "axes.titleweight": "normal"})

# Text sizes: the chapter figures are printed at the text width (16.5 cm), so their text is sized to
# print at about 7.5pt and never below 6.5pt, like the other figures of the report. Currency labels read "US$", as in the
# text of the report (a backslash keeps matplotlib from reading the dollar sign as the start of a formula).
def style(ax, ylab=""):
    for s in ("top", "right"):
        ax.spines[s].set_visible(False)
    ax.yaxis.grid(True, color=GRID, linewidth=0.8)
    ax.set_axisbelow(True)
    ax.tick_params(length=0)
    ax.set_ylabel(ylab, color=INK2)

def save(fig, name):
    fig.savefig(f"{F}/{name}", dpi=200, facecolor=SURFACE, bbox_inches="tight")
    print("saved", name)

# 7. Offshore wealth 2001-2023, USD trillion: Figure 4.1 (fig7) shows the total, Figure 4.3 (fig7b) the split into
# wealth visible to tax authorities and hidden wealth, with dashed lines at the start of automatic exchange of
# information. Visible: taxed wealth plus the 4.9% of identified wealth that stays untaxed (visible, though untaxed);
# hidden: the rest. The tax loss falls on the hidden wealth and on that 4.9%
w = pd.read_csv(f"{R}/fgmz_global_offshore_wealth_2001_2023.csv").set_index("year")
gb = pd.read_csv(f"{R}/global_by_year.csv").set_index("year")
p7 = pd.read_csv(f"{R}/pairs_owner_centre_year.csv")
tot = w.offshore_wealth_bn / 1000
vis = ((gb.taxed + p7.groupby("year").own.sum() * M).reindex(w.index) / 1000).fillna(0.075 * tot)   # before 2016: the assumed 5–10% only
# FATCA from its first year of reports: in 2014 and 2015, US owners' wealth in each centre is reported
# and identified at the centre's share of 2016 (the pipeline's first year); taxed: identified less the 4.9%, at least 7.5%
p16 = p7.query("year == 2016 and o == 'USA'").set_index("j")
us = pd.read_csv(f"{R}/us_owner_wealth_by_centre_2014_2015.csv")
us["ident"] = us.wealth_bn * us.centre_iso3.map(p16.own / p16.W).fillna(0)
us = us.groupby("year")[["wealth_bn", "ident"]].sum()
us_vis = (us.ident * (1 - M)).clip(lower=0.075 * us.wealth_bn) + us.ident * M
vis.loc[us.index] = (0.075 * (w.offshore_wealth_bn.loc[us.index] - us.wealth_bn) + us_vis) / 1000
hid = tot - vis
# visible, but probably not taxed: the 4.9% of identified wealth, shown between hidden and visible
vun = (p7.groupby("year").own.sum() * M).reindex(w.index).fillna(0) / 1000
vun.loc[us.index] = us.ident * M / 1000
pd.DataFrame({"offshore_wealth_tn": tot, "visible_tn": vis, "of_which_almost_certainly_untaxed_tn": vun,      # data of
              "hidden_tn": hid}).round(4).to_csv(f"{F}/fig7b_data.csv")                                     # Figure 3
# first year of accounts reported under FATCA (2014, first exchanged in 2015) and under the CRS (2016, early adopters,
# first exchanged in 2017): dashed line before that year's bar, label at height yl
AEOI = [(2014, 14.2, "FATCA (US):\nreports from 2014"), (2016, 12.4, "CRS (OECD):\nreports from 2016")]

def years_axis(ax):
    ax.set_xlim(2000.3, 2023.7); ax.set_xticks(range(2001, 2024)); ax.tick_params(axis="x", labelsize=8.2)

def total_labels(ax):
    for y in w.index:
        ax.text(y, tot[y] + 0.2, f"{tot[y]:.1f}", ha="center", fontsize=8.2, color=INK)

def aeoi_lines(ax, top=None):
    """Dashed lines at the start of automatic exchange; labelled unless top (the panel's height) is given."""
    for x, yl, lab in AEOI:
        ax.plot([x - 0.5] * 2, [0, top or yl + 0.75], color=MUTED, linewidth=0.8, linestyle=(0, (3, 2)), zorder=0.8)
        if top is None:
            ax.text(x - 0.38, yl, lab, ha="left", va="center", fontsize=8.5, color=INK2, linespacing=1.15)

def split_panel(ax):
    ax.bar(w.index, hid, color=PURPLE, width=0.74, label="Hidden")               # hidden below, visible above
    ax.bar(w.index, vun, bottom=hid, color=tint(EARTH_GREEN, 0.5), hatch="xxx", edgecolor=PURPLE, linewidth=0, width=0.74,   # cross-hatch:
           # "hatched" is the self-declared part in Figure 4.2
           label="Visible, but almost certainly not taxed (minimum)")      # a minimum
    ax.bar(w.index, vis - vun, bottom=hid + vun, color=tint(EARTH_GREEN, 0.5), width=0.74,     # lighter green, so the hidden
           label="Visible to tax authorities")                                                # part stands out
    years_axis(ax); style(ax, r"US\$ trillion"); ax.set_ylim(0, 15); total_labels(ax)
    for y in w.index:
        if hid[y] >= 1.2:
            ax.text(y, hid[y] / 2, f"{hid[y]:.1f}", ha="center", va="center", fontsize=8.2, color="white")
        if vis[y] - vun[y] >= 1.2:
            ax.text(y, hid[y] + vun[y] + (vis[y] - vun[y]) / 2, f"{vis[y] - vun[y]:.1f}", ha="center", va="center", fontsize=8.2, color=INK)
    aeoi_lines(ax)
    h7, l7 = ax.get_legend_handles_labels()
    ax.legend(h7[::-1], l7[::-1], loc="upper left", frameon=False, fontsize=9, labelcolor=INK)     # legend top-down like the stack

# 7a. Figure 4.1: the total, in the purple of the hidden part of Figure 4.3 (7b), so that Figure 4.3 adds the green of
# the visible part to the same bars
fig, ax = plt.subplots(figsize=(9.5, 4.8))
ax.bar(w.index, tot, color=PURPLE, width=0.74)
years_axis(ax); style(ax, r"US\$ trillion"); ax.set_ylim(0, 15); total_labels(ax)
fig.subplots_adjust(top=0.95)
save(fig, "fig7_offshore_wealth_2001_2023.png")

# 7b. Figure 4.3: visible and hidden
fig, ax = plt.subplots(figsize=(9.5, 4.8))
split_panel(ax)
fig.subplots_adjust(top=0.95)
save(fig, "fig7b_visible_hidden_2001_2023.png")

# 10. Figure 4.4: revealed by AEOI vs excluded from it, by owner income group (stacked shares per group)
import json
wb = json.load(open(f"{R}/../../../" + "/dev/null")) if False else None
pr = pd.read_csv(f"{R}/pairs_owner_centre_year.csv")
oi_map = pd.read_csv(f"{R}/owners_by_country.csv")[["o"]].drop_duplicates()
inc_map = pd.read_csv(f"{R}/owner_income_groups.csv").set_index("o").inc_o.to_dict()
pr["inc"] = pr.o.map(inc_map)
pr["crs_taxed"] = pr.own * (1 - M); pr["topup"] = (pr.taxed - pr.crs_taxed).clip(lower=0)
oy = pr.groupby(["o", "year"]).agg(W=("W", "sum"), ct=("crs_taxed", "sum"), tu=("topup", "sum"))
oy["topup5"] = (0.05 * oy.W - oy.ct).clip(lower=0)
pr = pr.merge(oy[["tu", "topup5"]].rename(columns={"tu": "tu_o"}), left_on=["o", "year"], right_index=True, how="left")
pr["topup5"] = pr.topup * (pr.topup5 / pr.tu_o.where(pr.tu_o > 0, 1.0))
pr["noagr"] = ((pr["cov"] <= 0) & (pr.crs_in_effect == 0) & (pr.us_in_us_cell == 0)).astype(int)
def bands(v):
    W = v.W.sum()
    return pd.Series({
        "Revealed, owner identified": v.own.sum() / W * 100,      # visible; whether it is taxed depends on the authority
        "Probably self-declared despite no exchange": v.topup.sum() / W * 100,
        "Reported without identified owner": (v["cov"] - v.own).sum() / W * 100,
        "Exchange in place, not reported": ((v.W - v["cov"])[v.noagr == 0] - v.topup[v.noagr == 0]).sum() / W * 100,
        "Country chooses not to receive information": (v.W[v.choose == 1] - v.topup[v.choose == 1]).sum() / W * 100,   # the owner's country, not the owner
        "No information received": (v.W[(v.noagr == 1) & (v.choose == 0)] - v.topup[(v.noagr == 1) & (v.choose == 0)]).sum() / W * 100,
        "_noeoi_total": v.W[v.noagr == 1].sum() / W * 100})
pr["choose"] = (pr.reason == "Owner sends but does not receive (no or little income tax)").astype(int)
cols = [C["taxed"], tint(EARTH_GREEN, 0.55), C["cov_unid"], C["uncov"], "#B0B0B0", "#6B6B6B"]
# two rows of two panels, so that the text stays legible when the figure is printed at the text width
fig, axes = plt.subplots(2, 2, figsize=(9.5, 7.8), sharey=True)
axes = axes.ravel()
F10 = []                                                         # data of Figure 4
for ax, gname in zip(axes, GROUPS):
    x = pr[pr.inc == gname].groupby("year").apply(bands, include_groups=False)
    F10.append(x.assign(income_group=gname))
    noeoi = x.pop("_noeoi_total")
    x = x[x.columns[::-1]]                                      # hidden bands below, visible above
    polys = ax.stackplot(x.index, x.T.values, labels=x.columns, colors=cols[::-1], alpha=0.95)
    paint(polys, ["outside", "choose", "hidden", "noowner", "self", "crs"])
    tl = x["Revealed, owner identified"] + x["Probably self-declared despite no exchange"]; t23 = tl[2023]
    assumed_only = x["Revealed, owner identified"][2023] < 0.5          # nothing revealed: the visible share is the assumption itself
    labs = [(100 - t23, 100, "visible 5–10%" if assumed_only else f"visible {t23:.0f}%"),
            (0, 100 - t23, "hidden\n90–95%" if assumed_only else f"hidden {100 - t23:.0f}%")]
    for (y0, y1, lab), colr in zip(labs, [TX["crs"][0], UN["outside"][0]]):
        ax.plot([2023.12, 2023.12], [y0 + 0.8, y1 - 0.8], color=colr, lw=2.6, clip_on=False, solid_capstyle="butt")
        ax.text(2023.2, (y0 + y1) / 2, lab, fontsize=9.5, color=colr, va="center", ha="left", clip_on=False)
    w23 = pr[(pr.inc == gname) & (pr.year == 2023)].W.sum() / 1000
    ax.set_title(f"{gname}\nUS\\${w23:.2f}tn offshore in 2023", loc="left", fontsize=10.5)
    ax.set_xlim(2016, 2023); ax.set_ylim(0, 100); ax.set_xticks([2017, 2020, 2023])
    style(ax, "% of the group's offshore wealth" if gname in (GROUPS[0], GROUPS[2]) else "")
    ax.tick_params(labelsize=9.5); ax.yaxis.label.set_size(9.5)
    ex = x["No information received"][2023]
    top_band = x["No information received"].min()      # thinnest point of the dark band over the years
    if top_band >= 11:
        ax.text(2019.5, 3, f"no information received\n{noeoi[2023]:.0f}%", ha="center", va="bottom", fontsize=9.5, color="white", linespacing=1.4)
    else:                                                           # too thin for two lines: one line
        ax.text(2019.5, 2.5, f"no information received: {noeoi[2023]:.0f}%", ha="center", va="bottom", fontsize=9.5, color="white")
    ax.text(2016.15, 97, "", fontsize=1)
pd.concat(F10).rename(columns={"_noeoi_total": "No exchange of information (all)"}).reset_index().round(3).to_csv(
    f"{F}/fig10_data.csv", index=False)
h, l = axes[0].get_legend_handles_labels()
fig.legend(h[::-1], l[::-1], loc="lower center", ncol=2, frameon=False, fontsize=9.5, labelcolor=INK, bbox_to_anchor=(0.5, -0.02))
fig.subplots_adjust(top=0.92, bottom=0.17, wspace=0.42, hspace=0.42, right=0.88)
save(fig, "fig10_revealed_vs_excluded_income_groups.png")

# 13. Figure 4.5: tax loss by owner income group, index 2016 = 100
oi = pd.read_csv(f"{R}/owners_by_income_group.csv"); oi = oi[oi.inc_o.isin(GROUPS)]
gl = pd.read_csv(f"{R}/global_by_year.csv").set_index("year")
fig, ax = plt.subplots(figsize=(9.5, 4.8))
ends = []
for gname in GROUPS:
    x = oi[oi.inc_o == gname].set_index("year").tax_loss
    idx = x / x[2016] * 100
    ax.plot(idx.index, idx, color=GC[gname], lw=2.4, ls=GS[gname][0], marker=GS[gname][1], ms=3.5, label=f"{gname} (US\\${x[2023]:.1f}bn in 2023)")
    ends.append([idx[2023], gname, GC[gname]])
gidx = gl.tax_loss / gl.tax_loss[2016] * 100
ax.plot(gidx.index, gidx, color=INK, lw=1.8, ls="--", marker="x", ms=4, label=f"World (US\\${gl.tax_loss[2023]:.0f}bn in 2023)")
ends.append([gidx[2023], "World", INK])
ends.sort(key=lambda e: e[0])
for i in range(1, len(ends)):
    if ends[i][0] - ends[i - 1][0] < 5.5:
        ends[i][0] = ends[i - 1][0] + 5.5
for ypos, gname, col in ends:
    v = (oi[(oi.inc_o == gname) & (oi.year == 2023)].tax_loss.iloc[0] / oi[(oi.inc_o == gname) & (oi.year == 2016)].tax_loss.iloc[0] * 100) if gname != "World" else gidx[2023]
    # the group's name with its end value, so that a reader who cannot tell the colours apart can still tell the lines apart
    ax.text(2023.15, ypos, f"{gname} {v:.0f}", color=col, fontsize=9.5, va="center", clip_on=False)
ax.axhline(100, color="#B0B0B0", lw=0.8, ls=":")
# the axis starts at 40 to make the changes visible
ax.set_xlim(2016, 2023.25); ax.set_xticks(range(2016, 2024)); style(ax, "Tax loss, index 2016 = 100"); ax.set_ylim(40, 145)
ax.tick_params(labelsize=9.5); ax.yaxis.label.set_size(9.5)
ax.legend(frameon=False, fontsize=9.5, loc="lower left", labelcolor=INK, title="Owner income group", title_fontsize=9.5)
fig.subplots_adjust(top=0.95, right=0.8)
save(fig, "fig13_tax_loss_index_income_groups.png")

# 10w. Figure 4.2: the composition of fig10 for all owners together (one panel)
pr = pd.read_csv(f"{R}/pairs_owner_centre_year.csv")
pr["crs_taxed"] = pr.own * (1 - M); pr["topup"] = (pr.taxed - pr.crs_taxed).clip(lower=0)
pr["noagr"] = ((pr["cov"] <= 0) & (pr.crs_in_effect == 0) & (pr.us_in_us_cell == 0)).astype(int)
pr["choose"] = (pr.reason == "Owner sends but does not receive (no or little income tax)").astype(int)
x = pr.groupby("year").apply(bands, include_groups=False)
x.rename(columns={"_noeoi_total": "No exchange of information (all)"}).round(3).to_csv(f"{F}/fig10w_data.csv")   # data of Figure 2
noeoi = x.pop("_noeoi_total")
x = x[x.columns[::-1]]                                          # hidden bands below, visible above
fig, ax = plt.subplots(figsize=(9.5, 5.2))
polys = ax.stackplot(x.index, x.T.values, labels=x.columns, colors=cols[::-1], alpha=0.95)
paint(polys, ["outside", "choose", "hidden", "noowner", "self", "crs"])
ax.set_xlim(2016, 2023); ax.set_ylim(0, 100); ax.set_xticks(range(2016, 2024)); style(ax, "% of global offshore wealth")
ax.tick_params(labelsize=10); ax.yaxis.label.set_size(10)
ax.text(2019.5, 2.5, f"no information received: {noeoi[2023]:.0f}%", ha="center", va="bottom", fontsize=10, color="white")
tl = x["Revealed, owner identified"] + x["Probably self-declared despite no exchange"]; t23 = tl[2023]
for (y0, y1, lab), colr in zip([(100 - t23, 100, f"visible to\ntax authorities\n{t23:.0f}%"),     # full label, as in Figure 4.3
                                (0, 100 - t23, f"hidden {100 - t23:.0f}%")], [TX["crs"][0], UN["outside"][0]]):
    ax.plot([2023.06, 2023.06], [y0 + 0.6, y1 - 0.6], color=colr, lw=2.6, clip_on=False, solid_capstyle="butt")
    ax.text(2023.12, (y0 + y1) / 2, lab, fontsize=10, color=colr, va="center", ha="left", clip_on=False)
W = pr.groupby("year").W.sum()
for y in x.index:
    ax.text(y, 101, f"US\\${W[y]/1000:.1f}tn", ha="left" if y == 2016 else "right" if y == 2023 else "center", va="bottom", fontsize=9, color=INK2)
h, l = ax.get_legend_handles_labels()
fig.legend(h[::-1], l[::-1], loc="lower center", ncol=2, frameon=False, fontsize=9.5, labelcolor=INK, bbox_to_anchor=(0.5, -0.06))
fig.subplots_adjust(top=0.92, bottom=0.2, right=0.86)   # room for the two-row legend
save(fig, "fig10w_revealed_vs_excluded_world.png")
