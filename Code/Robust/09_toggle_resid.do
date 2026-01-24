****************************************************
* 09_toggle_resid.do
* Toggle: Residual Inequality
*
* Inputs:
*   - $deriv/cons_YYYY_cuq.dta (1990-2008)
*   - $deriv/income_YYYY_cuq.dta (1990-2008)
*   - FMLI files for demographics
*   - RR shocks file
*
* Output:
*   - $robust_data/gini_rr_merged_resid.dta
*
* Methodology:
*   - Regress log consumption on demographics
*   - Compute Gini on residuals (exp(residuals))
*   - Recompute 4 Gini coefficients quarter-by-quarter
*   - Merge with RR shocks
*
* Note: This toggle requires merging FMLI files to get demographics
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
global rr_shocks "/Volumes/SSD PRO/Downloads/replication_folder/source_files/RR_shocks_updated.dta"

* Ensure inequality command is installed
capture which ineqdeco
if _rc ssc install ineqdeco

display _n "========================================"
display "TOGGLE: Residual Inequality"
display "========================================" _n

****************************************************
* 1. Compute Ginis on residuals
****************************************************
display _n "=== Computing Residual Inequality Ginis (1990-2008) ==="

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
            
            * Load FMLI data to get demographics (similar to equiv toggle)
            local yr_suffix = substr(string(`y'), 3, 2)
            local intr_path "$intr_base/intrvw`yr_suffix'"
            
            * Try to load FMLI file for this quarter (simplified - use same logic as equiv)
            local fmli_files ""
            if `y' < 1996 {
                forvalues fq = 1/4 {
                    if `fq' == `q' {
                        capture confirm file "`intr_path'/fmli`yr_suffix'`fq'.dta"
                        if !_rc local fmli_files "fmli`yr_suffix'`fq'"
                    }
                }
            }
            else if `y' >= 1996 & `y' < 2018 {
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
                local q_map "1x 2 3 4 1"
                local q_idx = 1
                foreach qval in `q_map' {
                    if `q_idx' == `q' {
                        capture confirm file "`intr_path'/fmli`yr_suffix'`qval'.dta"
                        if !_rc local fmli_files "fmli`yr_suffix'`qval'"
                    }
                    local q_idx = `q_idx' + 1
                }
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
                    
                    * Extract demographics
                    capture rename famsize FAM_SIZE
                    capture rename fam_size FAM_SIZE
                    capture rename age_ref AGE_REF
                    capture rename educ_ref EDUC_REF
                    capture rename sex_ref SEX_REF
                    capture rename ref_race REF_RACE
                    
                    * Keep only needed variables
                    keep NEWID FAM_SIZE AGE_REF EDUC_REF SEX_REF REF_RACE
                    
                    tempfile demographics
                    save `demographics', replace
                    restore
                    
                    * Merge demographics with consumption
                    merge m:1 NEWID using `demographics'
                    keep if _merge == 3 | _merge == 1
                    drop _merge
                }
            }
            
            * Compute residuals for consumption
            scalar gc = .
            scalar gb = .
            
            if _N > 0 {
                * Create log consumption
                gen ln_cons_core = log(cons_core_q) if cons_core_q > 0
                gen ln_cons_broad = log(cons_broad_q) if cons_broad_q > 0
                
                * Regress log consumption on demographics (if available)
                capture confirm variable AGE_REF EDUC_REF SEX_REF REF_RACE FAM_SIZE
                if !_rc {
                    * Only proceed if we have usable observations for regression
                    quietly count if !missing(ln_cons_core, AGE_REF, EDUC_REF, SEX_REF, REF_RACE, FAM_SIZE)
                    local N_core = r(N)
                    quietly count if !missing(ln_cons_broad, AGE_REF, EDUC_REF, SEX_REF, REF_RACE, FAM_SIZE)
                    local N_broad = r(N)
                    
                    if `N_core' > 0 & `N_broad' > 0 {
                        * Regress and get residuals
                        capture noisily regress ln_cons_core AGE_REF EDUC_REF SEX_REF REF_RACE FAM_SIZE [aw = FINLWT21]
                        if !_rc {
                            predict resid_core if e(sample), residuals
                            
                            capture noisily regress ln_cons_broad AGE_REF EDUC_REF SEX_REF REF_RACE FAM_SIZE [aw = FINLWT21]
                            if !_rc {
                                predict resid_broad if e(sample), residuals
                                
                                * Convert residuals back to levels (exp(residuals))
                                gen res_cons_core = exp(resid_core)
                                gen res_cons_broad = exp(resid_broad)
                                
                                * Compute Gini on residuals
                                capture ineqdeco res_cons_core [aw = FINLWT21]
                                if !_rc {
                                    scalar gc = r(gini)
                                }
                                
                                capture ineqdeco res_cons_broad [aw = FINLWT21]
                                if !_rc {
                                    scalar gb = r(gini)
                                }
                            }
                        }
                        
                        * Clean up temporary variables (use capture in case some don't exist)
                        capture drop ln_cons_core ln_cons_broad resid_core resid_broad res_cons_core res_cons_broad
                    }
                    else {
                        * Fallback: not enough data for residualization, use regular consumption
                        capture ineqdeco cons_core_q [aw = FINLWT21]
                        if !_rc {
                            scalar gc = r(gini)
                        }
                        
                        capture ineqdeco cons_broad_q [aw = FINLWT21]
                        if !_rc {
                            scalar gb = r(gini)
                        }
                        
                        capture drop ln_cons_core ln_cons_broad
                    }
                }
                else {
                    * Demographics not available, use regular consumption
                    capture ineqdeco cons_core_q [aw = FINLWT21]
                    if !_rc {
                        scalar gc = r(gini)
                    }
                    
                    capture ineqdeco cons_broad_q [aw = FINLWT21]
                    if !_rc {
                        scalar gb = r(gini)
                    }
                    
                    * Clean up log variables if they were created
                    capture drop ln_cons_core ln_cons_broad
                }
            }
            
            * Income Ginis (no residualization for income)
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
save "$robust_data/gini_rr_merged_resid.dta", replace

display _n "========================================"
display "TOGGLE COMPLETE: Residual Inequality"
display "========================================"
display "Saved: $robust_data/gini_rr_merged_resid.dta"
display "Observations: " _N
display "========================================" _n

****************************************************
* 5. Run Local Projections and Export IRFs
****************************************************
display _n "=== Running Local Projections ==="

use "$robust_data/gini_rr_merged_resid.dta", clear
tsset qdate, quarterly

local H 20
local p 4
local shocks "sh_rr"
local outcomes "gini_core gini_broad gini_fincbtax gini_fsalaryx"
local toggle_name "resid"

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
