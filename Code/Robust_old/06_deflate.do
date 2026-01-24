****************************************************
* 06_deflate.do
* Tier 1a: Deflation ON
****************************************************

clear all
set more off

global code "/Volumes/SSD PRO/Github-forks/Chp3-EnergyIneq/Code"

display _n "========================================"
display "TIER 1A: DEFLATION ON"
display "========================================" _n

* Compute Ginis
do "$code/Robust/02_compute_gini_robust.do" ///
    1 0 "aw" 0 "include" 0 "ineqdeco" "Deflate"

* Run Local Projections
local toggle_sig = "deflate1_equiv0_aw_winsor0_zerosinclude_resid0_ineqdeco"
do "$code/Robust/03_local_projections_robust.do" "`toggle_sig'" "Deflate"

display _n "Completed: Deflate"
