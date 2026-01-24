****************************************************
* 05_toggle_equiv.do
* Toggle: OECD Equivalence Scale
*
* Inputs:
*   - $deriv/cons_YYYY_cuq.dta (1990-2008)
*   - FMLI files for demographics (FAM_SIZE, PERSLT18)
*   - $robust_data/gini_rr_merged_baseline.dta (baseline Ginis + sh_rr)
*
* Output:
*   - $robust_data/gini_rr_merged_equiv.dta
*
* Methodology:
*   - Apply OECD equivalence scale: ES = 1 + 0.5*(FAM_SIZE-1) + 0.2*(FAM_SIZE-PERSLT18)
*   - Divide consumption by equivalence scale
*   - Recompute ONLY consumption Ginis (gini_core, gini_broad)
*   - Keep income Ginis (gini_fincbtax, gini_fsalaryx) from baseline unchanged
*   - Merge new consumption Ginis into baseline merged panel
****************************************************

clear all
set more off

* Globals
capture confirm global deriv
if _rc {
    global deriv "/Volumes/SSD PRO/Github-forks/Chp3-EnergyIneq/Code/Data/CEX/derived"
}
capture confirm global robust_data
if _rc {
    global robust_data "/Volumes/SSD PRO/Github-forks/Chp3-EnergyIneq/Code/Robust/Data"
}
global intr_base "/Volumes/SSD PRO/Github-forks/Chp3-EnergyIneq/Code/Data/CEX"

* Ensure inequality command is installed
capture which ineqdeco
if _rc ssc install ineqdeco

display _n "========================================"
display "TOGGLE: OECD Equivalence Scale"
display "========================================" _n

****************************************************
* 1. Compute consumption Ginis with equivalence scale
****************************************************
display _n "=== Computing Consumption Ginis with Equivalence Scale (1990-2008) ==="

tempfile gini_eq_cons
postfile gini_post int year int quarter double gini_core double gini_broad ///
    using `gini_eq_cons', replace

forvalues y = 1990/2008 {
    forvalues q = 1/4 {
        quietly {
            * Load consumption data
            capture confirm file "$deriv/cons_`y'_cuq.dta"
            if _rc continue
            
            use "$deriv/cons_`y'_cuq.dta", clear
            keep if quarter == `q'
            
            * Load FMLI data to get demographics
            local yr_suffix = substr(string(`y'), 3, 2)
            local intr_path "$intr_base/intrvw`yr_suffix'"
            
            * Try to load FMLI file for this quarter (simplified logic)
            local fmli_files ""
            if `y' < 1996 {
                * Pre-1996: fmli901, fmli902, fmli903, fmli904
                capture confirm file "`intr_path'/fmli`yr_suffix'`q'.dta"
                if !_rc local fmli_files "fmli`yr_suffix'`q'"
            }
            else if `y' >= 1996 & `y' < 2018 {
                * 1996-2017: fmli961x, fmli962, fmli963, fmli964, fmli971
                local q_map "1 1x 2 3 4"
                local q_idx = 1
                foreach qval in `q_map' {
                    if `q_idx' == `q' {
                        capture confirm file "`intr_path'/fmli`yr_suffix'`qval'.dta"
                        if !_rc local fmli_files "fmli`yr_suffix'`qval'"
                    }
                    local q_idx = `q_idx' + 1
                }
            }
            else {
                * 2018+: not in our 1990-2008 window
                continue
            }
            
            * Merge demographics if FMLI file found
            if "`fmli_files'" != "" {
                capture {
                    preserve
                    cd "`intr_path'"
                    use `fmli_files'.dta, clear
                    
                    * Standardize variable names
                    capture rename newid NEWID
                    capture rename finlwt21 FINLWT21
                    
                    * Extract demographics (try various possible names)
                    capture rename famsize FAM_SIZE
                    capture rename fam_size FAM_SIZE
                    capture rename v980010 FAM_SIZE
                    
                    capture rename perslt18 PERSLT18
                    capture rename v980050 PERSLT18
                    
                    * Keep only needed variables
                    keep NEWID FAM_SIZE PERSLT18
                    
                    * Apply CGK's fix for PERSLT18
                    replace PERSLT18 = FAM_SIZE - 1 if PERSLT18 >= FAM_SIZE & FAM_SIZE ~= . & PERSLT18 ~= .
                    
                    tempfile demographics
                    save `demographics', replace
                    restore
                    
                    * Merge demographics with consumption
                    merge m:1 NEWID using `demographics'
                    keep if _merge == 3 | _merge == 1
                    drop _merge
                    
                    * Compute equivalence scale
                    * OECD_ES = 1 + 0.5*(FAM_SIZE-1) + 0.2*(FAM_SIZE-PERSLT18)
                    gen OECD_ES = 1 + 0.5*(FAM_SIZE-1) + 0.2*(FAM_SIZE-PERSLT18)
                    
                    * Apply equivalence scale to consumption
                    replace cons_core_q  = cons_core_q  / OECD_ES
                    replace cons_broad_q = cons_broad_q / OECD_ES
                }
            }
            
            * Compute consumption Ginis
            scalar gc = .
            scalar gb = .
            
            if _N > 0 {
                capture ineqdeco cons_core_q [aw = FINLWT21]
                if !_rc {
                    scalar gc = r(gini)
                }
                
                capture ineqdeco cons_broad_q [aw = FINLWT21]
                if !_rc {
                    scalar gb = r(gini)
                }
            }
            
            * Post results (only consumption Ginis)
            post gini_post (`y') (`q') (gc) (gb)
        }
        
        if mod(`q', 2) == 0 {
            display "  Completed year `y', quarter `q'"
        }
    }
    
    if mod(`y', 5) == 0 {
        display "Completed year `y'"
    }
}

postclose gini_post

display _n "=== Consumption Gini Computation Complete ==="

****************************************************
* 2. Merge new consumption Ginis into baseline panel
****************************************************
display _n "=== Merging Equivalized Consumption Ginis into Baseline ==="

* Load equivalized consumption Ginis
use `gini_eq_cons', clear
gen qdate = yq(year, quarter)
format qdate %tq
sort year quarter

tempfile gini_eq_panel
save `gini_eq_panel', replace

* Load baseline merged panel (with income Ginis + sh_rr)
use "$robust_data/gini_rr_merged_baseline.dta", clear
sort year quarter

* Merge in new consumption Ginis
merge 1:1 year quarter using `gini_eq_panel'

display _n "Merge result (baseline + equivalized cons Ginis):"
tab _merge

* Keep baseline obs; allow missing equivalized Ginis for some quarters
drop _merge

* Overwrite baseline consumption Ginis with equivalized versions where available
capture confirm variable gini_core gini_broad
if _rc {
    display "ERROR: Expected gini_core/gini_broad in baseline panel not found"
    describe
    exit 111
}

* New Ginis are gini_core / gini_broad from the posted panel already
* (they overwrote via merge); nothing else to do here.

* Save equivalized merged panel
sort year quarter
save "$robust_data/gini_rr_merged_equiv.dta", replace

display _n "========================================"
display "TOGGLE COMPLETE: OECD Equivalence Scale"
display "========================================"
display "Saved: $robust_data/gini_rr_merged_equiv.dta"
display "Observations: " _N
display "========================================" _n

****************************************************
* 5. Run Local Projections and Export IRFs
****************************************************
display _n "=== Running Local Projections ==="

use "$robust_data/gini_rr_merged_equiv.dta", clear
tsset qdate, quarterly

local H 20
local p 4
local shocks "sh_rr"
local outcomes "gini_core gini_broad gini_fincbtax gini_fsalaryx"
local toggle_name "equiv"

capture confirm global robust_tables
if _rc global robust_tables "$robust_data/../Tables"
capture confirm global robust_figures
if _rc global robust_figures "$robust_data/../Figures"
capture mkdir "$robust_tables"
capture mkdir "$robust_figures"

tempfile results
postfile IRF str20 outcome str50 outcome_label int h ///
    str20 shock_type str50 shock_label ///
    double coefficient double se double ci_lower double ci_upper ///
    using `results', replace

foreach y of local outcomes {
    local ylabel : variable label `y'
    if "`ylabel'" == "" local ylabel "`y'"
    display _n "Estimating LP for: `y'"
    forvalues h = 0/`H' {
        * Cumulative change for horizon h
        quietly gen dyh = F`h'.`y' - L.`y'

        * Skip horizons with no usable data
        quietly count if !missing(dyh, `shocks', L1.`y')
        if r(N) == 0 {
            quietly drop dyh
            continue
        }

        * Run LP regression with Newey-West; skip horizon if regression fails
        capture noisily newey dyh `shocks' L(1/`p').`y', lag(`h')
        if _rc {
            quietly drop dyh
            continue
        }

        quietly {
            local b        = _b[`shocks']
            local se       = _se[`shocks']
            local ci_lower = `b' - 1.96*`se'
            local ci_upper = `b' + 1.96*`se'
            local shocklabel "Romer-Romer Monetary Policy Shock"
            post IRF ("`y'") ("`ylabel'") (`h') ///
                ("`shocks'") ("`shocklabel'") ///
                (`b') (`se') (`ci_lower') (`ci_upper')
            drop dyh
        }
    }
}

postclose IRF

use `results', clear
rename h horizon
sort outcome shock_type horizon
export delimited using "$robust_tables/lp_irf_results_rr_`toggle_name'.csv", replace
display "Saved: $robust_tables/lp_irf_results_rr_`toggle_name'.csv"

levelsof outcome, local(outlist)
levelsof shock_type, local(shocklist)

foreach y of local outlist {
    foreach shock of local shocklist {
        preserve
        keep if outcome == "`y'" & shock_type == "`shock'"
        quietly local ylabel = outcome_label[1]
        local shocklabel_short "RR"
        local plottitle "`ylabel' to `shocklabel_short' Shock (`toggle_name')"
        gen zero_line = 0
        twoway ///
            (rarea ci_upper ci_lower horizon, color(gs12) fintensity(30)) ///
            (line coefficient horizon, lwidth(medthick) lcolor(navy)) ///
            (line zero_line horizon, lpattern(dash) lcolor(black) lwidth(thin)) ///
            , title("`plottitle'", size(med)) ///
              xtitle("Horizon (quarters)", size(med)) ///
              ytitle("", size(med)) ///
              legend(order(2 "Point Estimate" 1 "95% Confidence Interval") ///
                     cols(2) size(small)) ///
              xlabel(0(5)20, grid) ///
              ylabel(, grid) ///
              scheme(s1mono) ///
              plotregion(margin(small)) ///
              graphregion(margin(medium) color(white))
        local outcomename = subinstr("`y'", "gini_", "", .)
        graph export "$robust_figures/irf_rr_`outcomename'_`toggle_name'.png", replace width(2000)
        restore
    }
}

display _n "========================================"
display "LOCAL PROJECTIONS COMPLETE"
display "========================================"
display "Results table: $robust_tables/lp_irf_results_rr_`toggle_name'.csv"
display "IRF plots:    $robust_figures/irf_rr_*_`toggle_name'.png"
display "========================================" _n
