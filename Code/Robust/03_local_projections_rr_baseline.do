****************************************************
* 03_local_projections_rr_baseline.do
* Local Projections: RR shocks (sh_rr) → 4 Gini measures
*
* Dataset:
*   $robust_data/gini_rr_merged_baseline.dta
*
* Outcomes:
*   gini_core
*   gini_broad
*   gini_fincbtax
*   gini_fsalaryx
*
* Shock:
*   sh_rr   (Greenbook Romer–Romer MP shock)
*
* This is a stripped-down version of 06_local_projections.do:
* - Only one shock (sh_rr)
* - Only 4 Ginis as outcomes
* - No macro controls (for speed and transparency)
****************************************************

clear all
set more off

* Expect globals from 00_run_all_robust.do, but define safe defaults
capture confirm global robust_data
if _rc {
    global robust_data "/Volumes/SSD PRO/Github-forks/Chp3-EnergyIneq/Code/Robust/Data"
}
capture confirm global robust_tables
if _rc {
    global robust_tables "/Volumes/SSD PRO/Github-forks/Chp3-EnergyIneq/Code/Robust/Tables"
}
capture confirm global robust_figures
if _rc {
    global robust_figures "/Volumes/SSD PRO/Github-forks/Chp3-EnergyIneq/Code/Robust/Figures"
}

* Open log
capture log close
log using "/Volumes/SSD PRO/Github-forks/Chp3-EnergyIneq/Code/Robust/03_local_projections_rr_baseline.log", replace

display _n "========================================"
display "LOCAL PROJECTIONS: RR SHOCKS TO INEQUALITY (BASELINE)"
display "========================================" _n

****************************************************
* 1. Setup and Data Loading
****************************************************

* Load merged dataset
use "$robust_data/gini_rr_merged_baseline.dta", clear

* Declare time series (qdate already in Gini panel)
tsset qdate, quarterly

display _n "=== DATA OVERVIEW ==="
count
display "Total observations: " r(N)
display "Date range:"
summarize qdate
quietly {
    local first_date = qdate[1]
    local last_date  = qdate[_N]
}
display "First observation: " %tq `first_date'
display "Last observation:  " %tq `last_date'

****************************************************
* 2. LP Specification
****************************************************

local H 20          // horizons (quarters): 0 to 20
local p 4           // number of lags for controls

* Shock
local shocks "sh_rr"

* Outcomes: 4 Ginis
local outcomes "gini_core gini_broad gini_fincbtax gini_fsalaryx"

display _n "=== SPECIFICATION ==="
display "Horizons: 0 to `H' quarters"
display "Lags:     `p' quarters"
display "Outcomes: `outcomes'"
display "Shock:    `shocks'"
display "Controls: lags of outcome only"
display "Form:     Cumulative change (y_{t+h} - y_{t-1})"

****************************************************
* 3. Local Projections Loop
****************************************************

display _n "=== ESTIMATING LOCAL PROJECTIONS ==="

tempfile results
postfile IRF str20 outcome str50 outcome_label int h ///
    str20 shock_type str50 shock_label ///
    double coefficient double se double ci_lower double ci_upper ///
    using `results', replace

foreach y of local outcomes {

    * Get outcome label
    local ylabel : variable label `y'
    if "`ylabel'" == "" {
        local ylabel "`y'"
    }

    display _n "----------------------------------------"
    display "Estimating LP for: `y'"
    display "Label:            `ylabel'"
    display "----------------------------------------"

    forvalues h = 0/`H' {

        quietly {
            * Cumulative change: y_{t+h} - y_{t-1}
            gen dyh = F`h'.`y' - L.`y'

            * LP regression with Newey-West HAC standard errors
            local nwlag = `h'
            newey dyh ///
                `shocks' ///
                L(1/`p').`y' ///
                , lag(`nwlag')

            * Store coefficients and SEs for each shock
            foreach shock of local shocks {
                local b        = _b[`shock']
                local se       = _se[`shock']
                local ci_lower = `b' - 1.96*`se'
                local ci_upper = `b' + 1.96*`se'

                * Shock label
                local shocklabel : variable label `shock'
                if "`shocklabel'" == "" {
                    local shocklabel "RR Greenbook shock"
                }

                post IRF ("`y'") ("`ylabel'") (`h') ///
                    ("`shock'") ("`shocklabel'") ///
                    (`b') (`se') (`ci_lower') (`ci_upper')
            }

            drop dyh
        }

        if mod(`h', 5) == 0 {
            display "  Horizon `h' complete"
        }
    }

    display "  Completed all horizons for `y'"
}

postclose IRF

display _n "=== ESTIMATION COMPLETE ==="

****************************************************
* 4. Process and Export Results
****************************************************

use `results', clear

rename h horizon
sort outcome shock_type horizon

display _n "=== RESULTS SUMMARY ==="
count
display "Total IRF estimates: " r(N)
tab outcome shock_type

* Export to CSV
capture mkdir "$robust_tables"
export delimited using "$robust_tables/lp_irf_results_rr_baseline.csv", replace
display "Saved: $robust_tables/lp_irf_results_rr_baseline.csv"

****************************************************
* 5. Create IRF Plots
****************************************************

display _n "=== CREATING IRF PLOTS ==="

levelsof outcome, local(outlist)
levelsof shock_type, local(shocklist)

foreach y of local outlist {
    foreach shock of local shocklist {

        preserve
        keep if outcome == "`y'" & shock_type == "`shock'"

        quietly {
            local ylabel = outcome_label[1]
        }

        * Short labels
        if "`shock'" == "sh_rr" {
            local shocklabel_short "RR shock"
            local shockname "rr"
        }
        else {
            local shocklabel_short "`shock'"
            local shockname = subinstr("`shock'", "_", "", .)
        }

        local plottitle "`ylabel' to `shocklabel_short'"

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

        local filename "irf_`shockname'_`y'_baseline.png"
        capture mkdir "$robust_figures"
        graph export "$robust_figures/`filename'", replace width(2000)

        display "  Saved: `filename'"

        restore
    }
}

display _n "=== ALL PLOTS CREATED ==="

display _n "========================================"
display "LOCAL PROJECTIONS (RR baseline) COMPLETE"
display "========================================"
display "Results table: $robust_tables/lp_irf_results_rr_baseline.csv"
display "IRF plots:    $robust_figures/irf_*_baseline.png"
display "========================================" _n

log close

