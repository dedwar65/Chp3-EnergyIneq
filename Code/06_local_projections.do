****************************************************
* 06_local_projections.do
* Local Projections (Jordà) using BH oil shocks
* Estimates IRFs for inequality outcomes
****************************************************

clear all
set more off

global deriv "/Volumes/SSD PRO/Github-forks/Chp3-EnergyIneq/Code/Data/CEX/derived"
global paper "/Volumes/SSD PRO/Github-forks/Chp3-EnergyIneq/Paper"
global code "/Volumes/SSD PRO/Github-forks/Chp3-EnergyIneq/Code"

* Close any open log file, then open new log file
capture log close
log using "$code/06_local_projections.log", replace

****************************************************
* 1. Setup and Data Loading
****************************************************

display _n "========================================"
display "LOCAL PROJECTIONS: BH SHOCKS TO INEQUALITY"
display "========================================" _n

* Load final merged dataset
use "$deriv/gini_bh_shocks_fred_merged.dta", clear

* Declare time series
tsset qdate, quarterly

* Verify data structure and check for gaps
display _n "=== DATA OVERVIEW ==="
count
display "Total observations: " r(N)
display "Date range:"
summarize qdate
quietly {
    local first_date = qdate[1]
    local last_date = qdate[_N]
}
display "First observation: " %tq `first_date'
display "Last observation: " %tq `last_date'

* Check for gaps in time series
display _n "=== CHECKING FOR GAPS IN TIME SERIES ==="
quietly {
    * Create expected full sequence from first to last date
    local first_q = qdate[1]
    local last_q = qdate[_N]
    local expected_n = (`last_q' - `first_q') + 1
    local actual_n = _N
    
    display "First quarter: " %tq `first_q'
    display "Last quarter: " %tq `last_q'
    display "Expected observations (if complete): `expected_n'"
    display "Actual observations: `actual_n'"
    
    * Check if there are gaps
    gen expected_qdate = qdate[1] + _n - 1
    gen has_gap = (qdate != expected_qdate)
    count if has_gap
    local n_gaps = r(N)
    
    * Also check for duplicates
    duplicates tag qdate, gen(dup)
    count if dup > 0
    local n_dups = r(N)
}
if `n_dups' > 0 {
    display _n "WARNING: Found duplicate dates!"
    display "Duplicate quarters:"
    list qdate year quarter if dup > 0, clean
    quietly drop dup expected_qdate has_gap
    display _n "ERROR: Cannot proceed with duplicate dates. Please fix data construction."
    exit 198
}
if `n_gaps' > 0 {
    display _n "WARNING: Found gaps in time series"
    display "Missing quarters (expected vs actual):"
    list qdate expected_qdate year quarter if has_gap, clean
    display _n "Checking if gaps are at endpoints..."
    quietly {
        * Check if first or last expected dates are missing
        local first_expected = expected_qdate[1]
        local last_expected = expected_qdate[_N]
        count if qdate == `first_expected'
        local has_first = (r(N) > 0)
        count if qdate == `last_expected'
        local has_last = (r(N) > 0)
    }
    if !`has_first' {
        display "NOTE: First expected quarter " %tq `first_expected' " is missing (endpoint issue)"
    }
    if !`has_last' {
        display "NOTE: Last expected quarter " %tq `last_expected' " is missing (endpoint issue)"
    }
    display _n "Filling gaps with missing values (for time series regularity)..."
    quietly drop expected_qdate has_gap dup
    tsfill
    display "Gaps filled. New observation count: " _N
    display "NOTE: Filled observations have missing values and will be dropped in regressions"
}
else {
    display "No gaps detected - time series is regularly spaced"
    quietly drop expected_qdate has_gap dup
}

* Re-declare time series after potential filling
tsset qdate, quarterly

* Settings
local H 20          // horizons (quarters): 0 to 20
local p 4           // number of lags for controls

* Shock variables
local shocks "supply_shock demand_shock_agg demand_shock_oil"

* Outcome variables
local outcomes "gini_core gini_broad gini_fincbtax gini_fsalaryx"

* Macro controls (baseline: log_indpro, infl_core, treasury_1yr)
local macroctrl "log_indpro infl_core treasury_1yr"

* Create output directories
capture mkdir "$paper/Tables"
capture mkdir "$paper/Figures"

display _n "=== SPECIFICATION ==="
display "Horizons: 0 to `H' quarters"
display "Lags: `p' quarters"
display "Outcomes: `outcomes'"
display "Shocks: `shocks'"
display "Controls: `macroctrl'"
display "Form: Cumulative change (y_{t+h} - y_{t-1})"

****************************************************
* 2. Local Projections Loop
****************************************************

display _n "=== ESTIMATING LOCAL PROJECTIONS ==="

* Create postfile to store results
tempfile results
postfile IRF str20 outcome str50 outcome_label int h ///
    str20 shock_type str50 shock_label ///
    double coefficient double se double ci_lower double ci_upper ///
    using `results', replace

* Loop over outcomes
foreach y of local outcomes {
    
    * Get outcome label
    local ylabel : variable label `y'
    if "`ylabel'" == "" {
        local ylabel "`y'"
    }
    
    display _n "----------------------------------------"
    display "Estimating LP for: `y'"
    display "Label: `ylabel'"
    display "----------------------------------------"
    
    * Loop over horizons
    forvalues h = 0/`H' {
        
        quietly {
            * Create cumulative change: y_{t+h} - y_{t-1}
            gen dyh = F`h'.`y' - L.`y'
            
            * LP regression with Newey-West HAC standard errors
            * Controls: lags of outcome + lags of macro vars
            * Use lag(h) to account for horizon-dependent autocorrelation
            local nwlag = `h'
            newey dyh ///
                `shocks' ///
                L(1/`p').`y' ///
                L(1/`p').(`macroctrl') ///
                , lag(`nwlag')
            
            * Store coefficients and SEs for each shock
            foreach shock of local shocks {
                local b = _b[`shock']
                local se = _se[`shock']
                local ci_lower = `b' - 1.96*`se'
                local ci_upper = `b' + 1.96*`se'
                
                * Get shock label
                local shocklabel : variable label `shock'
                if "`shocklabel'" == "" {
                    if "`shock'" == "supply_shock" {
                        local shocklabel "BH Oil Supply Shock"
                    }
                    else if "`shock'" == "demand_shock_agg" {
                        local shocklabel "BH Aggregate Demand Shock"
                    }
                    else if "`shock'" == "demand_shock_oil" {
                        local shocklabel "BH Oil Consumption Demand Shock"
                    }
                    else {
                        local shocklabel "`shock'"
                    }
                }
                
                * Post results
                post IRF ("`y'") ("`ylabel'") (`h') ///
                    ("`shock'") ("`shocklabel'") ///
                    (`b') (`se') (`ci_lower') (`ci_upper')
            }
            
            drop dyh
        }
        
        * Progress indicator every 5 horizons
        if mod(`h', 5) == 0 {
            display "  Horizon `h' complete"
        }
    }
    
    display "  Completed all horizons for `y'"
}

postclose IRF

display _n "=== ESTIMATION COMPLETE ==="

****************************************************
* 3. Load and Process Results
****************************************************

use `results', clear

* Rename h to horizon for clarity
rename h horizon

* Sort for easier viewing
sort outcome shock_type horizon

* Display summary
display _n "=== RESULTS SUMMARY ==="
count
display "Total IRF estimates: " r(N)
display "Breakdown:"
tab outcome shock_type

****************************************************
* 4. Export Results Table
****************************************************

display _n "=== EXPORTING RESULTS TABLE ==="

* Export to CSV with descriptive headers
export delimited using "$paper/Tables/lp_irf_results.csv", replace

display "Saved: $paper/Tables/lp_irf_results.csv"

****************************************************
* 5. Create IRF Plots
****************************************************

display _n "=== CREATING IRF PLOTS ==="

* Get list of outcomes
levelsof outcome, local(outlist)

* Get list of shocks
levelsof shock_type, local(shocklist)

* Create plots for each outcome-shock combination
foreach y of local outlist {
    
    foreach shock of local shocklist {
        
        preserve
        keep if outcome == "`y'" & shock_type == "`shock'"
        
        * Get outcome label from first observation
        quietly {
            local ylabel = outcome_label[1]
        }
        
        * Create short shock label for title
        if "`shock'" == "supply_shock" {
            local shocklabel_short "supply shock"
        }
        else if "`shock'" == "demand_shock_agg" {
            local shocklabel_short "demand shock (agg)"
        }
        else if "`shock'" == "demand_shock_oil" {
            local shocklabel_short "demand shock"
        }
        else {
            local shocklabel_short "`shock'"
        }
        
        * Create plot title
        local plottitle "`ylabel' to `shocklabel_short'"
        
        * Determine file name based on shock type
        if "`shock'" == "supply_shock" {
            local shockname "supply"
        }
        else if "`shock'" == "demand_shock_agg" {
            local shockname "dagg"
        }
        else if "`shock'" == "demand_shock_oil" {
            local shockname "doil"
        }
        else {
            local shockname = subinstr("`shock'", "_", "", .)
        }
        
        * Generate zero line variable
        gen zero_line = 0
        
        * Create plot with confidence bands and zero line
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
        
        * Save plot
        local filename "irf_`shockname'_`y'.png"
        graph export "$paper/Figures/`filename'", replace width(2000)
        
        display "  Saved: `filename'"
        
        restore
    }
}

display _n "=== ALL PLOTS CREATED ==="

****************************************************
* 6. Final Summary
****************************************************

display _n "========================================"
display "LOCAL PROJECTIONS COMPLETE"
display "========================================"
display "Results table: $paper/Tables/lp_irf_results.csv"
display "IRF plots: $paper/Figures/irf_*.png"
display "Total plots created: 12 (3 shocks × 4 outcomes)"
display "========================================" _n

* Close log file
log close
