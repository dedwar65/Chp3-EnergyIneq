****************************************************
* 07_deflate_equiv.do
* Tier 1b: Deflation + Equivalence Scale ON
****************************************************

clear all
set more off

global code "/Volumes/SSD PRO/Github-forks/Chp3-EnergyIneq/Code"

display _n "========================================"
display "TIER 1B: DEFLATION + EQUIVALENCE SCALE ON"
display "========================================" _n

* Compute Ginis
do "$code/Robust/02_compute_gini_robust.do" ///
    1 1 "aw" 0 "include" 0 "ineqdeco" "DeflateEquiv"

* Run Local Projections
local toggle_sig = "deflate1_equiv1_aw_winsor0_zerosinclude_resid0_ineqdeco"
do "$code/Robust/03_local_projections_robust.do" "`toggle_sig'" "DeflateEquiv"

display _n "Completed: DeflateEquiv"
