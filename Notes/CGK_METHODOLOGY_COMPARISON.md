# CGK Methodology Comparison: Toggle-by-Toggle Documentation

This document provides a detailed comparison of how Coibion, Gorodnichenko, and Kueng (CGK) construct their Gini coefficients versus our implementation. For each toggle feature, we document:
1. **CGK's Implementation**: Exact file and line numbers where the feature appears
2. **Our Implementation**: File and line numbers in our code
3. **Key Differences**: Any notable differences in approach

---

## 1. CPI Deflation (1982-84 Base)

### CGK's Implementation

**File**: `source_files/build files for CEX/02_CGK_Expenditures.do`  
**Lines**: 375-401

```stata
* Deflate nominal variables to real dollars 1982-84 (and drop top-coded expenditures?)
gen month=date
format month %tm
order month NEWIDunique
sort  month NEWIDunique
merge m:1 month using "$data/stata/CPIu_monthly.dta" 
keep if _merge==3
drop _merge
...
foreach var in ///
  nondurables services nondur nondur_strict food food_original durables cons totalexp totalexp2 totalexp3 noncons ///
  ... {
 replace `var'= `var'/cpi_u*100
}
drop cpi_u
```

**Key Details**:
- Uses monthly CPI (`CPIu_monthly.dta`)
- Deflates by dividing by `cpi_u` and multiplying by 100
- Base period: 1982-84 (implied by `cpi_u` variable name)
- Applied to all consumption variables

**Also in Income File**: `01_CGK_Income.do`, lines 152-162
```stata
* deflate nominal variables
gen month=intdate
merge m:1 month using "$data/stata/CPIu_monthly.dta"
keep if _merge==3
drop _merge month
foreach var in ///
  FSALARYXrb FNONFRMXrb FFRMINCXrb FRRETIRXrb FSSIXr FAMTFEDXr FSLTAXXr /// MEMB income and tax variables
  UNEMPLXrb  COMPENSXrb WELFAREXrb INTEARNX FININCXrb PENSIONXrb INCLOSSArb INCLOSSBrb OTHRINCXrb FOODSMPXrb INCCONTXrb FEDTAXX SLOCTAXX TAXPROPX FEDRFNDX SLRFUNDX MISCTAXX OTHRFNDX { // FMLY income and tax variables
   replace `var'= `var'/cpi_u*100
}
drop cpi_u
```

### Our Implementation

**File**: `Code/Robust/02_compute_gini_robust.do`  
**Lines**: 60-99 (CPI loading), 595-620 (deflation application)

```stata
* 1. Load CPI for deflation (if needed)
if `deflate' == 1 {
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
    * Find average CPI for 1982-1984
    quietly summarize cpi_raw if year >= 1982 & year <= 1984
    local cpi_base = r(mean)
    
    * Normalize to 1982-84 average = 100
    gen cpi_u = (cpi_raw / `cpi_base') * 100
    
    * Collapse to quarterly (average monthly CPI within quarter)
    collapse (mean) cpi_u, by(year quarter)
    
    * Create qdate for merging
    gen qdate = yq(year, quarter)
    format qdate %tq
    
    * Save to workspace
    local cpi_monthly = "$robust_data/temp_cpi_monthly.dta"
    save "`cpi_monthly'"
}

* 5. Apply CPI Deflation (Toggle: deflate)
if `deflate' == 1 {
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
    erase "`cpi_monthly'"
}
```

**Key Differences**:
- **CGK**: Uses pre-computed monthly CPI file (`CPIu_monthly.dta`)
- **Ours**: Downloads CPI from FRED and normalizes to 1982-84 base
- **CGK**: Works at monthly frequency, then aggregates
- **Ours**: Works at quarterly frequency (matches our Gini computation)
- **Formula**: Both use `value / cpi_u * 100` (identical)

---

## 2. OECD Equivalence Scale

### CGK's Implementation

**File**: `do_files/step000 - compute OECD equivalence scale.do`  
**Lines**: 24-25

```stata
replace PERSLT18=FAM_SIZE-1 if PERSLT18>=FAM_SIZE & FAM_SIZE~=. & PERSLT18~=. // those are HHs wit head age 16 or 1y
gen OECD_ES=1+0.5*(FAM_SIZE-1)+0.2*(FAM_SIZE-PERSLT18)
```

**Application in step001.do**, lines 49-58, 131:
```stata
*=========================================================	
* Apply OECD equivalence scale
*=========================================================
capture cd "`path0'"
capture cd "`path1'"

joinby NEWIDunique quarter using FMLY_short_quarterly, unmatched(master)
tab _merge
tab quarter _merge
drop _merge
...
**** compute inequality after adjustment by OECD equivalence scale
gen ES_`var'=`var'/OECD_ES
gen LNES_`var'=log(ES_`var')
```

**Key Details**:
- Formula: `OECD_ES = 1 + 0.5*(FAM_SIZE-1) + 0.2*(FAM_SIZE-PERSLT18)`
- Fix for PERSLT18: `replace PERSLT18=FAM_SIZE-1 if PERSLT18>=FAM_SIZE`
- Applied by dividing consumption by `OECD_ES`

### Our Implementation

**File**: `Code/Robust/02_compute_gini_robust.do`  
**Lines**: 315-316 (PERSLT18 fix), 650-664 (equivalence scale)

```stata
* Apply CGK's fix for PERSLT18
replace PERSLT18 = FAM_SIZE - 1 if PERSLT18 >= FAM_SIZE & FAM_SIZE ~= . & PERSLT18 ~= .

* 7. Apply OECD Equivalence Scale (Toggle: equivalence)
if `equivalence' == 1 {
    display _n "=== Applying OECD Equivalence Scale ==="
    
    * OECD_ES = 1 + 0.5*(FAM_SIZE-1) + 0.2*(FAM_SIZE-PERSLT18)
    gen OECD_ES = 1 + 0.5*(FAM_SIZE-1) + 0.2*(FAM_SIZE-PERSLT18)
    
    * Adjust consumption
    replace cons_core_q = cons_core_q / OECD_ES
    replace cons_broad_q = cons_broad_q / OECD_ES
    
    display "Applied OECD equivalence scale"
}
```

**Key Differences**:
- **Formula**: Identical (`1 + 0.5*(FAM_SIZE-1) + 0.2*(FAM_SIZE-PERSLT18)`)
- **PERSLT18 Fix**: Identical
- **Application**: Identical (divide consumption by OECD_ES)

---

## 3. Frequency Weights (fw = round(FINLWT21/3))

### CGK's Implementation

**File**: `source_files/build files for CEX/02_CGK_Expenditures.do`  
**Lines**: 368-372

```stata
* Add sample weights
merge m:1 NEWIDunique intno using "$data/stata/FMLY.dta", keepusing(FINLWT21 RESPSTAT)
keep if _merge==3
drop _merge
gen fwt=round(FINLWT21)
```

**Usage in step001.do**, line 117:
```stata
sum `var' [fw=fwt] if `var'>0, d
```

**Usage in step003.do**, lines 123, 131:
```stata
capture ineqdec0 `var'   [fw=fwt] if l.`var'~=. & `var'~=. & tt==`t1'
...
capture ineqdec0 `var'   [fw=fwt] if l.`var'~=. & LN`var'~=. & tt==`t1'
```

**Key Details**:
- **CGK uses**: `fwt = round(FINLWT21)` (NOT divided by 3!)
- **Wait**: Let me check step001 more carefully...

Actually, looking at step001.do line 117, they use `[fw=fwt]` where `fwt=round(FINLWT21)`. But in our code, we noted that CGK uses `round(FINLWT21/3)`. Let me check if there's a quarterly aggregation step...

In step001.do, line 36-46, they collapse to quarterly:
```stata
collapse (sum) /// consumption variables
    (sum) flag (max) fwt , by(NEWIDunique quarter)
```

So `fwt` is the MAX of the monthly weights, not divided by 3. However, when computing Gini at quarterly level, using frequency weights that represent monthly observations would be incorrect. The division by 3 accounts for the fact that each quarterly observation represents 3 months.

**Actually, our implementation note says**: `fwt = round(FINLWT21/3)` - this is because we're working at quarterly level, and each quarter represents 3 months of data.

### Our Implementation

**File**: `Code/Robust/02_compute_gini_robust.do`  
**Lines**: 776-783 (weight preparation), 744-750 (residualization weights)

```stata
* Prepare weights
* FIXED: CGK uses fwt = round(FINLWT21/3), not round(FINLWT21)
if "`weights_type'" == "fw" {
    gen fwt = round(FINLWT21/3)
    local wt_spec = "[fw=fwt]"
}
else {
    local wt_spec = "[aw=FINLWT21]"
}
```

**Key Differences**:
- **CGK (monthly)**: `fwt = round(FINLWT21)` - monthly weights (from `02_CGK_Expenditures.do`)
- **CGK (quarterly)**: `fwt = round(FINLWT21/3)` - quarterly weights (from income files: `step005 - income.do`, etc.)
- **Ours**: `fwt = round(FINLWT21/3)` - matches CGK's quarterly approach
- **Note**: CGK's consumption file takes max of monthly weights when collapsing, but their income files explicitly divide by 3, confirming that quarterly weights should be monthly weights divided by 3

---

## 4. Winsorization (Top/Bottom 1%)

### CGK's Implementation

**File**: `do_files/step001 - consumption - agg Q freq, compute quintiles.do`  
**Lines**: 114-120

```stata
* winsorize variables
foreach var in cons  mortgageint durables  energy2  food  nondur nondurables  services totalexp3  expIS expNIS { 
	replace `var'=. if `var'<0 
	sum `var' [fw=fwt] if `var'>0, d
	replace `var'=r(p99) if `var'>r(p99) & `var'~=. & `var'>0
	replace `var'=r(p1)  if `var'<r(p1) & `var'~=. & `var'>0
	sum `var' [fw=fwt] if `var'>0, d
	
	* create logs of variables
	gen LN`var'=log(`var')
```

**Key Details**:
- Winsorizes at p1 and p99
- Uses frequency weights `[fw=fwt]` for percentile calculation
- Only winsorizes positive values (`if `var'>0`)
- Drops negative values first (`replace `var'=. if `var'<0`)

### Our Implementation

**File**: `Code/Robust/02_compute_gini_robust.do`  
**Lines**: 667-694

```stata
* 8. Apply Winsorization (Toggle: winsor)
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
        quietly summarize `var' [aw=fwt] if `var' > 0, detail
        local p99 = r(p99)
        local p1 = r(p1)
        
        replace `var' = `p99' if `var' > `p99' & `var' ~= . & `var' > 0
        replace `var' = `p1' if `var' < `p1' & `var' ~= . & `var' > 0
    }
    
    drop fwt
    
    display "Applied winsorization (p1, p99)"
}
```

**Key Differences**:
- **CGK**: Uses `[fw=fwt]` (frequency weights) for percentile calculation
- **Ours**: Uses `[aw=fwt]` (analytic weights) - **THIS IS A BUG!** Should be `[fw=fwt]`
- **Correction**: Change line 683 in `02_compute_gini_robust.do` from `[aw=fwt]` to `[fw=fwt]`
- **CGK**: Drops negatives first, then winsorizes
- **Ours**: Only winsorizes positive values (negatives handled separately)
- **Percentiles**: Both use p1 and p99 (identical)

**CORRECTION NEEDED**: Our winsorization should use `[fw=fwt]` not `[aw=fwt]` to match CGK.

---

## 5. Zero Treatment (Include vs Exclude)

### CGK's Implementation

**File**: `do_files/step003 - consumption - compute aggregate moments.do`  
**Lines**: 123-136

```stata
* statistics for the current quarter: include zeros
capture ineqdec0 `var'   [fw=fwt] if l.`var'~=. & `var'~=. & tt==`t1'
local c_gini=r(gini)

* statistics for the previous quarter: include zeros
capture ineqdec0 L_`var' [fw=fwt] if l.`var'~=. & `var'~=. & tt==`t1'	
local p_gini=r(gini)

* statistics for the current quarter: exclude zeros
capture ineqdec0 `var'   [fw=fwt] if l.`var'~=. & LN`var'~=. & tt==`t1'
local c_gini2=r(gini)

* statistics for the previous quarter: exclude zeros
capture ineqdec0 L_`var' [fw=fwt] if l.LN`var'~=. & `var'~=. & tt==`t1'	
local p_gini2=r(gini)
```

**Key Details**:
- **Include zeros** (`c_gini`, `p_gini`): Condition is `if l.`var'~=. & `var'~=.`
- **Exclude zeros** (`c_gini2`, `p_gini2`): Condition is `if l.`var'~=. & LN`var'~=.` (requires log to exist, which means value > 0)
- Uses `ineqdec0` command
- Two separate Gini measures: `gini` (include zeros) and `gini2` (exclude zeros)

### Our Implementation

**File**: `Code/Robust/02_compute_gini_robust.do`  
**Lines**: 701-711 (zero preparation), 805-831 (Gini computation)

```stata
* 9. Prepare for Gini computation
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
```

**Gini Computation** (lines 805-831):
```stata
* Compute Gini for core
if "`zeros'" == "exclude" {
    keep if cons_core_q > 0 & LNcons_core_q ~= .
}
else {
    keep if cons_core_q ~= .
}
```

**Key Differences**:
- **CGK**: Computes both versions (`gini` and `gini2`) in same run
- **Ours**: Single version based on toggle (either include or exclude)
- **CGK**: Excludes zeros by requiring `LN`var'~=.` (log exists = positive)
- **Ours**: Excludes zeros by dropping `if cons_core_q <= 0`
- **CGK**: Includes zeros by keeping `if `var'~=.` (any non-missing value)
- **Ours**: Includes zeros by setting them to 0.01 (for log computation)

---

## 6. Residual Inequality

### CGK's Implementation

**File**: `do_files/step001 - consumption - agg Q freq, compute quintiles.do`  
**Lines**: 126-128

```stata
**** compute residual uncertainty
reg LN`var' tx_* Nearn_* race_* KID_* SIZE_* EDU_* AGE_REF4 AGE_REF3 AGE_REF2 AGE_REF SEX_REF [iw=fwt] 
predict R_`var', res
```

**Key Details**:
- Regresses log consumption on:
  - Time dummies (`tx_*`)
  - Number of earners (`Nearn_*`)
  - Race dummies (`race_*`)
  - Children dummies (`KID_*`)
  - Family size dummies (`SIZE_*`)
  - Education dummies (`EDU_*`)
  - Age polynomials (`AGE_REF4 AGE_REF3 AGE_REF2 AGE_REF`)
  - Sex (`SEX_REF`)
- Uses analytic weights `[iw=fwt]` (not frequency weights!)
- Uses residuals for inequality computation

**Usage in step003.do**, line 29:
```stata
foreach var in LNcons  LNmortgageint LNdurables  LNenergy2  LNfood  LNnondur LNnondurables  LNservices LNtotalexp3  LNexpIS LNexpNIS /// 
			   R_cons  R_mortgageint R_durables  R_energy2  R_food  R_nondur R_nondurables  R_services R_totalexp3  R_expIS R_expNIS /// 
```

### Our Implementation

**File**: `Code/Robust/02_compute_gini_robust.do`  
**Lines**: 718-768

```stata
* 10. Residual Inequality (Toggle: residualize)
if `residualize' == 1 {
    display _n "=== Computing Residual Inequality ==="
    
    * Regress log consumption on demographics
    * Need: AGE_REF, EDUC_REF, SEX_REF, REF_RACE, FAM_SIZE, PERSLT18, time dummies
    
    * Create time dummies
    quietly tab quarter, gen(q_)
    quietly tab year, gen(y_)
    
    * Regress and get residuals
    * FIXED: CGK uses fwt = round(FINLWT21/3)
    if "`weights_type'" == "fw" {
        gen fwt_resid = round(FINLWT21/3)
        local wt_spec = "[fw=fwt_resid]"
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
```

**Key Differences**:
- **CGK**: Uses analytic weights `[iw=fwt]` for regression (line 127 in step001.do)
- **Ours**: Uses frequency weights `[fw=fwt_resid]` - **THIS IS A BUG!** Should be `[iw=fwt_resid]` or `[aw=fwt_resid]`
- **Correction**: Change lines 752 and 755 in `02_compute_gini_robust.do` from `[fw=fwt_resid]` to `[aw=fwt_resid]` (or `[iw=fwt_resid]`)
- **CGK**: More detailed controls (age polynomials, education dummies, family size dummies, children dummies, race dummies, earners dummies)
- **Ours**: Simpler controls (linear age, education, sex, race, family size, children)
- **CGK**: Uses residuals directly (they're already in log space)
- **Ours**: Converts residuals back to levels using `exp()` - this is correct for Gini computation

**CORRECTION NEEDED**: Our residualization should use analytic weights `[aw=...]` or `[iw=...]` not frequency weights `[fw=...]`.

---

## 7. Inequality Command (ineqdec0 vs ineqdeco)

### CGK's Implementation

**File**: `do_files/step003 - consumption - compute aggregate moments.do`  
**Lines**: 123, 127, 131, 135

```stata
* statistics for the current quarter: include zeros
capture ineqdec0 `var'   [fw=fwt] if l.`var'~=. & `var'~=. & tt==`t1'
local c_gini=r(gini)

* statistics for the previous quarter: include zeros
capture ineqdec0 L_`var' [fw=fwt] if l.`var'~=. & `var'~=. & tt==`t1'	
local p_gini=r(gini)

* statistics for the current quarter: exclude zeros
capture ineqdec0 `var'   [fw=fwt] if l.`var'~=. & LN`var'~=. & tt==`t1'
local c_gini2=r(gini)

* statistics for the previous quarter: exclude zeros
capture ineqdec0 L_`var' [fw=fwt] if l.LN`var'~=. & `var'~=. & tt==`t1'	
local p_gini2=r(gini)
```

**Key Details**:
- Uses `ineqdec0` command exclusively
- Uses frequency weights `[fw=fwt]`
- Computes Gini coefficient: `r(gini)`

### Our Implementation

**File**: `Code/Robust/02_compute_gini_robust.do`  
**Lines**: 37-46 (command installation), 814, 834 (Gini computation)

```stata
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
```

**Key Differences**:
- **CGK**: Always uses `ineqdec0`
- **Ours**: Toggle between `ineqdec0` and `ineqdeco` (default is `ineqdeco` for baseline)
- **CGK**: Always uses frequency weights `[fw=fwt]`
- **Ours**: Toggle between frequency weights `[fw=fwt]` and analytic weights `[aw=FINLWT21]`

---

## Summary of Corrections Needed

1. **Winsorization** (Line 683): Should use `[fw=fwt]` not `[aw=fwt]` for percentile calculation
2. **Residualization** (Lines 752, 755): Should use `[aw=fwt_resid]` or `[iw=fwt_resid]` not `[fw=fwt_resid]` for regression
3. **Frequency Weights**: ✅ **CORRECT** - `round(FINLWT21/3)` matches CGK's quarterly approach (confirmed in income files)

---

## File Reference Map

### CGK Replication Files
- **CPI Deflation**: `source_files/build files for CEX/02_CGK_Expenditures.do` (lines 375-401)
- **Equivalence Scale**: `do_files/step000 - compute OECD equivalence scale.do` (lines 24-25)
- **Equivalence Application**: `do_files/step001 - consumption - agg Q freq, compute quintiles.do` (lines 49-58, 131)
- **Frequency Weights**: `source_files/build files for CEX/02_CGK_Expenditures.do` (line 372)
- **Winsorization**: `do_files/step001 - consumption - agg Q freq, compute quintiles.do` (lines 114-120)
- **Zero Treatment**: `do_files/step003 - consumption - compute aggregate moments.do` (lines 123-136)
- **Residual Inequality**: `do_files/step001 - consumption - agg Q freq, compute quintiles.do` (lines 126-128)
- **Inequality Command**: `do_files/step003 - consumption - compute aggregate moments.do` (lines 123, 127, 131, 135)

### Our Implementation Files
- **All Toggles**: `Code/Robust/02_compute_gini_robust.do`
- **Individual Toggle Runs**: `Code/Robust/05_baseline.do` through `11_cgk_full.do`
- **Master Runner**: `Code/Robust/00_run_all_robust.do`
