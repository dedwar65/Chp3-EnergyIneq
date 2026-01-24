****************************************************
* 05_baseline.do
* Baseline: All toggles OFF
****************************************************

clear all
set more off

global code "/Volumes/SSD PRO/Github-forks/Chp3-EnergyIneq/Code"

display _n "========================================"
display "BASELINE: All Toggles OFF"
display "========================================" _n

* Compute Ginis
do "$code/Robust/02_compute_gini_robust.do" ///
    0 0 "aw" 0 "include" 0 "ineqdeco" "Baseline"

* Run Local Projections
local toggle_sig = "deflate0_equiv0_aw_winsor0_zerosinclude_resid0_ineqdeco"
do "$code/Robust/03_local_projections_robust.do" "`toggle_sig'" "Baseline"

display _n "Completed: Baseline"
