"""The offshore columns of Table A2 of The State of Tax Justice 2026: the tax revenue lost to offshore wealth in 2023 by
each owner country (losses suffered) and caused by each financial centre where the wealth is held (losses caused),
in US$ million at 2025 prices, as in the report. The losses caused are the sum over the owner x centre pairs of each
centre, so that they add up to the losses suffered of all owner countries.

Usage: python3 src/helpers/table_a2_offshore.py <pairs_owner_centre_year.csv> <offshore_wealth_owned.csv>
           <offshore_wealth_stored.csv> <out_csv>
"""
import sys

import pandas as pd

PAIRS, OWNED, STORED, OUT = sys.argv[1:5]
YEAR = 2023
DEFLATOR = 1.053849             # US$ of 2023 to US$ of 2025 (US GDP deflator), as in the report's totals

p = pd.read_csv(PAIRS)
o = pd.read_csv(OWNED)
o = o[o.year == YEAR].set_index("country_iso3")
c = pd.read_csv(STORED)
caused = p[p.year == YEAR].groupby("j").tax_loss.sum() * 1e3 * DEFLATOR
t = pd.DataFrame({"losses_suffered_usd_m": o.tax_loss * DEFLATOR, "losses_caused_usd_m": caused}).fillna(0)
t.index.name = "iso3"
names = c.set_index("country_iso3").country.to_dict() | o.country.to_dict()
t.insert(0, "country", t.index.map(lambda k: names.get(k, k)))
assert abs(t.losses_suffered_usd_m.sum() - t.losses_caused_usd_m.sum()) < 0.5, "losses caused do not add up to losses suffered"
t = t[(t.losses_suffered_usd_m > 0) | (t.losses_caused_usd_m > 0)].sort_values("losses_suffered_usd_m", ascending=False)
t.round(1).to_csv(OUT)
