****************************************************
* 01_build_gini_baseline.do
* Baseline Gini panel for 1990–2008
*
* Uses the final BH + FRED merged dataset from the main pipeline:
*   $deriv/gini_bh_shocks_fred_merged.dta
*
* Keeps:
*   - year, quarter, qdate
*   - 4 Gini measures:
*       gini_core
*       gini_broad
*       gini_fincbtax
*       gini_fsalaryx
*
* Restricts to 1990–2008 and saves into Robust/Data.
****************************************************

clear all
set more off

* Expect globals from 00_run_all_robust.do, but define safe defaults
capture confirm global deriv
if _rc {
    global deriv "/Volumes/SSD PRO/Github-forks/Chp3-EnergyIneq/Code/Data/CEX/derived"
}
capture confirm global robust_data
if _rc {
    global robust_data "/Volumes/SSD PRO/Github-forks/Chp3-EnergyIneq/Code/Robust/Data"
}

display _n "=== Building baseline Gini panel for 1990–2008 ==="

* Start from final BH + FRED merged dataset, which already
* contains Ginis and macro controls used in 06_local_projections.do
use "$deriv/gini_bh_shocks_fred_merged.dta", clear

* Keep only variables needed for LPs (4 Ginis + time vars)
keep year quarter qdate ///
     gini_core gini_broad gini_fincbtax gini_fsalaryx

* Restrict to 1990–2008
keep if year >= 1990 & year <= 2008

* Basic sanity check
summarize year quarter
display "Years in sample (min/max): " r(min) " / " r(max)

* Save to Robust/Data
save "$robust_data/gini_baseline_1990_2008_quarterly.dta", replace

display "Saved baseline Gini panel to:"
display "  $robust_data/gini_baseline_1990_2008_quarterly.dta"

