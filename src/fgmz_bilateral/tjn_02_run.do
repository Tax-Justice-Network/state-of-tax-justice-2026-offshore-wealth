* FGMZ (2025) replication steps needed for the owner x centre split, then the TJN extension.
* Steps 01 (except GDP) and 02 are not needed: the global portfolio gap is taken from the
* published totals (tjn_01_prep.do); step 05 only feeds a variant FGMZ do not publish.
do "__RUN__/tjn_00_setup.do"
do "$do/01-gravity-data-build/1b_import_gdp.do"
do "$do/03-uae-deposits/3-uae-deposits.do"
do "$do/04-bis-deposits-build/4a-import-bis.do"
do "$do/04-bis-deposits-build/4b-build-bis-01-23.do"
do "$do/06-swiss-fiduciary-build/6a-build-fiduciary.do"
do "$do/07-offshore-wealth-analysis/7a-build-offshore.do"
do "$do/07-offshore-wealth-analysis/7b-build-offshore_switzerland.do"
do "$do/07-offshore-wealth-analysis/7c-build-countries.do"
do "$do/08-tjn-bilateral/8a-owner-by-centre.do"
