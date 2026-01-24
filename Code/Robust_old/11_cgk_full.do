****************************************************
* 11_cgk_full.do
* Tier 4: Switch to ineqdec0 (CGK's Full Method)
****************************************************

clear all
set more off

global code "/Volumes/SSD PRO/Github-forks/Chp3-EnergyIneq/Code"

display _n "========================================"
display "TIER 4: CGK FULL METHOD (ineqdec0)"
display "========================================" _n

* Compute Ginis
do "$code/Robust/02_compute_gini_robust.do" ///
    1 1 "fw" 1 "exclude" 0 "ineqdec0" "CGKFull"

* Run Local Projections
local toggle_sig = "deflate1_equiv1_fw_winsor1_zeroexclude_resid0_ineqdec0"
do "$code/Robust/03_local_projections_robust.do" "`toggle_sig'" "CGKFull"

display _n "Completed: CGKFull"
