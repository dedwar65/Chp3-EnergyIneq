****************************************************
* 11_toggle_cgk_spec.do
* Toggle: CGK Full Specification (All Methodological Adjustments)
*
* Inputs:
*   - $deriv/cons_YYYY_cuq.dta (1990-2008)
*   - $deriv/income_YYYY_cuq.dta (1990-2008)
*   - FMLI files for demographics
*   - $fred/CPIAUCSL.csv (CPI data)
*   - RR shocks file
*
* Output:
*   - $robust_data/gini_rr_merged_cgk_spec.dta
*
* Methodology (applied in sequence):
*   1. CPI Deflation (1982-84 base)
*   2. OECD Equivalence Scale
*   3. Winsorization (1st/99th percentiles)
*   4. Zero Exclusion
*   5. Residual Inequality (regress log on demographics on FULL PANEL)
*   6. Frequency Weights [fw=fwt] where fwt = round(FINLWT21/3)
*   7. Inequality Command: ineqdec0
*
* Note: Both consumption and income Ginis are recomputed with all toggles
*       Residualization is done on FULL PANEL (like CGK), then Ginis computed quarter-by-quarter
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
global fred "/Volumes/SSD PRO/Github-forks/Chp3-EnergyIneq/Code/Data/FRED"
global rr_shocks "/Volumes/SSD PRO/Downloads/replication_folder/source_files/RR_shocks_updated.dta"

* Ensure inequality command is installed
capture which ineqdec0
if _rc ssc install ineqdec0

display _n "========================================"
display "TOGGLE: CGK Full Specification"
display "========================================" _n

****************************************************
* 1. Load CPI Data (1982-84 base = 100)
****************************************************
display _n "=== Loading CPI Data ==="
import delimited "$fred/CPIAUCSL.csv", clear
gen date = date(observation_date, "YMD")
format date %td
gen year = year(date)
gen month = month(date)
gen quarter = ceil(month/3)
rename cpiaucsl cpi_u
collapse (mean) cpi_u, by(year quarter)
gen qdate = yq(year, quarter)
format qdate %tq
keep if year >= 1990 & year <= 2008
tempfile cpi_data
save `cpi_data', replace
display "CPI loaded: " _N " quarterly observations (1990-2008)"

****************************************************
* 2. Build Full Panel: Consumption Data (1990-2008)
****************************************************
display _n "=== Building Full Consumption Panel (1990-2008) ==="

clear
local first = 1
forvalues y = 1990/2008 {
    capture confirm file "$deriv/cons_`y'_cuq.dta"
    if _rc continue
    
    display "  Loading consumption data for year `y'..."
    if `first' == 1 {
        use "$deriv/cons_`y'_cuq.dta", clear
        * Ensure year and quarter variables exist and are correct
        capture confirm variable year
        if _rc {
            gen year = `y'
        }
        else {
            replace year = `y' if missing(year)
        }
        capture confirm variable quarter
        if _rc {
            display "  ERROR: quarter variable missing in cons_`y'_cuq.dta"
            continue
        }
        * Check if quarter has missing values
        quietly count if missing(quarter)
        if r(N) > 0 {
            display "  WARNING: " r(N) " observations with missing quarter in year `y'"
        }
        keep NEWID year quarter cons_core_q cons_broad_q FINLWT21
        * Drop observations with missing quarter (can't use them)
        drop if missing(quarter)
        local first = 0
    }
    else {
        preserve
        use "$deriv/cons_`y'_cuq.dta", clear
        * Ensure year and quarter variables exist and are correct
        capture confirm variable year
        if _rc {
            gen year = `y'
        }
        else {
            replace year = `y' if missing(year)
        }
        capture confirm variable quarter
        if _rc {
            display "  ERROR: quarter variable missing in cons_`y'_cuq.dta"
            restore
            continue
        }
        * Check if quarter has missing values
        quietly count if missing(quarter)
        if r(N) > 0 {
            display "  WARNING: " r(N) " observations with missing quarter in year `y'"
        }
        keep NEWID year quarter cons_core_q cons_broad_q FINLWT21
        * Drop observations with missing quarter (can't use them)
        drop if missing(quarter)
        tempfile append_cons
        save `append_cons', replace
        restore
        append using `append_cons'
    }
}

display "  Total consumption observations: " _N
* Debug: Check observations by year
quietly count if year >= 1990 & year <= 1995
display "  Observations for 1990-1995: " r(N)
quietly count if year >= 1996 & year <= 2008
display "  Observations for 1996-2008: " r(N)
quietly summarize year, detail
display "  Consumption data year range: " r(min) " to " r(max)
quietly tab year if year >= 1990 & year <= 1995, missing
display "  Consumption data years 1990-1995 present: " r(r)

****************************************************
* 3. Merge CPI Data
****************************************************
gen qdate = yq(year, quarter)
format qdate %tq
merge m:1 qdate using `cpi_data', keepusing(cpi_u)
quietly count if _merge == 3 & year >= 1990 & year <= 1995
display "  CPI merge matches for 1990-1995: " r(N)
quietly count if _merge == 3 & year >= 1996 & year <= 2008
display "  CPI merge matches for 1996-2008: " r(N)
keep if _merge == 3
drop _merge

* Apply CPI Deflation
replace cons_core_q = cons_core_q / cpi_u * 100
replace cons_broad_q = cons_broad_q / cpi_u * 100
drop cpi_u qdate

display "  Applied CPI deflation"
quietly count if year >= 1990 & year <= 1995 & !missing(cons_core_q, cons_broad_q)
display "  Valid consumption observations for 1990-1995 after deflation: " r(N)

* Ensure NEWID is numeric (critical for merge)
capture confirm numeric variable NEWID
if _rc {
    destring NEWID, replace
}

* Save consumption panel (before building FMLI panel)
tempfile cons_panel
save `cons_panel', replace

****************************************************
* 4. Merge FMLI Demographics (Full Panel)
****************************************************
display _n "=== Merging FMLI Demographics (Full Panel) ==="

* Build full FMLI panel
clear
local first = 1
forvalues y = 1990/2008 {
    local yr_suffix = substr(string(`y'), 3, 2)
    local intr_path "$intr_base/intrvw`yr_suffix'"
    
    * Determine FMLI file pattern for this year
    if `y' < 1996 {
        forvalues q = 1/4 {
            capture confirm file "`intr_path'/fmli`yr_suffix'`q'.dta"
            if !_rc {
                if `first' == 1 {
                    use "`intr_path'/fmli`yr_suffix'`q'.dta", clear
                    capture rename newid NEWID
                    capture rename finlwt21 FINLWT21
                    capture rename famsize FAM_SIZE
                    capture rename fam_size FAM_SIZE
                    capture rename v980010 FAM_SIZE
                    capture rename perslt18 PERSLT18
                    capture rename v980050 PERSLT18
                    capture rename age_ref AGE_REF
                    capture rename educ_ref EDUC_REF
                    capture rename sex_ref SEX_REF
                    capture rename ref_race REF_RACE
                    keep NEWID FAM_SIZE PERSLT18 AGE_REF EDUC_REF SEX_REF REF_RACE
                    gen year = `y'
                    gen quarter = `q'
                    local first = 0
                }
                else {
                    preserve
                    use "`intr_path'/fmli`yr_suffix'`q'.dta", clear
                    capture rename newid NEWID
                    capture rename finlwt21 FINLWT21
                    capture rename famsize FAM_SIZE
                    capture rename fam_size FAM_SIZE
                    capture rename v980010 FAM_SIZE
                    capture rename perslt18 PERSLT18
                    capture rename v980050 PERSLT18
                    capture rename age_ref AGE_REF
                    capture rename educ_ref EDUC_REF
                    capture rename sex_ref SEX_REF
                    capture rename ref_race REF_RACE
                    keep NEWID FAM_SIZE PERSLT18 AGE_REF EDUC_REF SEX_REF REF_RACE
                    gen year = `y'
                    gen quarter = `q'
                    tempfile append_fmli
                    save `append_fmli', replace
                    restore
                    append using `append_fmli'
                }
            }
        }
    }
    else if `y' >= 1996 & `y' < 2018 {
        local q_map "1 1x 2 3 4"
        local q_idx = 1
        foreach qval in `q_map' {
            capture confirm file "`intr_path'/fmli`yr_suffix'`qval'.dta"
            if !_rc {
                if `first' == 1 {
                    use "`intr_path'/fmli`yr_suffix'`qval'.dta", clear
                    capture rename newid NEWID
                    capture rename finlwt21 FINLWT21
                    capture rename famsize FAM_SIZE
                    capture rename fam_size FAM_SIZE
                    capture rename v980010 FAM_SIZE
                    capture rename perslt18 PERSLT18
                    capture rename v980050 PERSLT18
                    capture rename age_ref AGE_REF
                    capture rename educ_ref EDUC_REF
                    capture rename sex_ref SEX_REF
                    capture rename ref_race REF_RACE
                    keep NEWID FAM_SIZE PERSLT18 AGE_REF EDUC_REF SEX_REF REF_RACE
                    gen year = `y'
                    gen quarter = `q_idx'
                    local first = 0
                }
                else {
                    preserve
                    use "`intr_path'/fmli`yr_suffix'`qval'.dta", clear
                    capture rename newid NEWID
                    capture rename finlwt21 FINLWT21
                    capture rename famsize FAM_SIZE
                    capture rename fam_size FAM_SIZE
                    capture rename v980010 FAM_SIZE
                    capture rename perslt18 PERSLT18
                    capture rename v980050 PERSLT18
                    capture rename age_ref AGE_REF
                    capture rename educ_ref EDUC_REF
                    capture rename sex_ref SEX_REF
                    capture rename ref_race REF_RACE
                    keep NEWID FAM_SIZE PERSLT18 AGE_REF EDUC_REF SEX_REF REF_RACE
                    gen year = `y'
                    gen quarter = `q_idx'
                    tempfile append_fmli
                    save `append_fmli', replace
                    restore
                    append using `append_fmli'
                }
            }
            local q_idx = `q_idx' + 1
        }
    }
    else {
        local q_map "1x 2 3 4 1"
        local q_idx = 1
        foreach qval in `q_map' {
            capture confirm file "`intr_path'/fmli`yr_suffix'`qval'.dta"
            if !_rc {
                if `first' == 1 {
                    use "`intr_path'/fmli`yr_suffix'`qval'.dta", clear
                    capture rename newid NEWID
                    capture rename finlwt21 FINLWT21
                    capture rename famsize FAM_SIZE
                    capture rename fam_size FAM_SIZE
                    capture rename v980010 FAM_SIZE
                    capture rename perslt18 PERSLT18
                    capture rename v980050 PERSLT18
                    capture rename age_ref AGE_REF
                    capture rename educ_ref EDUC_REF
                    capture rename sex_ref SEX_REF
                    capture rename ref_race REF_RACE
                    keep NEWID FAM_SIZE PERSLT18 AGE_REF EDUC_REF SEX_REF REF_RACE
                    gen year = `y'
                    gen quarter = `q_idx'
                    local first = 0
                }
                else {
                    preserve
                    use "`intr_path'/fmli`yr_suffix'`qval'.dta", clear
                    capture rename newid NEWID
                    capture rename finlwt21 FINLWT21
                    capture rename famsize FAM_SIZE
                    capture rename fam_size FAM_SIZE
                    capture rename v980010 FAM_SIZE
                    capture rename perslt18 PERSLT18
                    capture rename v980050 PERSLT18
                    capture rename age_ref AGE_REF
                    capture rename educ_ref EDUC_REF
                    capture rename sex_ref SEX_REF
                    capture rename ref_race REF_RACE
                    keep NEWID FAM_SIZE PERSLT18 AGE_REF EDUC_REF SEX_REF REF_RACE
                    gen year = `y'
                    gen quarter = `q_idx'
                    tempfile append_fmli
                    save `append_fmli', replace
                    restore
                    append using `append_fmli'
                }
            }
            local q_idx = `q_idx' + 1
        }
    }
}

* Apply CGK's fix for PERSLT18
replace PERSLT18 = FAM_SIZE - 1 if PERSLT18 >= FAM_SIZE & FAM_SIZE ~= . & PERSLT18 ~= .

* Ensure year and quarter are numeric and sorted
capture confirm numeric variable year
if _rc destring year, replace
capture confirm numeric variable quarter
if _rc destring quarter, replace

* Ensure NEWID is numeric (critical for merge)
capture confirm numeric variable NEWID
if _rc {
    destring NEWID, replace
}
sort NEWID year quarter

tempfile fmli_panel
save `fmli_panel', replace
display "  FMLI panel: " _N " observations"
quietly count if year >= 1990 & year <= 1995
display "  FMLI observations for 1990-1995: " r(N)

* Merge demographics with consumption
use `cons_panel', clear

* Ensure NEWID is numeric before merge
capture confirm numeric variable NEWID
if _rc {
    destring NEWID, replace
}
sort NEWID year quarter

* Check consumption panel before merge
quietly count if year >= 1990 & year <= 1995
display "  Consumption panel obs for 1990-1995 before merge: " r(N)
quietly count if year >= 1996 & year <= 2008
display "  Consumption panel obs for 1996-2008 before merge: " r(N)

merge m:1 NEWID year quarter using `fmli_panel'
quietly count if _merge == 1 & year >= 1990 & year <= 1995
display "  Consumption-only (no FMLI match) for 1990-1995: " r(N)
quietly count if _merge == 2 & year >= 1990 & year <= 1995
display "  FMLI-only (no consumption match) for 1990-1995: " r(N)
quietly count if _merge == 3 & year >= 1990 & year <= 1995
display "  FMLI merge matches for 1990-1995: " r(N)
quietly count if _merge == 3 & year >= 1996 & year <= 2008
display "  FMLI merge matches for 1996-2008: " r(N)
keep if _merge == 3 | _merge == 1
drop _merge
quietly count if year >= 1990 & year <= 1995 & !missing(cons_core_q, cons_broad_q)
display "  Valid consumption observations for 1990-1995 after FMLI merge: " r(N)

display "  Merged consumption with demographics: " _N " observations"

****************************************************
* 5. Apply OECD Equivalence Scale
****************************************************
display _n "=== Applying OECD Equivalence Scale ==="

* OECD_ES = 1 + 0.5*(FAM_SIZE-1) + 0.2*(FAM_SIZE-PERSLT18)
* Only apply if demographics are available
gen OECD_ES = .
replace OECD_ES = 1 + 0.5*(FAM_SIZE-1) + 0.2*(FAM_SIZE-PERSLT18) if !missing(FAM_SIZE, PERSLT18)

* Check how many observations have demographics
quietly count if year >= 1990 & year <= 1995 & !missing(FAM_SIZE, PERSLT18)
display "  Observations with demographics for 1990-1995: " r(N)
quietly count if year >= 1996 & year <= 2008 & !missing(FAM_SIZE, PERSLT18)
display "  Observations with demographics for 1996-2008: " r(N)

* Apply equivalence scale to consumption (only where OECD_ES is not missing)
replace cons_core_q  = cons_core_q  / OECD_ES if !missing(OECD_ES)
replace cons_broad_q = cons_broad_q / OECD_ES if !missing(OECD_ES)

display "  Applied equivalence scale"
quietly count if year >= 1990 & year <= 1995 & !missing(cons_core_q, cons_broad_q) & cons_core_q > 0 & cons_broad_q > 0
display "  Valid consumption observations for 1990-1995 after equivalence: " r(N)

****************************************************
* 6. Winsorization (1st and 99th percentiles)
****************************************************
display _n "=== Applying Winsorization ==="

* Create frequency weights
gen fwt = round(FINLWT21/3)

* Winsorize cons_core_q
quietly summarize cons_core_q [fw = fwt] if cons_core_q > 0, detail
local p1_core = r(p1)
local p99_core = r(p99)
replace cons_core_q = `p1_core' if cons_core_q < `p1_core' & cons_core_q != . & cons_core_q > 0
replace cons_core_q = `p99_core' if cons_core_q > `p99_core' & cons_core_q != . & cons_core_q > 0

* Winsorize cons_broad_q
quietly summarize cons_broad_q [fw = fwt] if cons_broad_q > 0, detail
local p1_broad = r(p1)
local p99_broad = r(p99)
replace cons_broad_q = `p1_broad' if cons_broad_q < `p1_broad' & cons_broad_q != . & cons_broad_q > 0
replace cons_broad_q = `p99_broad' if cons_broad_q > `p99_broad' & cons_broad_q != . & cons_broad_q > 0

display "  Applied winsorization (p1, p99)"

****************************************************
* 7. Create Time Dummies and Residualize (FULL PANEL)
****************************************************
display _n "=== Computing Residual Inequality (Full Panel) ==="

* Create quarter identifier (1990q1 = 1, 1990q2 = 2, ..., 2008q4 = 76)
gen qnum = (year - 1990) * 4 + quarter

* Create time dummies (like CGK: tx_* for each quarter)
forvalues qnum_val = 1/76 {
    gen tx_`qnum_val' = (qnum == `qnum_val')
}

* Create log consumption
gen ln_cons_core  = log(cons_core_q)  if cons_core_q > 0
gen ln_cons_broad = log(cons_broad_q) if cons_broad_q > 0

* Create demographic dummies (like CGK)
* AGE polynomials
capture confirm variable AGE_REF
if !_rc {
    capture confirm numeric variable AGE_REF
    if _rc {
        destring AGE_REF, replace
    }
    gen AGE_REF2 = AGE_REF^2
    gen AGE_REF3 = AGE_REF^3
    gen AGE_REF4 = AGE_REF^4
}

* Ensure SEX_REF is numeric
capture confirm variable SEX_REF
if !_rc {
    capture confirm numeric variable SEX_REF
    if _rc {
        destring SEX_REF, replace
    }
}

* Education dummies
capture confirm variable EDUC_REF
if !_rc {
    * Ensure EDUC_REF is numeric
    capture confirm numeric variable EDUC_REF
    if _rc {
        * Convert string to numeric
        destring EDUC_REF, replace
    }
    * Create education dummies
    forvalues edu = 2/6 {
        gen EDU_`edu' = (EDUC_REF == `edu')
    }
    replace EDU_6 = 1 if EDUC_REF == 7
}

* Family size dummies
capture confirm variable FAM_SIZE
if !_rc {
    capture confirm numeric variable FAM_SIZE
    if _rc {
        destring FAM_SIZE, replace
    }
    forvalues size = 2/7 {
        gen SIZE_`size' = (FAM_SIZE == `size')
    }
    replace SIZE_7 = 1 if FAM_SIZE >= 7 & FAM_SIZE ~= .
}

* Children dummies
capture confirm variable PERSLT18
if !_rc {
    capture confirm numeric variable PERSLT18
    if _rc {
        destring PERSLT18, replace
    }
    forvalues kid = 1/4 {
        gen KID_`kid' = (PERSLT18 == `kid')
    }
    replace KID_4 = 1 if PERSLT18 >= 4 & PERSLT18 ~= .
}

* Race dummies
capture confirm variable REF_RACE
if !_rc {
    capture confirm numeric variable REF_RACE
    if _rc {
        destring REF_RACE, replace
    }
    gen race_2 = (REF_RACE == 2)
    gen race_4 = (REF_RACE == 4)
    gen race_5 = (REF_RACE == 3 | REF_RACE == 5 | REF_RACE == 6)
}

* Number of earners (if available - will be missing for some years, that's OK)
* CGK uses Nearn_* but we don't have this, so we'll skip it

* Regress log consumption on demographics (FULL PANEL)
* Use analytic weights for regression (like CGK: [iw=fwt])
* Check if we have enough observations for regression
quietly count if !missing(ln_cons_core, AGE_REF, EDUC_REF, SEX_REF, REF_RACE, FAM_SIZE)
local N_core_reg = r(N)
if `N_core_reg' > 100 {
    capture noisily regress ln_cons_core tx_* race_* KID_* SIZE_* EDU_* AGE_REF4 AGE_REF3 AGE_REF2 AGE_REF SEX_REF [iw = fwt]
    if !_rc {
        predict resid_core if e(sample), residuals
        gen res_cons_core = exp(resid_core) if !missing(resid_core)
        replace cons_core_q = res_cons_core if !missing(res_cons_core)
        drop resid_core res_cons_core
        display "  Residualized cons_core (full panel): " `N_core_reg' " observations"
    }
    else {
        display "  WARNING: Residualization regression failed for cons_core, using winsorized values"
    }
}
else {
    display "  WARNING: Too few observations for residualization (N=" `N_core_reg' "), using winsorized values"
}

quietly count if !missing(ln_cons_broad, AGE_REF, EDUC_REF, SEX_REF, REF_RACE, FAM_SIZE)
local N_broad_reg = r(N)
if `N_broad_reg' > 100 {
    capture noisily regress ln_cons_broad tx_* race_* KID_* SIZE_* EDU_* AGE_REF4 AGE_REF3 AGE_REF2 AGE_REF SEX_REF [iw = fwt]
    if !_rc {
        predict resid_broad if e(sample), residuals
        gen res_cons_broad = exp(resid_broad) if !missing(resid_broad)
        replace cons_broad_q = res_cons_broad if !missing(res_cons_broad)
        drop resid_broad res_cons_broad
        display "  Residualized cons_broad (full panel): " `N_broad_reg' " observations"
    }
    else {
        display "  WARNING: Residualization regression failed for cons_broad, using winsorized values"
    }
}
else {
    display "  WARNING: Too few observations for residualization (N=" `N_broad_reg' "), using winsorized values"
}

* Clean up
drop ln_cons_core ln_cons_broad tx_* AGE_REF2 AGE_REF3 AGE_REF4 EDU_* SIZE_* KID_* race_* qnum OECD_ES

* Save processed consumption panel
save `cons_panel', replace
quietly count if year >= 1990 & year <= 1995 & !missing(cons_core_q, cons_broad_q) & cons_core_q > 0 & cons_broad_q > 0
display "  Final valid consumption observations for 1990-1995: " r(N)

****************************************************
* 8. Process Income Data (Same Steps)
****************************************************
display _n "=== Processing Income Data (Full Panel) ==="

* Build full income panel
clear
local first = 1
forvalues y = 1990/2008 {
    capture confirm file "$deriv/income_`y'_cuq.dta"
    if _rc continue
    
    if `first' == 1 {
        use "$deriv/income_`y'_cuq.dta", clear
        * Ensure year and quarter variables exist and are correct
        capture confirm variable year
        if _rc {
            gen year = `y'
        }
        else {
            replace year = `y' if missing(year)
        }
        capture confirm variable quarter
        if _rc {
            display "  ERROR: quarter variable missing in income_`y'_cuq.dta"
            continue
        }
        * Check if quarter has missing values
        quietly count if missing(quarter)
        if r(N) > 0 {
            display "  WARNING: " r(N) " observations with missing quarter in year `y'"
        }
        * Handle variable name differences BEFORE keeping
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
        * Build keep list dynamically
        local keep_vars "NEWID year quarter FINLWT21"
        capture confirm variable fincbtax
        if !_rc local keep_vars "`keep_vars' fincbtax"
        capture confirm variable fsalaryx
        if !_rc local keep_vars "`keep_vars' fsalaryx"
        keep `keep_vars'
        * Drop observations with missing quarter (can't use them)
        drop if missing(quarter)
        local first = 0
    }
    else {
        preserve
        use "$deriv/income_`y'_cuq.dta", clear
        * Ensure year and quarter variables exist and are correct
        capture confirm variable year
        if _rc {
            gen year = `y'
        }
        else {
            replace year = `y' if missing(year)
        }
        capture confirm variable quarter
        if _rc {
            display "  ERROR: quarter variable missing in income_`y'_cuq.dta"
            restore
            continue
        }
        * Check if quarter has missing values
        quietly count if missing(quarter)
        if r(N) > 0 {
            display "  WARNING: " r(N) " observations with missing quarter in year `y'"
        }
        * Handle variable name differences BEFORE keeping
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
        * Build keep list dynamically
        local keep_vars "NEWID year quarter FINLWT21"
        capture confirm variable fincbtax
        if !_rc local keep_vars "`keep_vars' fincbtax"
        capture confirm variable fsalaryx
        if !_rc local keep_vars "`keep_vars' fsalaryx"
        keep `keep_vars'
        * Drop observations with missing quarter (can't use them)
        drop if missing(quarter)
        tempfile append_inc
        save `append_inc', replace
        restore
        append using `append_inc'
    }
}

display "  Total income observations: " _N
* Debug: Check which years are present
quietly tab year if year >= 1990 & year <= 1995, missing
display "  Income data years 1990-1995: " r(r)
quietly tab year if year >= 1996 & year <= 2008, missing
display "  Income data years 1996-2008: " r(r)
quietly summarize year, detail
display "  Income data year range: " r(min) " to " r(max)

* Merge CPI
gen qdate = yq(year, quarter)
format qdate %tq
merge m:1 qdate using `cpi_data', keepusing(cpi_u)
keep if _merge == 3
drop _merge qdate

* Apply CPI Deflation
replace fincbtax = fincbtax / cpi_u * 100
replace fsalaryx = fsalaryx / cpi_u * 100
drop cpi_u

* Merge demographics
* Ensure year and quarter are numeric and sorted
capture confirm numeric variable year
if _rc destring year, replace
capture confirm numeric variable quarter
if _rc destring quarter, replace
sort NEWID year quarter

* Note: FMLI panel has year and quarter, so merge on all three keys
merge m:1 NEWID year quarter using `fmli_panel'
display _n "Income-FMLI merge result:"
tab _merge
keep if _merge == 3 | _merge == 1
drop _merge
display "  Income observations with demographics: " _N

* Apply equivalence scale (only if demographics are available)
capture confirm variable FAM_SIZE PERSLT18
if !_rc {
    gen OECD_ES = 1 + 0.5*(FAM_SIZE-1) + 0.2*(FAM_SIZE-PERSLT18)
    replace fincbtax = fincbtax / OECD_ES if OECD_ES != .
    replace fsalaryx = fsalaryx / OECD_ES if OECD_ES != .
    drop OECD_ES
}
else {
    display "WARNING: Demographics not available for income, skipping equivalence scale"
}

* Winsorization
gen fwt = round(FINLWT21/3)

preserve
drop if missing(fincbtax) | fincbtax <= 0
quietly summarize fincbtax [fw = fwt], detail
if r(N) > 0 {
    local p1_fincbtax = r(p1)
    local p99_fincbtax = r(p99)
    replace fincbtax = `p1_fincbtax' if fincbtax < `p1_fincbtax'
    replace fincbtax = `p99_fincbtax' if fincbtax > `p99_fincbtax'
}
restore

preserve
drop if missing(fsalaryx) | fsalaryx <= 0
quietly summarize fsalaryx [fw = fwt], detail
if r(N) > 0 {
    local p1_fsalaryx = r(p1)
    local p99_fsalaryx = r(p99)
    replace fsalaryx = `p1_fsalaryx' if fsalaryx < `p1_fsalaryx'
    replace fsalaryx = `p99_fsalaryx' if fsalaryx > `p99_fsalaryx'
}
restore

* Residualization (full panel)
gen qnum = (year - 1990) * 4 + quarter
forvalues qnum_val = 1/76 {
    gen tx_`qnum_val' = (qnum == `qnum_val')
}

* Ensure variables are numeric and create dummies
capture confirm variable AGE_REF
if !_rc {
    capture confirm numeric variable AGE_REF
    if _rc {
        destring AGE_REF, replace
    }
    gen AGE_REF2 = AGE_REF^2
    gen AGE_REF3 = AGE_REF^3
    gen AGE_REF4 = AGE_REF^4
}

capture confirm variable SEX_REF
if !_rc {
    capture confirm numeric variable SEX_REF
    if _rc {
        destring SEX_REF, replace
    }
}

capture confirm variable EDUC_REF
if !_rc {
    capture confirm numeric variable EDUC_REF
    if _rc {
        destring EDUC_REF, replace
    }
    forvalues edu = 2/6 {
        gen EDU_`edu' = (EDUC_REF == `edu')
    }
    replace EDU_6 = 1 if EDUC_REF == 7
}

capture confirm variable FAM_SIZE
if !_rc {
    capture confirm numeric variable FAM_SIZE
    if _rc {
        destring FAM_SIZE, replace
    }
    forvalues size = 2/7 {
        gen SIZE_`size' = (FAM_SIZE == `size')
    }
    replace SIZE_7 = 1 if FAM_SIZE >= 7 & FAM_SIZE ~= .
}

capture confirm variable PERSLT18
if !_rc {
    capture confirm numeric variable PERSLT18
    if _rc {
        destring PERSLT18, replace
    }
    forvalues kid = 1/4 {
        gen KID_`kid' = (PERSLT18 == `kid')
    }
    replace KID_4 = 1 if PERSLT18 >= 4 & PERSLT18 ~= .
}

capture confirm variable REF_RACE
if !_rc {
    capture confirm numeric variable REF_RACE
    if _rc {
        destring REF_RACE, replace
    }
    gen race_2 = (REF_RACE == 2)
    gen race_4 = (REF_RACE == 4)
    gen race_5 = (REF_RACE == 3 | REF_RACE == 5 | REF_RACE == 6)
}

gen ln_fincbtax = log(fincbtax) if fincbtax > 0
gen ln_fsalaryx = log(fsalaryx) if fsalaryx > 0

preserve
drop if missing(fincbtax) | fincbtax <= 0
capture noisily regress ln_fincbtax tx_* race_* KID_* SIZE_* EDU_* AGE_REF4 AGE_REF3 AGE_REF2 AGE_REF SEX_REF [iw = fwt]
if !_rc {
    predict resid_fincbtax, residuals
    gen res_fincbtax = exp(resid_fincbtax)
    replace fincbtax = res_fincbtax
    drop resid_fincbtax res_fincbtax
}
drop ln_fincbtax
restore

preserve
drop if missing(fsalaryx) | fsalaryx <= 0
capture noisily regress ln_fsalaryx tx_* race_* KID_* SIZE_* EDU_* AGE_REF4 AGE_REF3 AGE_REF2 AGE_REF SEX_REF [iw = fwt]
if !_rc {
    predict resid_fsalaryx, residuals
    gen res_fsalaryx = exp(resid_fsalaryx)
    replace fsalaryx = res_fsalaryx
    drop resid_fsalaryx res_fsalaryx
}
drop ln_fsalaryx
restore

* Clean up (use capture drop for variables that might not exist)
capture drop tx_*
capture drop AGE_REF2 AGE_REF3 AGE_REF4
capture drop EDU_*
capture drop SIZE_*
capture drop KID_*
capture drop race_*
capture drop qnum OECD_ES fwt

tempfile income_panel
save `income_panel', replace
display "  Processed income panel: " _N " observations"

****************************************************
* 9. Compute Ginis Quarter-by-Quarter
****************************************************
display _n "=== Computing Ginis Quarter-by-Quarter ==="

* Reload consumption panel
use `cons_panel', clear

tempfile gini_results
postfile gini_post int year int quarter double gini_core double gini_broad ///
    double gini_fincbtax double gini_fsalaryx ///
    using `gini_results', replace

forvalues y = 1990/2008 {
    forvalues q = 1/4 {
        * Consumption Ginis
        preserve
        keep if year == `y' & quarter == `q'
        local N_before_drop = _N
        
        if `N_before_drop' == 0 {
            * No observations for this year-quarter in consumption panel
            if `y' <= 1995 {
                display "  WARNING: No consumption data for `y'q`q'"
            }
        }
        else {
            drop if cons_core_q <= 0 | cons_broad_q <= 0 | missing(cons_core_q) | missing(cons_broad_q)
            local N_after_drop = _N
            
            if `N_after_drop' == 0 & `N_before_drop' > 0 & `y' <= 1995 {
                display "  WARNING: All consumption data dropped for `y'q`q' (had " `N_before_drop' " obs before drop)"
            }
        }
        
        scalar gc = .
        scalar gb = .
        
        if _N > 0 {
            capture drop fwt
            gen fwt = round(FINLWT21/3)
            capture ineqdec0 cons_core_q [fw = fwt]
            if !_rc {
                scalar gc = r(gini)
            }
            capture ineqdec0 cons_broad_q [fw = fwt]
            if !_rc {
                scalar gb = r(gini)
            }
            drop fwt
        }
        restore
            
        * Income Ginis (load income panel separately, no preserve needed)
        use `income_panel', clear
        keep if year == `y' & quarter == `q'
        
        local N_income = _N
        if `N_income' == 0 & `y' <= 1995 {
            display "  WARNING: No income data for `y'q`q'"
        }
        
        scalar g_fincbtax = .
        scalar g_fsalaryx = .
        
        * Compute fincbtax Gini
        preserve
        drop if missing(fincbtax) | fincbtax <= 0
        if _N > 0 {
            capture drop fwt
            gen fwt = round(FINLWT21/3)
            capture ineqdec0 fincbtax [fw = fwt]
            if !_rc {
                scalar g_fincbtax = r(gini)
            }
            drop fwt
        }
        restore
        
        * Compute fsalaryx Gini
        preserve
        drop if missing(fsalaryx) | fsalaryx <= 0
        if _N > 0 {
            capture drop fwt
            gen fwt = round(FINLWT21/3)
            capture ineqdec0 fsalaryx [fw = fwt]
            if !_rc {
                scalar g_fsalaryx = r(gini)
            }
            drop fwt
        }
        restore
        
        * Reload consumption panel for next iteration
        use `cons_panel', clear
        
        * Post results
        post gini_post (`y') (`q') (gc) (gb) (g_fincbtax) (g_fsalaryx)
        
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
* 10. Create Quarterly Panel
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
* 11. Merge with RR Shocks
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
* 12. Save Final Merged File
****************************************************
sort year quarter
save "$robust_data/gini_rr_merged_cgk_spec.dta", replace

display _n "========================================"
display "TOGGLE COMPLETE: CGK Full Specification"
display "========================================"
display "Saved: $robust_data/gini_rr_merged_cgk_spec.dta"
display "Observations: " _N
display "Date range: " year[1] "q" quarter[1] " to " year[_N] "q" quarter[_N]
display "========================================" _n

****************************************************
* 12.5. Apply Center Three-Quarter Moving Average (CGK Methodology)
****************************************************
display _n "=== Applying Center Three-Quarter Moving Average ==="

use "$robust_data/gini_rr_merged_cgk_spec.dta", clear
tsset qdate, quarterly

* Check data before smoothing
display "Observations before smoothing: " _N
summarize year
display "Year range: " r(min) " to " r(max)

* Apply center three-quarter moving average to all 4 Gini measures
* Formula: gini_smooth[t] = (gini[t-1] + gini[t] + gini[t+1]) / 3
foreach var in gini_core gini_broad gini_fincbtax gini_fsalaryx {
    gen `var'_smooth = (L.`var' + `var' + F.`var') / 3
    replace `var' = `var'_smooth
    drop `var'_smooth
    display "  Applied moving average to `var'"
}

* Check data after smoothing (first and last quarters will be missing)
display _n "Observations after smoothing: " _N
quietly count if !missing(gini_core, gini_broad, gini_fincbtax, gini_fsalaryx)
display "Observations with all 4 Ginis non-missing: " r(N)
summarize year if !missing(gini_core)
display "Effective year range (non-missing): " r(min) " to " r(max)

* Save smoothed dataset (overwrite)
save "$robust_data/gini_rr_merged_cgk_spec.dta", replace
display "Saved smoothed Gini panel"

****************************************************
* 13. Run Local Projections and Export IRFs
****************************************************
display _n "=== Running Local Projections ==="

use "$robust_data/gini_rr_merged_cgk_spec.dta", clear
tsset qdate, quarterly

local H 20
local p 4
local shocks "sh_rr"
local outcomes "gini_core gini_broad gini_fincbtax gini_fsalaryx"
local toggle_name "cgk_spec"

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
    
    * Check if outcome variable has any non-missing data
    quietly count if !missing(`y')
    local N_outcome = r(N)
    display _n "Estimating LP for: `y' (non-missing obs: `N_outcome')"
    
    if `N_outcome' == 0 {
        display "  WARNING: No non-missing observations for `y', skipping"
        continue
    }
    
    local horizons_success = 0
    forvalues h = 0/`H' {
        quietly gen dyh = F`h'.`y' - L.`y'
        quietly count if !missing(dyh, `shocks', L1.`y')
        if r(N) == 0 {
            quietly drop dyh
            continue
        }
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
            local horizons_success = `horizons_success' + 1
        }
    }
    display "  Successfully estimated " `horizons_success' " horizons for `y'"
}

postclose IRF

use `results', clear
rename h horizon
sort outcome shock_type horizon

* Debug: Check which outcomes have data
display _n "=== IRF Results Summary ==="
quietly tab outcome, missing
display "Outcomes with IRF data:"
levelsof outcome, local(outlist)
foreach o of local outlist {
    quietly count if outcome == "`o'"
    display "  `o': " r(N) " observations"
}

export delimited using "$robust_tables/lp_irf_results_rr_`toggle_name'.csv", replace
display "Saved: $robust_tables/lp_irf_results_rr_`toggle_name'.csv"

levelsof outcome, local(outlist)
levelsof shock_type, local(shocklist)

display _n "Generating IRF plots for " r(r) " outcomes and " r(r) " shocks"

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
        graph display
        restore
    }
}

display _n "========================================"
display "LOCAL PROJECTIONS COMPLETE"
display "========================================"
display "Results table: $robust_tables/lp_irf_results_rr_`toggle_name'.csv"
display "IRF plots:    $robust_figures/irf_rr_*_`toggle_name'.png"
display "========================================" _n
