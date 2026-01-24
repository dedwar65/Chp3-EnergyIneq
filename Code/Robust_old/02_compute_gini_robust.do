****************************************************
* 02_compute_gini_robust.do
* Recompute Ginis with CGK methodological adjustments via toggles
* Called by individual toggle files (05-11) with toggle parameters
*
* Toggle parameters (passed as arguments):
*   deflate: 0 or 1 (CPI deflation to 1982-84 dollars)
*   equivalence: 0 or 1 (OECD equivalence scale)
*   weights_type: "fw" or "aw" (frequency vs analytic weights)
*   winsor: 0 or 1 (winsorize top/bottom 1%)
*   zeros: "include" or "exclude" (zero treatment)
*   residualize: 0 or 1 (residual inequality)
*   ineq_cmd: "ineqdec0" or "ineqdeco" (inequality command)
****************************************************

clear all
set more off

* Accept toggle parameters as arguments
args deflate equivalence weights_type winsor zeros residualize ineq_cmd toggle_shortname

* If no arguments provided, use defaults (baseline = all off)
if "`deflate'" == "" local deflate = 0
if "`equivalence'" == "" local equivalence = 0
if "`weights_type'" == "" local weights_type = "aw"
if "`winsor'" == "" local winsor = 0
if "`zeros'" == "" local zeros = "include"
if "`residualize'" == "" local residualize = 0
if "`ineq_cmd'" == "" local ineq_cmd = "ineqdeco"
if "`toggle_shortname'" == "" local toggle_shortname = "Baseline"

global deriv "/Volumes/SSD PRO/Github-forks/Chp3-EnergyIneq/Code/Data/CEX/derived"
global robust_data "/Volumes/SSD PRO/Github-forks/Chp3-EnergyIneq/Code/Robust/Data"
global fred "/Volumes/SSD PRO/Github-forks/Chp3-EnergyIneq/Code/Data/FRED"
global intr_base "/Volumes/SSD PRO/Github-forks/Chp3-EnergyIneq/Code/Data/CEX"

* Ensure inequality command is installed
capture which `ineq_cmd'
if _rc {
    if "`ineq_cmd'" == "ineqdec0" {
        ssc install ineqdec0
    }
    else {
        ssc install ineqdeco
    }
}

display _n "========================================"
display "COMPUTING GINIS WITH TOGGLES"
display "========================================"
display "Deflate: `deflate'"
display "Equivalence: `equivalence'"
display "Weights: `weights_type'"
display "Winsor: `winsor'"
display "Zeros: `zeros'"
display "Residualize: `residualize'"
display "Ineq command: `ineq_cmd'"
display "========================================" _n

****************************************************
* 1. Load CPI for deflation (if needed)
****************************************************
if `deflate' == 1 {
    display _n "=== Loading CPI for Deflation ==="
    
    * Import monthly CPI from FRED
    import delimited "$fred/CPIAUCSL.csv", clear
    
    * Parse date
    gen date = date(observation_date, "YMD")
    format date %td
    gen year = year(date)
    gen month = month(date)
    gen quarter = ceil(month/3)
    
    * Rename and compute CPI level (1982-84 base = 100)
    rename cpiaucsl cpi_raw
    * CPI is already indexed to 1982-84 = 100, but we'll normalize to ensure
    * Find average CPI for 1982-1984 (without preserve to avoid system temp)
    quietly summarize cpi_raw if year >= 1982 & year <= 1984
    local cpi_base = r(mean)
    
    * Normalize to 1982-84 average = 100
    gen cpi_u = (cpi_raw / `cpi_base') * 100
    
    * Collapse to quarterly (average monthly CPI within quarter)
    collapse (mean) cpi_u, by(year quarter)
    
    * Create qdate for merging
    gen qdate = yq(year, quarter)
    format qdate %tq
    
    * Save to workspace (SSD) instead of tempfile (which uses system temp)
    local cpi_monthly = "$robust_data/temp_cpi_monthly.dta"
    save "`cpi_monthly'"
    
    display "CPI loaded: " _N " quarterly observations"
    display "CPI base (1982-84 avg): `cpi_base'"
}

****************************************************
* 2. Load consumption data (use pre-loaded base data if available)
****************************************************
display _n "=== Loading Consumption Data ==="

* OPTIMIZED: Check if base consumption data exists (can be pre-loaded for efficiency)
capture confirm file "$robust_data/base_consumption_data.dta"
if !_rc {
    display "Loading from pre-loaded base consumption data (optimization)"
    use "$robust_data/base_consumption_data.dta", clear
    display "Loaded base consumption data: " _N " observations"
}
else {
    display "Base consumption data not found. Loading from scratch..."
    
    * Fallback: Load from scratch (original method)
    * OPTIMIZATION: Only process up to 2008 since CGK shocks end at 2008
    local first_year = 1990
    local last_year = 2008
    
    * Load first year's tagged consumption data
    use "$deriv/mtbi_`first_year'_tagged.dta", clear
    
    * STANDARDIZE VARIABLE TYPES for first year
    capture confirm variable NEWID
    if !_rc {
        capture confirm string variable NEWID
        if !_rc {
            destring NEWID, replace
        }
        capture recast double NEWID
    }
    capture confirm variable UCC
    if !_rc {
        capture confirm string variable UCC
        if !_rc {
            destring UCC, replace
        }
        capture recast double UCC
    }
    capture confirm variable COST
    if !_rc {
        capture confirm string variable COST
        if !_rc {
            destring COST, replace
        }
        capture recast double COST
    }
    capture confirm variable cons_core_item
    if !_rc {
        capture confirm string variable cons_core_item
        if !_rc {
            destring cons_core_item, replace
        }
        capture recast double cons_core_item
    }
    capture confirm variable cons_broad_item
    if !_rc {
        capture confirm string variable cons_broad_item
        if !_rc {
            destring cons_broad_item, replace
        }
        capture recast double cons_broad_item
    }
    
    capture confirm variable year
    if _rc {
        gen year = `first_year'
    }
    else {
        replace year = `first_year'
    }
    
    * Save first year as initial master (for error recovery)
    save "$robust_data/temp_current_master.dta", replace
    
    * OPTIMIZED: Append remaining years efficiently
    * Strategy: Standardize new year BEFORE appending (faster - operates on smaller file)
    * Then append to master. This avoids standardizing the growing master dataset.
    forvalues y = `=`first_year'+1'/`last_year' {
        display "Loading year `y'..."
        
        capture {
            * Load new year first (smaller file, faster to standardize)
            use "$deriv/mtbi_`y'_tagged.dta", clear
            
            * Fast standardization: only if needed (check first to avoid slow operations)
            * NEWID
            capture confirm variable NEWID
            if !_rc {
                capture confirm string variable NEWID
                if !_rc {
                    quietly destring NEWID, replace
                }
                capture confirm numeric variable NEWID
                if !_rc {
                    quietly recast double NEWID, force
                }
            }
            
            * UCC
            capture confirm variable UCC
            if !_rc {
                capture confirm string variable UCC
                if !_rc {
                    quietly destring UCC, replace
                }
                capture confirm numeric variable UCC
                if !_rc {
                    quietly recast double UCC, force
                }
            }
            
            * COST
            capture confirm variable COST
            if !_rc {
                capture confirm string variable COST
                if !_rc {
                    quietly destring COST, replace
                }
                capture confirm numeric variable COST
                if !_rc {
                    quietly recast double COST, force
                }
            }
            
            * cons_core_item
            capture confirm variable cons_core_item
            if !_rc {
                capture confirm string variable cons_core_item
                if !_rc {
                    quietly destring cons_core_item, replace
                }
                capture confirm numeric variable cons_core_item
                if !_rc {
                    quietly recast double cons_core_item, force
                }
            }
            
            * cons_broad_item
            capture confirm variable cons_broad_item
            if !_rc {
                capture confirm string variable cons_broad_item
                if !_rc {
                    quietly destring cons_broad_item, replace
                }
                capture confirm numeric variable cons_broad_item
                if !_rc {
                    quietly recast double cons_broad_item, force
                }
            }
            
            * Set year
            capture confirm variable year
            if _rc {
                gen year = `y'
            }
            else {
                replace year = `y'
            }
            
            * Save standardized new year to tempfile
            local year_temp = "$robust_data/temp_year_`y'.dta"
            save "`year_temp'", replace
            
            * Load master and append standardized new year
            use "$robust_data/temp_current_master.dta", clear
            append using "`year_temp'"
            
            * Save updated master
            save "$robust_data/temp_current_master.dta", replace
            
            * Clean up tempfile
            erase "`year_temp'"
        }
        if _rc {
            display "WARNING: Could not process mtbi_`y'_tagged.dta (error code: " _rc ")"
            * Reload master to continue
            capture use "$robust_data/temp_current_master.dta", clear
        }
    }
    
    use "$robust_data/temp_current_master.dta", clear
    erase "$robust_data/temp_current_master.dta"
}

display "Total item-level observations: " _N

****************************************************
* 3. Collapse to CU-quarter level (baseline consumption)
****************************************************
display _n "=== Collapsing to CU-Quarter Level ==="

* #region agent log
* Final verification before collapse
capture confirm variable year quarter NEWID cons_core_item cons_broad_item
if _rc {
    display "DEBUG ERROR: Required variables missing before collapse"
    describe
    exit 198
}
display "DEBUG: All required variables confirmed before collapse"
display "DEBUG: About to collapse " _N " observations"
* #endregion

* OPTIMIZED: Collapse year-by-year to avoid I/O errors
* Collapsing 61M observations at once creates a huge temp file that exceeds system temp space
* Solution: Collapse each year separately, then append collapsed results
display _n "Collapsing to CU-quarter level (year-by-year to avoid I/O errors)..."

* OPTIMIZED: Collapse year-by-year using SSD (avoid preserve which uses system temp)
* Strategy: Save full dataset to SSD once, then load year-by-year for collapsing
* This avoids preserve/restore which writes to system temp (which is full)
* Collapse year-by-year
* OPTIMIZATION: Only process up to 2008 since CGK shocks end at 2008
local first_year = 1990
local last_year = 2008

* Save full dataset to SSD first (data is already in memory)
local full_data = "$robust_data/temp_full_for_collapse.dta"
save "`full_data'", replace

* Start with first year
use "`full_data'", clear
keep if year == `first_year'
collapse (sum) cons_core_q=cons_core_item cons_broad_q=cons_broad_item, ///
    by(NEWID year quarter)
save "$robust_data/temp_collapsed_master.dta", replace

* Collapse remaining years and append (load from SSD, collapse, append)
forvalues y = `=`first_year'+1'/`last_year' {
    display "Collapsing year `y'..."
    
    * Load full data from SSD and filter for this year
    use "`full_data'", clear
    keep if year == `y'
    
    * Collapse this year
    collapse (sum) cons_core_q=cons_core_item cons_broad_q=cons_broad_item, ///
        by(NEWID year quarter)
    
    * Append to master (load master, append, save)
    append using "$robust_data/temp_collapsed_master.dta"
    save "$robust_data/temp_collapsed_master.dta", replace
}

* Load final collapsed dataset
use "$robust_data/temp_collapsed_master.dta", clear

* Clean up temp file
erase "`full_data'"

* #region agent log
display "DEBUG: Collapse complete: " _N " CU-quarter observations"
* #endregion

display "CU-quarter observations: " _N

****************************************************
* 4. Merge with weights (FMLI files)
****************************************************
display _n "=== Merging Weights ==="

* OPTIMIZED: Check if base FMLI data exists (can be pre-loaded for efficiency)
capture confirm file "$robust_data/base_fmli_data.dta"
if !_rc {
    display "Loading from pre-loaded base FMLI data (optimization)"
    use "$robust_data/base_fmli_data.dta", clear
    
    * Keep only what's needed based on toggles
    if `equivalence' == 1 | `residualize' == 1 {
        * Keep all demographics
        keep NEWID FINLWT21 quarter year FAM_SIZE PERSLT18 AGE_REF EDUC_REF SEX_REF REF_RACE
    }
    else {
        * Keep only weights
        keep NEWID FINLWT21 quarter year
    }
    
    * Remove duplicates (one weight per CU-quarter)
    duplicates drop NEWID year quarter, force
    
    * If demographics are included, collapse to CU-quarter level (take max for demographics)
    if `equivalence' == 1 | `residualize' == 1 {
        * Check if demographics variables exist before collapsing
        capture confirm variable FAM_SIZE
        if !_rc {
            collapse (first) FINLWT21 (max) FAM_SIZE PERSLT18 AGE_REF EDUC_REF SEX_REF REF_RACE, by(NEWID year quarter)
            
            * Apply CGK's fix for PERSLT18
            replace PERSLT18 = FAM_SIZE - 1 if PERSLT18 >= FAM_SIZE & FAM_SIZE ~= . & PERSLT18 ~= .
        }
        else {
            * Demographics not found, just collapse weights
            collapse (first) FINLWT21, by(NEWID year quarter)
        }
    }
    else {
        * No demographics needed, just collapse weights
        collapse (first) FINLWT21, by(NEWID year quarter)
    }
    
    * Save to temp file for merging
    local weights_file = "$robust_data/temp_weights_all_years.dta"
    save "`weights_file'", replace
    
    display "Loaded base FMLI data: " _N " observations"
    
    * Merge weights (and demographics) with consumption
    merge m:1 NEWID year quarter using "`weights_file'"
}
else {
    display "Base FMLI data not found. Loading from scratch (fallback)..."
    
    * Fallback: Load from scratch (original method - kept for safety)
    local weights_file = "$robust_data/temp_weights_all_years.dta"
    
    * Start with first year - load directly (no preserve)
    * Directory names use 2-digit years: intrvw90 (1990), intrvw00 (2000), etc.
    * File names also use 2-digit years: fmli901.dta (1990), fmli001.dta (2000), etc.
    local year_suffix = substr(string(`first_year'), 3, 2)
    local intr_path = "$intr_base/intrvw`year_suffix'"
if `first_year' <= 1995 {
    * 1990-1995: flat structure
    capture cd "`intr_path'"
    if _rc {
        * Try alternative path
        local intr_path = "$intr_base/intrvw`first_year'/intrvw`first_year'"
        capture cd "`intr_path'"
    }
    
    * Load FMLI files (use 2-digit year in filename)
    local fmli_files ""
    forvalues q = 1/4 {
        capture confirm file "fmli`year_suffix'`q'.dta"
        if !_rc {
            local fmli_files "`fmli_files' fmli`year_suffix'`q'.dta"
        }
    }
    
    if "`fmli_files'" != "" {
        use `=word("`fmli_files'", 1)', clear
        gen quarter = 1
        local q = 2
        foreach f in `=subinstr("`fmli_files'", word("`fmli_files'", 1), "", 1)' {
            capture append using `f'
            if !_rc {
                replace quarter = `q' if quarter == .
                local q = `q' + 1
            }
        }
    }
    else {
        display "ERROR: No FMLI files found for year `first_year'"
        display "Searched in path: `intr_path'"
        display "Attempted to find: fmli`first_year'1.dta through fmli`first_year'4.dta"
        display "Current working directory:"
        pwd
        exit 198
    }
}
else {
    * 1996+: nested structure
    capture cd "`intr_path'/intrvw`first_year'"
    if _rc {
        capture cd "`intr_path'"
    }
    
    * Load FMLI files (use 2-digit year in filename)
    local fmli_files ""
    forvalues q = 1/4 {
        capture confirm file "fmli`year_suffix'`q'x.dta"
        if !_rc {
            local fmli_files "`fmli_files' fmli`year_suffix'`q'x.dta"
        }
        else {
            capture confirm file "fmli`year_suffix'`q'.dta"
            if !_rc {
                local fmli_files "`fmli_files' fmli`year_suffix'`q'.dta"
            }
        }
    }
    
    if "`fmli_files'" != "" {
        use `=word("`fmli_files'", 1)', clear
        gen quarter = 1
        local q = 2
        foreach f in `=subinstr("`fmli_files'", word("`fmli_files'", 1), "", 1)' {
            capture append using `f'
            if !_rc {
                replace quarter = `q' if quarter == .
                local q = `q' + 1
            }
        }
    }
    else {
        display "ERROR: No FMLI files found for year `first_year'"
        display "Searched in path: `intr_path'/intrvw`first_year' or `intr_path'"
        display "Attempted to find: fmli`first_year'1x.dta or fmli`first_year'1.dta through quarter 4"
        display "Current working directory:"
        pwd
        exit 198
    }
}

* Verify we actually loaded FMLI data (check for FMLI-specific variables)
* FMLI files should have weight variables, not consumption variables
capture confirm variable cons_core_q
if !_rc {
    display "ERROR: Still in consumption dataset! FMLI files did not load properly."
    display "Current dataset has consumption variables, not FMLI variables."
    display "This means the FMLI files were not found or could not be loaded."
    describe
    exit 198
}

* Standardize variable names
capture rename newid NEWID

* Handle weight variable - check for lowercase first, then rename
capture confirm variable finlwt21
if !_rc {
    rename finlwt21 FINLWT21
}
else {
    capture confirm variable FINLWT21
    if _rc {
        * Try alternative names
        capture confirm variable FINLWT
        if !_rc {
            rename FINLWT FINLWT21
        }
        else {
            capture confirm variable finlwt
            if !_rc {
                rename finlwt FINLWT21
            }
            else {
                display "ERROR: Weight variable not found in FMLI files for year `first_year'"
                describe
                exit 111
            }
        }
    }
}

* Extract demographics if needed for toggles
if `equivalence' == 1 | `residualize' == 1 {
    * Try various possible names for demographics
    capture rename famsize FAM_SIZE
    capture rename fam_size FAM_SIZE
    capture rename v980010 FAM_SIZE  // UCC code for People
    
    capture rename perslt18 PERSLT18
    capture rename v980050 PERSLT18  // UCC code for Children under 18
    
    capture rename age_ref AGE_REF
    capture rename v980020 AGE_REF  // UCC code for Age
    
    capture rename educ_ref EDUC_REF
    capture rename sex_ref SEX_REF
    capture rename ref_race REF_RACE
    
    * Keep weights and demographics (only variables that exist)
    local keep_vars "NEWID FINLWT21 quarter"
    capture confirm variable FAM_SIZE
    if !_rc local keep_vars "`keep_vars' FAM_SIZE"
    capture confirm variable PERSLT18
    if !_rc local keep_vars "`keep_vars' PERSLT18"
    capture confirm variable AGE_REF
    if !_rc local keep_vars "`keep_vars' AGE_REF"
    capture confirm variable EDUC_REF
    if !_rc local keep_vars "`keep_vars' EDUC_REF"
    capture confirm variable SEX_REF
    if !_rc local keep_vars "`keep_vars' SEX_REF"
    capture confirm variable REF_RACE
    if !_rc local keep_vars "`keep_vars' REF_RACE"
    
    keep `keep_vars'
}
else {
    * Keep only weights if demographics not needed
    keep NEWID FINLWT21 quarter
}
gen year = `first_year'

* Save first year's weights to master file (must be done before loop)
save "`weights_file'", replace

* Append remaining years (without preserve to avoid system temp)
forvalues y = `=`first_year'+1'/`last_year' {
    * Load year's weights directly, save to workspace, then append
    local year_weights_file = "$robust_data/temp_weights_`y'.dta"
    
    capture {
        * Directory names use 2-digit years: intrvw90 (1990), intrvw00 (2000), etc.
        local year_suffix = substr(string(`y'), 3, 2)
        local intr_path = "$intr_base/intrvw`year_suffix'"
    
    if `y' <= 1995 {
        capture cd "`intr_path'"
        if _rc {
            local intr_path = "$intr_base/intrvw`y'/intrvw`y'"
            capture cd "`intr_path'"
        }
        
        * File names use 2-digit years: fmli901.dta (1990), fmli001.dta (2000), etc.
        local year_suffix_y = substr(string(`y'), 3, 2)
        local fmli_files ""
        forvalues q = 1/4 {
            capture confirm file "fmli`year_suffix_y'`q'.dta"
            if !_rc {
                local fmli_files "`fmli_files' fmli`year_suffix_y'`q'.dta"
            }
        }
        
        if "`fmli_files'" != "" {
            use `=word("`fmli_files'", 1)', clear
            gen quarter = 1
            local q = 2
            foreach f in `=subinstr("`fmli_files'", word("`fmli_files'", 1), "", 1)' {
                capture append using `f'
                if !_rc {
                    replace quarter = `q' if quarter == .
                    local q = `q' + 1
                }
            }
        }
    }
    else {
        capture cd "`intr_path'/intrvw`y'"
        if _rc {
            capture cd "`intr_path'"
        }
        
        * File names use 2-digit years: fmli901x.dta (1990), fmli001x.dta (2000), etc.
        local year_suffix_y = substr(string(`y'), 3, 2)
        local fmli_files ""
        forvalues q = 1/4 {
            capture confirm file "fmli`year_suffix_y'`q'x.dta"
            if !_rc {
                local fmli_files "`fmli_files' fmli`year_suffix_y'`q'x.dta"
            }
            else {
                capture confirm file "fmli`year_suffix_y'`q'.dta"
                if !_rc {
                    local fmli_files "`fmli_files' fmli`year_suffix_y'`q'.dta"
                }
            }
        }
        
        if "`fmli_files'" != "" {
            use `=word("`fmli_files'", 1)', clear
            gen quarter = 1
            local q = 2
            foreach f in `=subinstr("`fmli_files'", word("`fmli_files'", 1), "", 1)' {
                capture append using `f'
                if !_rc {
                    replace quarter = `q' if quarter == .
                    local q = `q' + 1
                }
            }
        }
    }
    
        capture rename newid NEWID
        
        * Handle weight variable - check for lowercase first, then rename
        capture confirm variable finlwt21
        if !_rc {
            rename finlwt21 FINLWT21
        }
        else {
            capture confirm variable FINLWT21
            if _rc {
                * Try alternative names
                capture confirm variable FINLWT
                if !_rc {
                    rename FINLWT FINLWT21
                }
                else {
                    capture confirm variable finlwt
                    if !_rc {
                        rename finlwt FINLWT21
                    }
                    else {
                        display "WARNING: Weight variable not found in FMLI files for year `y', skipping..."
                        continue
                    }
                }
            }
        }
        
        * Verify FINLWT21 exists before trying to keep it
        capture confirm variable FINLWT21
        if _rc {
            display "WARNING: FINLWT21 not found after rename for year `y', skipping..."
            continue
        }
        
        * Extract demographics if needed for toggles
        if `equivalence' == 1 | `residualize' == 1 {
            * Try various possible names for demographics
            capture rename famsize FAM_SIZE
            capture rename fam_size FAM_SIZE
            capture rename v980010 FAM_SIZE
            capture rename perslt18 PERSLT18
            capture rename v980050 PERSLT18
            capture rename age_ref AGE_REF
            capture rename v980020 AGE_REF
            capture rename educ_ref EDUC_REF
            capture rename sex_ref SEX_REF
            capture rename ref_race REF_RACE
            
            * Keep weights and demographics (only variables that exist)
            local keep_vars "NEWID FINLWT21 quarter"
            capture confirm variable FAM_SIZE
            if !_rc local keep_vars "`keep_vars' FAM_SIZE"
            capture confirm variable PERSLT18
            if !_rc local keep_vars "`keep_vars' PERSLT18"
            capture confirm variable AGE_REF
            if !_rc local keep_vars "`keep_vars' AGE_REF"
            capture confirm variable EDUC_REF
            if !_rc local keep_vars "`keep_vars' EDUC_REF"
            capture confirm variable SEX_REF
            if !_rc local keep_vars "`keep_vars' SEX_REF"
            capture confirm variable REF_RACE
            if !_rc local keep_vars "`keep_vars' REF_RACE"
            
            keep `keep_vars'
        }
        else {
            * Keep only weights if demographics not needed
            keep NEWID FINLWT21 quarter
        }
        gen year = `y'
        
        * Save to workspace
        save "`year_weights_file'", replace
    }
    
    * Append to master weights file
    if !_rc {
        use "`weights_file'", clear
        append using "`year_weights_file'"
        save "`weights_file'", replace
        erase "`year_weights_file'"
    }
}

* Remove duplicates (one weight per CU-quarter)
duplicates drop NEWID year quarter, force

* If demographics are included, collapse to CU-quarter level (take max for demographics)
if `equivalence' == 1 | `residualize' == 1 {
    * Check if demographics variables exist before collapsing
    capture confirm variable FAM_SIZE
    if !_rc {
        collapse (first) FINLWT21 (max) FAM_SIZE PERSLT18 AGE_REF EDUC_REF SEX_REF REF_RACE, by(NEWID year quarter)
        
        * Apply CGK's fix for PERSLT18
        replace PERSLT18 = FAM_SIZE - 1 if PERSLT18 >= FAM_SIZE & FAM_SIZE ~= . & PERSLT18 ~= .
    }
    else {
        * Demographics not found, just collapse weights
        collapse (first) FINLWT21, by(NEWID year quarter)
    }
}
else {
    * No demographics needed, just collapse weights
    collapse (first) FINLWT21, by(NEWID year quarter)
}

    * Save to workspace (SSD) instead of tempfile
    save "`weights_file'", replace
    
    * #region agent log
    display "DEBUG: Saved weights (and demographics if needed) to workspace: `weights_file'"
    * #endregion
    
    * Merge weights (and demographics) with consumption
    merge m:1 NEWID year quarter using "`weights_file'"
    keep if _merge == 3
    drop _merge
}

* Clean up weights file
erase "`weights_file'"

display "After merging weights: " _N " observations"
if `equivalence' == 1 | `residualize' == 1 {
    display "Demographics also merged from FMLI files"
}

****************************************************
* 5. Apply CPI Deflation (Toggle: deflate)
****************************************************
if `deflate' == 1 {
    display _n "=== Applying CPI Deflation ==="
    
    * Create qdate for merging
    gen qdate = yq(year, quarter)
    format qdate %tq
    
    * Merge CPI
    merge m:1 qdate using "`cpi_monthly'"
    keep if _merge == 3
    drop _merge
    
    * Deflate: real_cons = nominal_cons / cpi_u * 100
    replace cons_core_q = cons_core_q / cpi_u * 100
    replace cons_broad_q = cons_broad_q / cpi_u * 100
    
    drop cpi_u qdate
    
    * Clean up CPI temp file
    erase "`cpi_monthly'"
    
    display "Applied CPI deflation (1982-84 base)"
}

****************************************************
* 6. Verify demographics are present (if needed for toggles)
****************************************************
if `equivalence' == 1 | `residualize' == 1 {
    display _n "=== Verifying Demographics from FMLI Files ==="
    
    * Demographics should already be merged from weights section
    * Just verify they're present
    capture confirm variable FAM_SIZE PERSLT18
    if _rc {
        display "ERROR: Demographics not found after merge"
        display "FMLI files may not contain required variables or have different names"
        display "Please check FMLI file structure"
        exit 198
    }
    
    * For residualization, verify additional variables
    if `residualize' == 1 {
        capture confirm variable AGE_REF EDUC_REF SEX_REF REF_RACE
        if _rc {
            display "WARNING: Some demographic variables missing for residualization"
            display "Residualization may not work correctly"
        }
    }
    
    display "Demographics verified - ready for toggle application"
}

****************************************************
* 7. Apply OECD Equivalence Scale (Toggle: equivalence)
****************************************************
if `equivalence' == 1 {
    display _n "=== Applying OECD Equivalence Scale ==="
    
    * OECD_ES = 1 + 0.5*(FAM_SIZE-1) + 0.2*(FAM_SIZE-PERSLT18)
    gen OECD_ES = 1 + 0.5*(FAM_SIZE-1) + 0.2*(FAM_SIZE-PERSLT18)
    
    * Adjust consumption
    replace cons_core_q = cons_core_q / OECD_ES
    replace cons_broad_q = cons_broad_q / OECD_ES
    
    display "Applied OECD equivalence scale"
}

****************************************************
* 8. Apply Winsorization (Toggle: winsor)
****************************************************
if `winsor' == 1 {
    display _n "=== Applying Winsorization (top/bottom 1%) ==="
    
    * Compute frequency weights for percentile calculation
    * FIXED: CGK uses fwt = round(FINLWT21/3)
    if "`weights_type'" == "fw" {
        gen fwt = round(FINLWT21/3)
    }
    else {
        gen fwt = FINLWT21
    }
    
    foreach var in cons_core_q cons_broad_q {
        * Winsorize at p1 and p99
        * FIXED: CGK uses [fw=fwt] for percentile calculation (matches step001.do line 117)
        quietly summarize `var' [fw=fwt] if `var' > 0, detail
        local p99 = r(p99)
        local p1 = r(p1)
        
        replace `var' = `p99' if `var' > `p99' & `var' ~= . & `var' > 0
        replace `var' = `p1' if `var' < `p1' & `var' ~= . & `var' > 0
    }
    
    drop fwt
    
    display "Applied winsorization (p1, p99)"
}

****************************************************
* 9. Prepare for Gini computation
****************************************************
display _n "=== Preparing for Gini Computation ==="

* Drop zero/negative consumption (unless zeros are included)
if "`zeros'" == "exclude" {
    drop if cons_core_q <= 0 | cons_broad_q <= 0
    display "Excluded zero/negative consumption"
}
else {
    * Replace zeros with small positive value for log computation
    replace cons_core_q = 0.01 if cons_core_q <= 0 & cons_core_q ~= .
    replace cons_broad_q = 0.01 if cons_broad_q <= 0 & cons_broad_q ~= .
    display "Included zeros (set to 0.01 for logs)"
}

* Create log consumption (for residualization if needed)
gen LNcons_core_q = log(cons_core_q) if cons_core_q > 0
gen LNcons_broad_q = log(cons_broad_q) if cons_broad_q > 0

****************************************************
* 10. Residual Inequality (Toggle: residualize)
****************************************************
if `residualize' == 1 {
    display _n "=== Computing Residual Inequality ==="
    
    * Regress log consumption on demographics
    * Need: AGE_REF, EDUC_REF, SEX_REF, REF_RACE, FAM_SIZE, PERSLT18, time dummies
    
    * Create time dummies
    quietly tab quarter, gen(q_)
    quietly tab year, gen(y_)
    
    * Regress and get residuals
    * FIXED: CGK uses [iw=fwt] for regression (matches step001.do line 127)
    * Note: [iw=] is equivalent to [aw=] in Stata for regression
    if "`weights_type'" == "fw" {
        gen fwt_resid = round(FINLWT21/3)
        local wt_spec = "[aw=fwt_resid]"
    }
    else {
        local wt_spec = "[aw=FINLWT21]"
    }
    
    quietly reg LNcons_core_q AGE_REF EDUC_REF SEX_REF REF_RACE FAM_SIZE PERSLT18 q_* y_* `wt_spec'
    predict R_LNcons_core_q, residuals
    
    quietly reg LNcons_broad_q AGE_REF EDUC_REF SEX_REF REF_RACE FAM_SIZE PERSLT18 q_* y_* `wt_spec'
    predict R_LNcons_broad_q, residuals
    
    * Use residuals for Gini computation (convert back to levels)
    replace cons_core_q = exp(R_LNcons_core_q) if R_LNcons_core_q ~= .
    replace cons_broad_q = exp(R_LNcons_broad_q) if R_LNcons_broad_q ~= .
    
    drop q_* y_* R_LNcons_core_q R_LNcons_broad_q
    if "`weights_type'" == "fw" {
        drop fwt_resid
    }
    
    display "Computed residual inequality"
}

****************************************************
* 11. Compute Ginis by year-quarter
****************************************************
display _n "=== Computing Ginis ==="

* Prepare weights
* FIXED: CGK uses fwt = round(FINLWT21/3), not round(FINLWT21)
if "`weights_type'" == "fw" {
    gen fwt = round(FINLWT21/3)
    local wt_spec = "[fw=fwt]"
}
else {
    local wt_spec = "[aw=FINLWT21]"
}

* Create postfile for results (use workspace instead of tempfile)
local gini_results = "$robust_data/temp_gini_results.dta"
postfile gini_post int year int quarter double gini_core double gini_broad ///
    using "`gini_results'", replace

* OPTIMIZED: Loop over year-quarter combinations
* Load data once per year-quarter, compute both Ginis in same load (like original code)
* This avoids loading the full dataset 272 times (136 year-quarters × 2 Gini measures)
* Strategy: Keep full dataset in memory, use preserve/restore for filtering
quietly {
    levelsof year, local(years)
    foreach y of local years {
        levelsof quarter if year == `y', local(quarters)
        foreach q of local quarters {
            * Filter to this year-quarter (data already in memory)
            preserve
            keep if year == `y' & quarter == `q'
            
            * Compute Gini for core
            if "`zeros'" == "exclude" {
                keep if cons_core_q > 0 & LNcons_core_q ~= .
            }
            else {
                keep if cons_core_q ~= .
            }
            
            if _N > 0 {
                `ineq_cmd' cons_core_q `wt_spec'
                scalar gc = r(gini)
            }
            else {
                scalar gc = .
            }
            
            * Restore to year-quarter level, then filter for broad
            restore
            preserve
            keep if year == `y' & quarter == `q'
            
            * Compute Gini for broad
            if "`zeros'" == "exclude" {
                keep if cons_broad_q > 0 & LNcons_broad_q ~= .
            }
            else {
                keep if cons_broad_q ~= .
            }
            
            if _N > 0 {
                `ineq_cmd' cons_broad_q `wt_spec'
                scalar gb = r(gini)
            }
            else {
                scalar gb = .
            }
            
            restore
            
            post gini_post (`y') (`q') (gc) (gb)
        }
    }
}

postclose gini_post

* Load results
use "`gini_results'", clear

* Clean up results temp file
erase "`gini_results'"

* Create qdate
gen qdate = yq(year, quarter)
format qdate %tq

* Sort
sort year quarter

****************************************************
* 12. Create toggle signature and save
****************************************************
display _n "=== Saving Results ==="

* Create toggle signature for filename
local sig = "deflate`deflate'_equiv`equivalence'_`weights_type'_winsor`winsor'_zeros`zeros'_resid`residualize'_`ineq_cmd'"

* If shortname not provided, use signature
if "`toggle_shortname'" == "" local toggle_shortname = "`sig'"

* Add toggle signature and shortname as variables before saving
gen toggle_sig = "`sig'"
label var toggle_sig "Toggle signature for this Gini series"
gen toggle_shortname = "`toggle_shortname'"
label var toggle_shortname "Short name for toggle combination (for tables/graphs)"

* Save to temp file (will be combined into master file by 00_run_all_robust.do)
local temp_file = "$robust_data/temp_gini_`sig'.dta"
save "`temp_file'", replace

display "Saved to temp file: `temp_file'"
display "Total observations: " _N
display "Date range: " %tq qdate[1] " to " %tq qdate[_N]
display "This will be combined into master file by 00_run_all_robust.do"

display _n "========================================"
display "GINI COMPUTATION COMPLETE"
display "========================================"
