****************************************************
* 04_toggle_deflate.do
* Toggle: CPI Deflation (1982-84 base)
*
* Inputs:
*   - $deriv/cons_YYYY_cuq.dta (1990-2008)
*   - $deriv/income_YYYY_cuq.dta (1990-2008)
*   - $fred/CPIAUCSL.csv (CPI data)
*   - RR shocks file
*
* Output:
*   - $robust_data/gini_rr_merged_deflate.dta
*
* Methodology:
*   - Deflate nominal consumption/income to 1982-84 dollars
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
global fred "/Volumes/SSD PRO/Github-forks/Chp3-EnergyIneq/Code/Data/FRED"
global rr_shocks "/Volumes/SSD PRO/Downloads/replication_folder/source_files/RR_shocks_updated.dta"

* Ensure inequality command is installed
capture which ineqdeco
if _rc ssc install ineqdeco

display _n "========================================"
display "TOGGLE: CPI Deflation (1982-84 base)"
display "========================================" _n

****************************************************
* 1. Load and prepare CPI data
****************************************************
display _n "=== Loading CPI Data ==="

* CPIAUCSL is already indexed to 1982-84=100, so we can use the level directly
import delimited "$fred/CPIAUCSL.csv", clear

* Parse date
gen date = date(observation_date, "YMD")
format date %td
gen year = year(date)
gen month = month(date)
gen quarter = ceil(month/3)

* Use CPI level (1982-84 base = 100) directly
rename cpiaucsl cpi_u

* Collapse to quarterly (average monthly CPI within quarter)
collapse (mean) cpi_u, by(year quarter)

* Create qdate for merging
gen qdate = yq(year, quarter)
format qdate %tq

* Restrict to 1990-2008
keep if year >= 1990 & year <= 2008

tempfile cpi_data
save `cpi_data', replace

display "CPI loaded: " _N " quarterly observations (1990-2008)"

****************************************************
* 2. Compute deflated Ginis quarter-by-quarter
****************************************************
display _n "=== Computing Deflated Ginis (1990-2008) ==="

tempfile gini_results
postfile gini_post int year int quarter double gini_core double gini_broad ///
    double gini_fincbtax double gini_fsalaryx ///
    using `gini_results', replace

forvalues y = 1990/2008 {
    forvalues q = 1/4 {
        quietly {
            * Load consumption data
            capture confirm file "$deriv/cons_`y'_cuq.dta"
            if _rc {
                * Skip if file doesn't exist
                continue
            }
            
            use "$deriv/cons_`y'_cuq.dta", clear
            keep if quarter == `q'
            
            * Merge CPI
            gen qdate = yq(`y', `q')
            format qdate %tq
            merge m:1 qdate using `cpi_data'
            keep if _merge == 3
            drop _merge qdate
            
            * Apply deflation: real = nominal / cpi_u * 100
            replace cons_core_q = cons_core_q / cpi_u * 100
            replace cons_broad_q = cons_broad_q / cpi_u * 100
            drop cpi_u
            
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

            * #region agent log
            * Debug: consumption Gini computed for this year/quarter
            display "DEBUG deflate cons: year=" `y' " q=" `q' " N=" _N " gc=" gc " gb=" gb
            * #endregion
            
            * Load income data
            scalar g_fincbtax = .
            scalar g_fsalaryx = .
            
            capture confirm file "$deriv/income_`y'_cuq.dta"
            if !_rc {
                use "$deriv/income_`y'_cuq.dta", clear
                keep if quarter == `q'
                
                * Merge CPI
                gen qdate = yq(`y', `q')
                format qdate %tq
                merge m:1 qdate using `cpi_data'
                keep if _merge == 3
                drop _merge qdate
                
                * Handle variable name differences across years
                * Older years: fincbtax, fsalaryx
                * Newer years (2004+): fincbtxm, fsalarym
                capture confirm variable fincbtax
                if _rc {
                    capture confirm variable fincbtxm
                    if !_rc {
                        rename fincbtxm fincbtax
                    }
                }
                capture confirm variable fsalaryx
                if _rc {
                    capture confirm variable fsalarym
                    if !_rc {
                        rename fsalarym fsalaryx
                    }
                }
                
                * Apply deflation to income
                capture confirm variable fincbtax
                if !_rc {
                    replace fincbtax = fincbtax / cpi_u * 100
                }
                capture confirm variable fsalaryx
                if !_rc {
                    replace fsalaryx = fsalaryx / cpi_u * 100
                }
                drop cpi_u
                
                * Compute income Ginis (exclude zeros/missing)
                preserve
                drop if missing(fincbtax) | fincbtax <= 0
                if _N > 0 {
                    capture ineqdeco fincbtax [aw = FINLWT21]
                    if !_rc {
                        scalar g_fincbtax = r(gini)
                    }
                }
                restore
                
                preserve
                drop if missing(fsalaryx) | fsalaryx <= 0
                if _N > 0 {
                    capture ineqdeco fsalaryx [aw = FINLWT21]
                    if !_rc {
                        scalar g_fsalaryx = r(gini)
                    }
                }
                restore
            }

            * #region agent log
            * Debug: income Gini computed for this year/quarter
            display "DEBUG deflate inc: year=" `y' " q=" `q' " N=" _N " g_fincbtax=" g_fincbtax " g_fsalaryx=" g_fsalaryx
            * #endregion
            
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
* 3. Create quarterly panel
****************************************************
use `gini_results', clear

* Create qdate
gen qdate = yq(year, quarter)
format qdate %tq

* Sort
sort year quarter

display _n "=== Gini Panel Summary ==="
count
display "Total observations: " r(N)
summarize gini_core gini_broad gini_fincbtax gini_fsalaryx

****************************************************
* 4. Merge with RR shocks
****************************************************
display _n "=== Merging RR Shocks ==="

* Save Gini panel temporarily
tempfile gini_panel
save `gini_panel', replace

* Load RR shocks
use "$rr_shocks", clear

* Expect variables: year, quarter, sh_rr
capture confirm variable year quarter sh_rr
if _rc {
    display "ERROR: Expected variables year, quarter, sh_rr not all found in RR shocks file"
    describe
    exit 111
}

* Restrict to 1990-2008
keep if year >= 1990 & year <= 2008

* Sort for merge
sort year quarter

tempfile rr
save `rr', replace

* Merge into Gini panel
use `gini_panel', clear
sort year quarter

merge 1:1 year quarter using `rr'

display _n "Merge result:"
tab _merge

* Keep only matched observations
keep if _merge == 3
drop _merge

* Sanity check
summarize sh_rr
display "Non-missing sh_rr observations: " r(N)

****************************************************
* 5. Save final merged file
****************************************************
sort year quarter
save "$robust_data/gini_rr_merged_deflate.dta", replace

display _n "========================================"
display "TOGGLE COMPLETE: CPI Deflation"
display "========================================"
display "Saved: $robust_data/gini_rr_merged_deflate.dta"
display "Observations: " _N
display "Date range: " year[1] "q" quarter[1] " to " year[_N] "q" quarter[_N]
display "========================================" _n

****************************************************
* 6. Run Local Projections and Export IRFs
****************************************************
display _n "=== Running Local Projections ==="

* Reload merged file for LPs
use "$robust_data/gini_rr_merged_deflate.dta", clear

* Declare time series
tsset qdate, quarterly

* LP Specification
local H 20          // horizons (quarters): 0 to 20
local p 4           // number of lags for controls
local shocks "sh_rr"
local outcomes "gini_core gini_broad gini_fincbtax gini_fsalaryx"
local toggle_name "deflate"

* Create output directories
capture confirm global robust_tables
if _rc {
    global robust_tables "$robust_data/../Tables"
}
capture confirm global robust_figures
if _rc {
    global robust_figures "$robust_data/../Figures"
}
capture mkdir "$robust_tables"
capture mkdir "$robust_figures"

* Local Projections Loop
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
        
        * Skip horizons with no variation / all missing
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

* Process and Export Results
use `results', clear
rename h horizon
sort outcome shock_type horizon

export delimited using "$robust_tables/lp_irf_results_rr_`toggle_name'.csv", replace
display "Saved: $robust_tables/lp_irf_results_rr_`toggle_name'.csv"

* Create IRF Plots
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
