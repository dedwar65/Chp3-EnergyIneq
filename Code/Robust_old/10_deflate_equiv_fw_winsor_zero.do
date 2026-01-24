****************************************************
* 10_deflate_equiv_fw_winsor_zero.do
* Tier 2b: Add Zero Exclusion
****************************************************

clear all
set more off

global code "/Volumes/SSD PRO/Github-forks/Chp3-EnergyIneq/Code"

display _n "========================================"
display "TIER 2B: ADD ZERO EXCLUSION"
display "========================================" _n

* Compute Ginis
do "$code/Robust/02_compute_gini_robust.do" ///
    1 1 "fw" 1 "exclude" 0 "ineqdeco" "DeflateEquivFWWinsorZero"

* Run Local Projections
local toggle_sig = "deflate1_equiv1_fw_winsor1_zeroexclude_resid0_ineqdeco"
do "$code/Robust/03_local_projections_robust.do" "`toggle_sig'" "DeflateEquivFWWinsorZero"

display _n "Completed: DeflateEquivFWWinsorZero"
