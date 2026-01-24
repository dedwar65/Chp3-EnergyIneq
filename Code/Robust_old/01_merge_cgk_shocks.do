****************************************************
* 01_merge_cgk_shocks.do
* Import CGK shock files and merge with quarterly Gini data (1990-2023)
* Shocks: Romer-Romer, Gorodnichenko-Weber Fed Funds Futures, Trend Inflation
****************************************************

clear all
set more off

global cgk_source "/Volumes/SSD PRO/Downloads/replication_folder/source_files"
global deriv "/Volumes/SSD PRO/Github-forks/Chp3-EnergyIneq/Code/Data/CEX/derived"
global robust_data "/Volumes/SSD PRO/Github-forks/Chp3-EnergyIneq/Code/Robust/Data"
global code "/Volumes/SSD PRO/Github-forks/Chp3-EnergyIneq/Code"

* Close any open log file, then open new log file
capture log close
log using "$code/Robust/01_merge_cgk_shocks.log", replace

display _n "========================================"
display "MERGING CGK SHOCKS WITH GINI DATA"
display "========================================" _n

****************************************************
* 1. Import Romer-Romer (RR) Shocks
****************************************************
display _n "=== Importing RR Shocks ==="

use "$cgk_source/RR_shocks_updated.dta", clear

* Check structure
display "RR shocks structure:"
describe
count
display "First 10 observations:"
list in 1/10

* Check if already has year/quarter or needs conversion
capture confirm variable year
if _rc {
    * Need to create year/quarter from date variable
    * Check what date variable exists
    describe
    * Assuming there's a date variable - adjust based on actual structure
    * For now, assume it has year and quarter already
    display "WARNING: No year/quarter found. Please check RR_shocks_updated.dta structure"
}

* Ensure we have year and quarter
capture confirm variable year quarter
if _rc {
    * Try to infer from other variables
    * This will need adjustment based on actual file structure
    display "ERROR: Cannot find year/quarter in RR shocks. Please check file structure."
    exit 198
}

* Create qdate for merging
gen qdate = yq(year, quarter)
format qdate %tq

* Rename shock variable to match CGK convention
capture confirm variable sh_rr
if _rc {
    * Check what the shock variable is actually named
    describe
    * If it's named differently, rename it
    * Common names: RR_shock, shock, etc.
    capture rename RR_shock sh_rr
    capture rename shock sh_rr
    if _rc {
        display "WARNING: Could not find RR shock variable. Please check variable names."
    }
}

* Keep only necessary variables
keep year quarter qdate sh_rr

* Save temporary file
tempfile rr_shocks
save `rr_shocks'

display "RR shocks: " _N " quarterly observations"
summarize sh_rr

****************************************************
* 2. Import Gorodnichenko-Weber Fed Funds Futures Shocks
****************************************************
display _n "=== Importing Gorodnichenko-Weber Fed Funds Futures Shocks ==="

import excel "$cgk_source/Gorodnichenko_Weber_fed_funds_futures_shocks.xlsx", ///
    sheet("shocks") cellrange(A1) firstrow clear

* Check structure
display "Gorodnichenko-Weber shocks structure:"
describe
count
display "First 10 observations:"
list in 1/10

* Rename TIGHT_SHOCK to MP_FFF_GW
capture rename TIGHT_SHOCK MP_FFF_GW
if _rc {
    display "WARNING: TIGHT_SHOCK variable not found. Checking available variables:"
    describe
}

* Parse DATE variable to year, month, quarter
* DATE should be a Stata date variable or Excel date
capture confirm variable DATE
if _rc {
    display "ERROR: DATE variable not found in Gorodnichenko-Weber shocks"
    exit 198
}

* Convert DATE to Stata date if needed
capture confirm numeric variable DATE
if _rc {
    * DATE might be string or Excel date number
    * Try to convert
    capture destring DATE, replace
    if _rc {
        * Try as Excel date
        gen date_num = DATE
        replace date_num = date_num - 25569 if date_num > 25569
        gen DATE_stata = date_num
        format DATE_stata %td
        drop DATE
        rename DATE_stata DATE
    }
}

* Extract year, month, quarter
gen year = year(DATE)
gen month = month(DATE)
gen quarter = quarter(DATE)

* Collapse to quarterly (sum monthly shocks within quarter)
collapse (sum) MP_FFF_GW, by(year quarter)

* Create qdate for merging
gen qdate = yq(year, quarter)
format qdate %tq

* Save temporary file
tempfile gw_shocks
save `gw_shocks'

display "Gorodnichenko-Weber shocks: " _N " quarterly observations"
summarize MP_FFF_GW

****************************************************
* 3. Import Trend Inflation Shocks
****************************************************
display _n "=== Importing Trend Inflation Shocks ==="

import excel "$cgk_source/Trend_inflation_shocks_CG.xlsx", ///
    sheet("Sheet1") cellrange(A1) firstrow clear

* Check structure
display "Trend inflation shocks structure:"
describe
count
display "First 10 observations:"
list in 1/10

* Variables should be: pi_trend_cg, PI_TARGET, PI_STAR_IRL_BACK
* Check if they exist
capture confirm variable pi_trend_cg PI_TARGET PI_STAR_IRL_BACK
if _rc {
    display "WARNING: Some trend inflation variables not found. Available variables:"
    describe
}

* Check if already has year/quarter or needs conversion
capture confirm variable year quarter
if _rc {
    * Need to create from date variable
    * Check what date variable exists
    describe
    * Assuming there's a date variable - adjust based on actual structure
    display "WARNING: No year/quarter found. Please check Trend_inflation_shocks_CG.xlsx structure"
    * For now, try to infer from other variables or exit with error
    exit 198
}

* Create qdate for merging
gen qdate = yq(year, quarter)
format qdate %tq

* Keep only necessary variables
keep year quarter qdate pi_trend_cg PI_TARGET PI_STAR_IRL_BACK

* Save temporary file
tempfile trend_shocks
save `trend_shocks'

display "Trend inflation shocks: " _N " quarterly observations"
summarize pi_trend_cg PI_TARGET PI_STAR_IRL_BACK

****************************************************
* 4. Merge all shocks together
****************************************************
display _n "=== Merging All Shocks ==="

use `rr_shocks', clear

* Merge with Gorodnichenko-Weber shocks
merge 1:1 qdate using `gw_shocks'
display "Merge with GW shocks:"
tab _merge
drop _merge

* Merge with trend inflation shocks
merge 1:1 qdate using `trend_shocks'
display "Merge with trend inflation shocks:"
tab _merge
drop _merge

* Sort by date
sort qdate

* Save combined shocks
save "$robust_data/cgk_shocks_quarterly.dta", replace

display _n "Combined shocks summary:"
count
summarize qdate
summarize sh_rr MP_FFF_GW pi_trend_cg

****************************************************
* 5. Load our quarterly Gini data
****************************************************
display _n "=== Loading Gini Data ==="

use "$deriv/gini_1990_2023_quarterly.dta", clear

display "Gini data:"
count
summarize qdate
display "Date range: " %tq qdate[1] " to " %tq qdate[_N]

****************************************************
* 6. Merge shocks with Gini data
****************************************************
display _n "=== Merging Shocks with Gini Data ==="

* Merge on qdate
merge 1:1 qdate using "$robust_data/cgk_shocks_quarterly.dta"

display "Merge results:"
tab _merge
display _n "Sample of matched observations:"
list qdate year quarter gini_core gini_broad sh_rr MP_FFF_GW pi_trend_cg if _merge == 3 in 1/10

display _n "Sample of Gini-only (unmatched):"
count if _merge == 1
if r(N) > 0 {
    list qdate year quarter if _merge == 1 in 1/10
}

display _n "Sample of shocks-only (unmatched):"
count if _merge == 2
if r(N) > 0 {
    list qdate year quarter if _merge == 2 in 1/10
}

* Keep all Gini observations (shocks will be missing for 2009-2023, which is expected)
* For LP analysis, we'll use overlapping period 1990-2008
keep if _merge == 1 | _merge == 3
drop _merge

* Sort and order variables
sort qdate
order qdate year quarter gini_core gini_broad gini_fincbtax gini_fsalaryx ///
    sh_rr MP_FFF_GW pi_trend_cg PI_TARGET PI_STAR_IRL_BACK

* Add variable labels
label var sh_rr "Romer-Romer monetary policy shock"
label var MP_FFF_GW "Gorodnichenko-Weber fed funds futures shock"
label var pi_trend_cg "Coibion-Gorodnichenko trend inflation shock"
label var PI_TARGET "Inflation target: Cogley-Primiceri-Sargent"
label var PI_STAR_IRL_BACK "Inflation target: Ireland"

* Save final merged dataset
save "$robust_data/gini_cgk_shocks_merged.dta", replace

display _n "========================================"
display "MERGE COMPLETE"
display "========================================"
display "Saved: $robust_data/gini_cgk_shocks_merged.dta"
display "Total observations: " _N
display "Date range: " %tq qdate[1] " to " %tq qdate[_N]
display _n "Overlapping period (1990-2008) for LP analysis:"
count if year >= 1990 & year <= 2008 & !missing(sh_rr)
display "  Observations with RR shocks: " r(N)
count if year >= 1990 & year <= 2008 & !missing(MP_FFF_GW)
display "  Observations with GW shocks: " r(N)
count if year >= 1990 & year <= 2008 & !missing(pi_trend_cg)
display "  Observations with trend inflation shocks: " r(N)

display _n "First 10 observations:"
list in 1/10

* Close log file
log close
