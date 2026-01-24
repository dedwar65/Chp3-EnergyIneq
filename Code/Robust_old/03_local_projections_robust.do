****************************************************
* 03_local_projections_robust.do
* Run Local Projections using toggled Gini series and CGK shocks
* Called by individual toggle files (05-11) with toggle signature
*
* Arguments:
*   toggle_sig: Toggle signature to identify which Gini series to use
****************************************************

clear all
set more off

* Accept toggle signature and shortname as arguments
args toggle_sig toggle_shortname

* If no argument provided, use baseline
if "`toggle_sig'" == "" local toggle_sig = "deflate0_equiv0_aw_winsor0_zerosinclude_resid0_ineqdeco"
if "`toggle_shortname'" == "" local toggle_shortname = "Baseline"

global robust_data "/Volumes/SSD PRO/Github-forks/Chp3-EnergyIneq/Code/Robust/Data"
global robust_figures "/Volumes/SSD PRO/Github-forks/Chp3-EnergyIneq/Code/Robust/Figures"
global robust_tables "/Volumes/SSD PRO/Github-forks/Chp3-EnergyIneq/Code/Robust/Tables"
global deriv "/Volumes/SSD PRO/Github-forks/Chp3-EnergyIneq/Code/Data/CEX/derived"
global paper "/Volumes/SSD PRO/Github-forks/Chp3-EnergyIneq/Paper"
global code "/Volumes/SSD PRO/Github-forks/Chp3-EnergyIneq/Code"

display _n "========================================"
display "LOCAL PROJECTIONS: CGK SHOCKS TO INEQUALITY"
display "Toggle: `toggle_shortname'"
display "Signature: `toggle_sig'"
display "========================================" _n

****************************************************
* 1. Load toggled Gini series from temp file
****************************************************
display _n "=== Loading Toggled Gini Series ==="

* Load from temp file that was just created by 02_compute_gini_robust.do
* The temp file name matches the toggle signature
local temp_gini_file = "$robust_data/temp_gini_`toggle_sig'.dta"

capture confirm file "`temp_gini_file'"
if _rc {
    display "ERROR: Temp Gini file not found: `temp_gini_file'"
    display "This file should have been created by 02_compute_gini_robust.do"
    display "Please ensure 02_compute_gini_robust.do completed successfully before running LPs"
    exit 198
}

use "`temp_gini_file'", clear

display "Gini series for `toggle_sig': " _N " observations"
summarize qdate
display "Date range: " %tq qdate[1] " to " %tq qdate[_N]

* Merge income Ginis from original data (income Ginis don't use toggles)
* They're computed separately and don't need deflation/equivalence scale adjustments
display _n "=== Merging Income Ginis from Original Data ==="
merge 1:1 qdate using "$deriv/gini_1990_2023_quarterly.dta", ///
    keepusing(gini_fincbtax gini_fsalaryx) keep(master match)
    
display "Income Gini merge results:"
tab _merge
drop _merge

display "Now have all 4 Gini measures: consumption (toggled) + income (original)"

****************************************************
* 2. Merge with CGK shocks
****************************************************
display _n "=== Merging CGK Shocks ==="

merge 1:1 qdate using "$robust_data/gini_cgk_shocks_merged.dta"

display "Merge results:"
tab _merge

* Keep only overlapping period (1990-2008) where both Ginis and shocks exist
keep if _merge == 3
drop _merge

* For LP, we need the overlapping period
keep if year >= 1990 & year <= 2008

display "After merge and filtering: " _N " observations"
summarize qdate

****************************************************
* 3. Merge with FRED macro controls
****************************************************
display _n "=== Merging FRED Macro Controls ==="

merge 1:1 qdate using "$deriv/fred_quarterly.dta"

display "FRED merge results:"
tab _merge

keep if _merge == 3
drop _merge

display "After FRED merge: " _N " observations"

****************************************************
* 4. Declare time series
****************************************************
tsset qdate, quarterly

* Verify no gaps
display _n "=== Checking Time Series ==="
count
local n_obs = r(N)
quietly {
    local first_q = qdate[1]
    local last_q = qdate[_N]
    local expected_n = (`last_q' - `first_q') + 1
}
display "Expected observations: `expected_n'"
display "Actual observations: `n_obs'"

if `n_obs' < `expected_n' {
    display "WARNING: Gaps detected. Filling with missing values..."
    tsfill
}

****************************************************
* 5. LP Settings
****************************************************
local H 20          // horizons (quarters): 0 to 20
local p 4           // number of lags for controls

* CGK shock variables
local shocks "sh_rr MP_FFF_GW pi_trend_cg"

* Outcome variables (all 4 Gini measures: consumption and income)
local outcomes "gini_core gini_broad gini_fincbtax gini_fsalaryx"

* Macro controls (same as baseline)
local macroctrl "log_indpro infl_core treasury_1yr"

display _n "=== SPECIFICATION ==="
display "Horizons: 0 to `H' quarters"
display "Lags: `p' quarters"
display "Outcomes: `outcomes'"
display "Shocks: `shocks'"
display "Controls: `macroctrl'"
display "Form: Cumulative change (y_{t+h} - y_{t-1})"

****************************************************
* 6. Local Projections Loop
****************************************************
display _n "=== ESTIMATING LOCAL PROJECTIONS ==="

* Create postfile to store results
tempfile results
postfile IRF str20 outcome str50 outcome_label int h ///
    str20 shock_type str50 shock_label ///
    double coefficient double se double ci_lower double ci_upper ///
    str50 toggle_sig str30 toggle_shortname ///
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
                    if "`shock'" == "sh_rr" {
                        local shocklabel "Romer-Romer Monetary Policy Shock"
                    }
                    else if "`shock'" == "MP_FFF_GW" {
                        local shocklabel "Gorodnichenko-Weber Fed Funds Futures Shock"
                    }
                    else if "`shock'" == "pi_trend_cg" {
                        local shocklabel "Coibion-Gorodnichenko Trend Inflation Shock"
                    }
                    else {
                        local shocklabel "`shock'"
                    }
                }
                
                * Post results
                post IRF ("`y'") ("`ylabel'") (`h') ///
                    ("`shock'") ("`shocklabel'") ///
                    (`b') (`se') (`ci_lower') (`ci_upper') ///
                    ("`toggle_sig'") ("`toggle_shortname'")
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
* 7. Load and Process Results
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
* 8. Export Results Table
****************************************************
display _n "=== EXPORTING RESULTS TABLE ==="

* Export to CSV (needed temporarily for combined plots, then can be deleted)
* Save to Tables directory
export delimited using "$robust_tables/lp_irf_`toggle_shortname'.csv", replace

display "Saved: $robust_tables/lp_irf_`toggle_shortname'.csv (temporary - used for combined plots)"

****************************************************
* 9. Create IRF Plots
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
        
        * Create short shock label for title and filename
        if "`shock'" == "sh_rr" {
            local shocklabel_short "RR"
            local shockname = "RR"
        }
        else if "`shock'" == "MP_FFF_GW" {
            local shocklabel_short "GW"
            local shockname = "GW"
        }
        else if "`shock'" == "pi_trend_cg" {
            local shocklabel_short "TrendInf"
            local shockname = "TrendInf"
        }
        else {
            local shocklabel_short "`shock'"
            local shockname = subinstr("`shock'", "_", "", .)
        }
        
        * Create short outcome label for filename
        if "`y'" == "gini_core" {
            local outcomename = "ConsCore"
        }
        else if "`y'" == "gini_broad" {
            local outcomename = "ConsBroad"
        }
        else if "`y'" == "gini_fincbtax" {
            local outcomename = "IncBeforeTax"
        }
        else if "`y'" == "gini_fsalaryx" {
            local outcomename = "IncSalary"
        }
        else {
            local outcomename = "`y'"
        }
        
        * Create display label for plot title
        if "`y'" == "gini_core" {
            local outcomelabel_display = "Core Consumption Gini"
        }
        else if "`y'" == "gini_broad" {
            local outcomelabel_display = "Broad Consumption Gini"
        }
        else if "`y'" == "gini_fincbtax" {
            local outcomelabel_display = "Income Before Tax Gini"
        }
        else if "`y'" == "gini_fsalaryx" {
            local outcomelabel_display = "Salary Income Gini"
        }
        else {
            local outcomelabel_display = "`ylabel'"
        }
        
        * Create plot title (concise)
        local plottitle "`outcomelabel_display' to `shocklabel_short' Shock (`toggle_shortname')"
        
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
        
        * Save plot with clear, concise filename: irf_[shortname]_[shock]_[gini].png
        local filename "irf_`toggle_shortname'_`shockname'_`outcomename'.png"
        graph export "$robust_figures/`filename'", replace width(2000)
        
        display "  Saved: `filename'"
        
        restore
    }
}

display _n "=== ALL PLOTS CREATED ==="
display "Total IRF plots created: 12 (4 Gini measures × 3 shocks)"
display "  - Consumption: Core, Broad"
display "  - Income: Before Tax, Salary"
display "  - Shocks: RR, GW, TrendInf"
display "Files saved in: $robust_figures/"

****************************************************
* 10. Final Summary
****************************************************
display _n "========================================"
display "LOCAL PROJECTIONS COMPLETE"
display "========================================"
display "Toggle signature: `toggle_sig'"
display "Results table: $robust_data/lp_irf_robust_`toggle_sig'.csv"
display "IRF plots: $paper/Figures/irf_robust_`toggle_sig'_*.png"
display "========================================" _n
