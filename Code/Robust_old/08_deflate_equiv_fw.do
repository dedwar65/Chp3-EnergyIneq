****************************************************
* 08_deflate_equiv_fw.do
* Tier 1c: Deflation + Equivalence + Frequency Weights ON
****************************************************

clear all
set more off

global code "/Volumes/SSD PRO/Github-forks/Chp3-EnergyIneq/Code"

display _n "========================================"
display "TIER 1C: DEFLATION + EQUIVALENCE + FREQUENCY WEIGHTS ON"
display "========================================" _n

* Compute Ginis
do "$code/Robust/02_compute_gini_robust.do" ///
    1 1 "fw" 0 "include" 0 "ineqdeco" "DeflateEquivFW"

* Run Local Projections
local toggle_sig = "deflate1_equiv1_fw_winsor0_zerosinclude_resid0_ineqdeco"
do "$code/Robust/03_local_projections_robust.do" "`toggle_sig'" "DeflateEquivFW"

display _n "Completed: DeflateEquivFW"
