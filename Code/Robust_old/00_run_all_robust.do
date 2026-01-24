****************************************************
* 00_run_all_robust.do
* Master file: Run all toggle combinations
****************************************************

clear all
set more off

global code "/Volumes/SSD PRO/Github-forks/Chp3-EnergyIneq/Code"

* Close any open log file, then open new log file
capture log close
log using "$code/Robust/00_run_all_robust.log", replace

display _n "========================================"
display "ROBUST REPLICATION: ALL TOGGLE COMBINATIONS"
display "========================================" _n

****************************************************
* Step 1: Merge CGK shocks (run once)
****************************************************
display _n "=== Step 1: Merging CGK Shocks ==="
do "$code/Robust/01_merge_cgk_shocks.do"

****************************************************
* Step 2: Run each toggle combination
****************************************************
display _n "=== Step 2: Running All Toggle Combinations ==="

* Baseline
display _n "--- Running Baseline ---"
do "$code/Robust/05_baseline.do"

* Deflate
display _n "--- Running Deflate ---"
do "$code/Robust/06_deflate.do"

* DeflateEquiv
display _n "--- Running DeflateEquiv ---"
do "$code/Robust/07_deflate_equiv.do"

* DeflateEquivFW
display _n "--- Running DeflateEquivFW ---"
do "$code/Robust/08_deflate_equiv_fw.do"

* DeflateEquivFWWinsor
display _n "--- Running DeflateEquivFWWinsor ---"
do "$code/Robust/09_deflate_equiv_fw_winsor.do"

* DeflateEquivFWWinsorZero
display _n "--- Running DeflateEquivFWWinsorZero ---"
do "$code/Robust/10_deflate_equiv_fw_winsor_zero.do"

* CGKFull
display _n "--- Running CGKFull ---"
do "$code/Robust/11_cgk_full.do"

****************************************************
* Step 3: Combine all Gini results
****************************************************
display _n "=== Step 3: Combining All Gini Results ==="

global robust_data "/Volumes/SSD PRO/Github-forks/Chp3-EnergyIneq/Code/Robust/Data"

* Load first combination
use "$robust_data/temp_gini_deflate0_equiv0_aw_winsor0_zerosinclude_resid0_ineqdeco.dta", clear
erase "$robust_data/temp_gini_deflate0_equiv0_aw_winsor0_zerosinclude_resid0_ineqdeco.dta"

* Append remaining combinations
local toggle_files "deflate1_equiv0_aw_winsor0_zerosinclude_resid0_ineqdeco deflate1_equiv1_aw_winsor0_zerosinclude_resid0_ineqdeco deflate1_equiv1_fw_winsor0_zerosinclude_resid0_ineqdeco deflate1_equiv1_fw_winsor1_zerosinclude_resid0_ineqdeco deflate1_equiv1_fw_winsor1_zeroexclude_resid0_ineqdeco deflate1_equiv1_fw_winsor1_zeroexclude_resid0_ineqdec0"

foreach sig of local toggle_files {
    capture confirm file "$robust_data/temp_gini_`sig'.dta"
    if !_rc {
        append using "$robust_data/temp_gini_`sig'.dta"
        erase "$robust_data/temp_gini_`sig'.dta"
        display "  Appended: `sig'"
    }
    else {
        display "  WARNING: File not found: `sig'"
    }
}

* Sort and save master file
sort toggle_sig year quarter
save "$robust_data/gini_robust_all_combos.dta", replace

display _n "=== Master File Created ==="
display "Saved: $robust_data/gini_robust_all_combos.dta"
display "Total observations: " _N

log close

display _n "========================================"
display "ALL TOGGLE COMBINATIONS COMPLETED"
display "========================================"
