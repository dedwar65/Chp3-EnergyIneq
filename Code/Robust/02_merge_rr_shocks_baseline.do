****************************************************
* 02_merge_rr_shocks_baseline.do
* Merge Greenbook Romer–Romer shocks (sh_rr)
* into the baseline Gini panel for 1990–2008.
*
* Inputs:
*   $robust_data/gini_baseline_1990_2008_quarterly.dta
*   /Volumes/SSD PRO/Downloads/replication_folder/source_files/RR_shocks_updated.dta
*
* Output:
*   $robust_data/gini_rr_merged_baseline.dta
****************************************************

clear all
set more off

* Expect globals from 00_run_all_robust.do, but define safe defaults
capture confirm global robust_data
if _rc {
    global robust_data "/Volumes/SSD PRO/Github-forks/Chp3-EnergyIneq/Code/Robust/Data"
}

display _n "=== Merging Greenbook RR shocks (sh_rr) with baseline Ginis ==="

* Load baseline Gini panel (1990–2008)
use "$robust_data/gini_baseline_1990_2008_quarterly.dta", clear

* Keep only years where RR shocks exist (should overlap 1969+, but we trim to 1990–2008)
keep if year >= 1990 & year <= 2008

* Save a copy of key structure
tempfile gini_base
save `gini_base', replace

* Load RR shocks
use "/Volumes/SSD PRO/Downloads/replication_folder/source_files/RR_shocks_updated.dta", clear

* Expect variables: year, quarter, sh_rr
capture confirm variable year quarter sh_rr
if _rc {
    display "ERROR: Expected variables year, quarter, sh_rr not all found in RR_shocks_updated.dta"
    describe
    exit 111
}

* Restrict RR shocks to 1990–2008
keep if year >= 1990 & year <= 2008

* Sort for merge
sort year quarter

tempfile rr
save `rr', replace

* Merge into Gini panel
use `gini_base', clear
sort year quarter

merge 1:1 year quarter using `rr'

display _n "Merge result:"
tab _merge

* Keep only matched observations
keep if _merge == 3
drop _merge

* Sanity check
summarize sh_rr
display "Non-missing sh_rr observations: " r(N)

save "$robust_data/gini_rr_merged_baseline.dta", replace

display "Saved merged Gini + RR shocks to:"
display "  $robust_data/gini_rr_merged_baseline.dta"

