****************************************************
* 10_toggle_ineqcmd.do
* Toggle: Inequality Command (ineqdec0 instead of ineqdeco)
*
* Inputs:
*   - $deriv/cons_YYYY_cuq.dta (1990-2008)
*   - $deriv/income_YYYY_cuq.dta (1990-2008)
*   - RR shocks file
*
* Output:
*   - $robust_data/gini_rr_merged_ineqcmd.dta
*
* Methodology:
*   - Use ineqdec0 instead of ineqdeco for Gini computation
*   - Recompute 4 Gini coefficients quarter-by-quarter
*   - Merge with RR shocks
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
global rr_shocks "/Volumes/SSD PRO/Downloads/replication_folder/source_files/RR_shocks_updated.dta"

* Ensure inequality command is installed
capture which ineqdec0
if _rc ssc install ineqdec0

display _n "========================================"
display "TOGGLE: Inequality Command (ineqdec0)"
display "========================================" _n

****************************************************
* 1. Compute Ginis with ineqdec0
****************************************************
display _n "=== Computing Ginis with ineqdec0 (1990-2008) ==="

tempfile gini_results
postfile gini_post int year int quarter double gini_core double gini_broad ///
    double gini_fincbtax double gini_fsalaryx ///
    using `gini_results', replace

forvalues y = 1990/2008 {
    forvalues q = 1/4 {
        quietly {
            * Load consumption data
            capture confirm file "$deriv/cons_`y'_cuq.dta"
            if _rc continue
            
            use "$deriv/cons_`y'_cuq.dta", clear
            keep if quarter == `q'
            
            * Compute consumption Ginis with ineqdec0
            scalar gc = .
            scalar gb = .
            
            if _N > 0 {
                capture ineqdec0 cons_core_q [aw = FINLWT21]
                if !_rc {
                    scalar gc = r(gini)
                }
                
                capture ineqdec0 cons_broad_q [aw = FINLWT21]
                if !_rc {
                    scalar gb = r(gini)
                }
            }
            
            * Load income data
            scalar g_fincbtax = .
            scalar g_fsalaryx = .
            
            capture confirm file "$deriv/income_`y'_cuq.dta"
            if !_rc {
                use "$deriv/income_`y'_cuq.dta", clear
                keep if quarter == `q'
                
                * Handle variable name differences
                capture confirm variable fincbtax
                if _rc {
                    capture confirm variable fincbtxm
                    if !_rc rename fincbtxm fincbtax
                }
                capture confirm variable fsalaryx
                if _rc {
                    capture confirm variable fsalarym
                    if !_rc rename fsalarym fsalaryx
                }
                
                * Compute income Ginis (exclude zeros/missing) with ineqdec0
                preserve
                drop if missing(fincbtax) | fincbtax <= 0
                if _N > 0 {
                    capture ineqdec0 fincbtax [aw = FINLWT21]
                    if !_rc {
                        scalar g_fincbtax = r(gini)
                    }
                }
                restore
                
                preserve
                drop if missing(fsalaryx) | fsalaryx <= 0
                if _N > 0 {
                    capture ineqdec0 fsalaryx [aw = FINLWT21]
                    if !_rc {
                        scalar g_fsalaryx = r(gini)
                    }
                }
                restore
            }
            
            * Post results
            post gini_post (`y') (`q') (gc) (gb) (g_fincbtax) (g_fsalaryx)
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

display _n "=== Gini Computation Complete ==="

****************************************************
* 2. Create quarterly panel
****************************************************
use `gini_results', clear

gen qdate = yq(year, quarter)
format qdate %tq
sort year quarter

display _n "=== Gini Panel Summary ==="
count
display "Total observations: " r(N)
summarize gini_core gini_broad gini_fincbtax gini_fsalaryx

****************************************************
* 3. Merge with RR shocks
****************************************************
display _n "=== Merging RR Shocks ==="

tempfile gini_panel
save `gini_panel', replace

use "$rr_shocks", clear
capture confirm variable year quarter sh_rr
if _rc {
    display "ERROR: Expected variables year, quarter, sh_rr not all found"
    describe
    exit 111
}

keep if year >= 1990 & year <= 2008
sort year quarter

tempfile rr
save `rr', replace

use `gini_panel', clear
sort year quarter

merge 1:1 year quarter using `rr'

display _n "Merge result:"
tab _merge

keep if _merge == 3
drop _merge

summarize sh_rr
display "Non-missing sh_rr observations: " r(N)

****************************************************
* 4. Save final merged file
****************************************************
sort year quarter
save "$robust_data/gini_rr_merged_ineqcmd.dta", replace

display _n "========================================"
display "TOGGLE COMPLETE: Inequality Command (ineqdec0)"
display "========================================"
display "Saved: $robust_data/gini_rr_merged_ineqcmd.dta"
display "Observations: " _N
display "========================================" _n

****************************************************
* 5. Run Local Projections and Export IRFs
****************************************************
display _n "=== Running Local Projections ==="

use "$robust_data/gini_rr_merged_ineqcmd.dta", clear
tsset qdate, quarterly

local H 20
local p 4
local shocks "sh_rr"
local outcomes "gini_core gini_broad gini_fincbtax gini_fsalaryx"
local toggle_name "ineqcmd"

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
        quietly {
            gen dyh = F`h'.`y' - L.`y'
            newey dyh `shocks' L(1/`p').`y', lag(`h')
            local b = _b[`shocks']
            local se = _se[`shocks']
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
