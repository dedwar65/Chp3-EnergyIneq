****************************************************
* 00_run_all_robust.do
* New, lightweight robust pipeline:
* - Uses existing combined Gini panel (1990–2023)
* - Restricts to 1990–2008
* - Merges in Greenbook Romer–Romer shocks (sh_rr)
* - Runs local projections for 4 Ginis with sh_rr
****************************************************

clear all
set more off

* ---- Globals ----
global code   "/Volumes/SSD PRO/Github-forks/Chp3-EnergyIneq/Code"
global deriv  "/Volumes/SSD PRO/Github-forks/Chp3-EnergyIneq/Code/Data/CEX/derived"
global robust "/Volumes/SSD PRO/Github-forks/Chp3-EnergyIneq/Code/Robust"

global robust_data    "$robust/Data"
global robust_figures "$robust/Figures"
global robust_tables  "$robust/Tables"

* Ensure output directories exist
capture mkdir "$robust_data"
capture mkdir "$robust_figures"
capture mkdir "$robust_tables"

* Open master log
capture log close
log using "$robust/00_run_all_robust.log", replace

display _n "========================================"
display "ROBUST BASELINE PIPELINE (RR shocks only)"
display "========================================" _n

****************************************************
* 1. Build baseline Gini panel for 1990–2008
****************************************************

do "$robust/01_build_gini_baseline.do"

****************************************************
* 2. Merge Greenbook RR shocks (sh_rr)
****************************************************

do "$robust/02_merge_rr_shocks_baseline.do"

****************************************************
* 3. Run local projections (RR → 4 Ginis)
****************************************************

do "$robust/03_local_projections_rr_baseline.do"

display _n "========================================"
display "ROBUST BASELINE PIPELINE COMPLETE"
display "========================================" _n
display "Input Gini panel: $robust_data/gini_baseline_1990_2008_quarterly.dta"
display "Merged data:      $robust_data/gini_rr_merged_baseline.dta"
display "Tables:           $robust_tables/"
display "Figures:          $robust_figures/"
display "========================================" _n

* Close log file (use capture in case it was already closed by a sub-do file)
capture log close
