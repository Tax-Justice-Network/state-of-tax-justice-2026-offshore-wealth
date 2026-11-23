* TJN run of the FGMZ (2025) replication code, steps 03-07, for the owner x centre split.
* Paths point to this run folder; raw-data links to a local copy of the FGMZ replication package.
clear all
set more off
set graphics off
global root "__RUN__"
global do "$root/code"
global work "$root/work-data"
global raw "$root/raw-data"
global fig "$root/figures"
global tables "$root/tables"
global temp "$root/temp"
* Stata add-ons used by FGMZ, installed into this run folder only
sysdir set PLUS "$root/ado/plus"
sysdir set PERSONAL "$root/ado/personal"
foreach p in isocodes fastreshape mmerge carryforward gtools wbopendata {
    capture which `p'
    if _rc ssc install `p', replace
}
* rebuild the Mata library index so add-ons installed into this folder (gtools) load
mata: mata mlib index
