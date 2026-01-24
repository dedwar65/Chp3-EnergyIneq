****************************************************
* 09_deflate_equiv_fw_winsor.do
* Tier 2a: Add Winsorization
****************************************************

clear all
set more off

global code "/Volumes/SSD PRO/Github-forks/Chp3-EnergyIneq/Code"

display _n "========================================"
display "TIER 2A: ADD WINSORIZATION"
display "========================================" _n

* Compute Ginis
do "$code/Robust/02_compute_gini_robust.do" ///
    1 1 "fw" 1 "include" 0 "ineqdeco" "DeflateEquivFWWinsor"

* Run Local Projections
local toggle_sig = "deflate1_equiv1_fw_winsor1_zerosinclude_resid0_ineqdeco"
do "$code/Robust/03_local_projections_robust.do" "`toggle_sig'" "DeflateEquivFWWinsor"

display _n "Completed: DeflateEquivFWWinsor"
