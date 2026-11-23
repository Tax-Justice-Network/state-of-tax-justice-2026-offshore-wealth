"""US owners' offshore wealth by financial centre, 2014-2015, USD billion: chapter input for Figure 4.3, which counts
the wealth revealed by FATCA from its first year of reports. From the FGMZ owner x centre table
($data_raw/$fgmz_pairs_file), with owners in the US Minor Outlying Islands counted with the United States as in
03_fgmz_pairs.do.
Usage: python3 src/helpers/us_owner_wealth_2014_2015.py <fgmz pairs csv> <output csv> (see src/build_chapter.sh)
"""
import sys

import pandas as pd

src, out = sys.argv[1:3]
u = pd.read_csv(src)
u = u[u.year.isin([2014, 2015]) & u.owner_iso3.isin(["USA", "UMI"]) & (u.wealth_usd_bn > 0)]
u = u.groupby(["year", "centre_iso3"], as_index=False).wealth_usd_bn.sum().rename(columns={"wealth_usd_bn": "wealth_bn"})
u.to_csv(out, index=False, float_format="%.6f")
print(u.groupby("year").wealth_bn.sum().round(1).to_string())
