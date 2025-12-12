****************************************************
* 02_gini_2023.do
* Build 2023 consumption (core/broad) and Gini
****************************************************

clear all
set more off

global intr  "/Volumes/SSD PRO/Github-forks/Chp3-EnergyIneq/Code/Data/CEX/intrvw23"
global deriv "/Volumes/SSD PRO/Github-forks/Chp3-EnergyIneq/Code/Data/CEX/derived"

* Ensure ineqdeco is installed
capture which ineqdeco
if _rc ssc install ineqdeco

****************************************************
* 1. Load MTBI expenditure microdata for 2023
****************************************************
cd "$intr"

use mtbi232.dta, clear
foreach f in mtbi233 mtbi234 mtbi241 {
    append using `f'.dta
}

keep NEWID UCC COST REF_MO
destring UCC, replace

****************************************************
* 2. Merge with UCC map
****************************************************
merge m:1 UCC using "$deriv/ucc_map_2023.dta"
keep if _merge==3
drop _merge

****************************************************
* 3. Classify core vs broad consumption
****************************************************
gen uppername = upper(name)

* Exclusions from core: mortgage/rent/health/education
gen excl_core = ///
    (strpos(uppername,"MORTGAGE")>0)  | ///
    (strpos(uppername,"RENT")>0)      | ///
    (strpos(uppername,"HEALTH")>0)    | ///
    (strpos(uppername,"MEDICAL")>0)   | ///
    (strpos(uppername,"EDUC")>0)

* Broad: all food + expenditure
gen cons_broad_item = COST if inlist(section,"FOOD","EXPEND")

* Core: broad minus excluded categories
gen cons_core_item = cons_broad_item
replace cons_core_item = . if excl_core

* Create quarter from REF_MO
destring REF_MO, replace ignore(" ")
gen quarter = ceil(REF_MO/3)

****************************************************
* 4. Save item-level tagged file
****************************************************
save "$deriv/mtbi_2023_tagged.dta", replace

****************************************************
* 5. Build weights file and extract income data
****************************************************
cd "$intr"
preserve
* Load first FMLI file and assign quarter
use fmli232.dta, clear
gen quarter = 1

* Load remaining FMLI files and assign quarters sequentially
local q = 2
foreach f in fmli233 fmli234 fmli241 {
    append using `f'.dta
    replace quarter = `q' if quarter == .
    local q = `q' + 1
}

* Handle variable name casing (2021-2023 use uppercase FINCBTXM/FSALARYM, standardize to lowercase)
capture rename FINCBTXM fincbtxm
capture rename FSALARYM fsalarym

* Extract income variables
keep NEWID FINLWT21 fincbtxm fsalarym quarter
gen year = 2023

* Drop missing income values
drop if missing(fincbtxm) & missing(fsalarym)

* Save income data at CU-quarter level
order NEWID year quarter fincbtxm fsalarym FINLWT21
save "$deriv/income_2023_cuq.dta", replace

* Also create weights-only file for consumption merge
keep NEWID FINLWT21
duplicates drop NEWID, force
tempfile weights
save `weights'
restore

****************************************************
* 6. Collapse to CU-quarter level + merge weights
****************************************************
use "$deriv/mtbi_2023_tagged.dta", clear
collapse (sum) cons_core_q=cons_core_item cons_broad_q=cons_broad_item, by(NEWID quarter)
gen year = 2023

merge m:1 NEWID using `weights'
keep if _merge==3
drop _merge

* Drop zero/negative consumption
drop if cons_core_q <= 0 | cons_broad_q <= 0

order NEWID year quarter cons_core_q cons_broad_q FINLWT21
save "$deriv/cons_2023_cuq.dta", replace

****************************************************
* 7. Collapse to CU-year level
****************************************************
collapse (sum) cons_core_y=cons_core_q cons_broad_y=cons_broad_q (first) FINLWT21, by(NEWID)
gen year = 2023

order NEWID year cons_core_y cons_broad_y FINLWT21
save "$deriv/cons_2023_cuy.dta", replace

****************************************************
* 8. Compute quarterly consumption Ginis
****************************************************
use "$deriv/cons_2023_cuq.dta", clear

postfile gini_post int year int quarter double gini_core double gini_broad ///
    using "$deriv/gini_2023_quarterly.dta", replace

forvalues q = 1/4 {
    quietly {
        use "$deriv/cons_2023_cuq.dta", clear
        keep if quarter == `q'
        ineqdeco cons_core_q [aw = FINLWT21]
        scalar gc = r(gini)
        ineqdeco cons_broad_q [aw = FINLWT21]
        scalar gb = r(gini)
    }
    post gini_post (2023) (`q') (gc) (gb)
}
postclose gini_post

****************************************************
* 8a. Compute quarterly income Ginis
****************************************************
use "$deriv/income_2023_cuq.dta", clear

postfile gini_inc_post int year int quarter double gini_fincbtax double gini_fsalaryx ///
    using "$deriv/gini_2023_income_quarterly.dta", replace

forvalues q = 1/4 {
    quietly {
        use "$deriv/income_2023_cuq.dta", clear
        keep if quarter == `q'
        * Compute Gini for fincbtxm (drop missing)
        preserve
        drop if missing(fincbtxm) | fincbtxm <= 0
        if _N > 0 {
            ineqdeco fincbtxm [aw = FINLWT21]
            scalar g_fincbtax = r(gini)
        }
        else {
            scalar g_fincbtax = .
        }
        restore
        
        * Compute Gini for fsalarym (drop missing)
        preserve
        drop if missing(fsalarym) | fsalarym <= 0
        if _N > 0 {
            ineqdeco fsalarym [aw = FINLWT21]
            scalar g_fsalaryx = r(gini)
        }
        else {
            scalar g_fsalaryx = .
        }
        restore
    }
    post gini_inc_post (2023) (`q') (g_fincbtax) (g_fsalaryx)
}
postclose gini_inc_post

****************************************************
* 9. Compute annual Gini
****************************************************
use "$deriv/cons_2023_cuy.dta", clear

ineqdeco cons_core_y [aw = FINLWT21]
scalar gini_core_annual = r(gini)

ineqdeco cons_broad_y [aw = FINLWT21]
scalar gini_broad_annual = r(gini)

clear
set obs 1
gen year       = 2023
gen quarter    = .
gen gini_core  = gini_core_annual
gen gini_broad = gini_broad_annual
save "$deriv/gini_2023_annual.dta", replace

****************************************************
* 10. Combine quarterly + annual into one file
****************************************************
* Merge consumption and income quarterly Ginis
use "$deriv/gini_2023_quarterly.dta", clear
merge 1:1 year quarter using "$deriv/gini_2023_income_quarterly.dta"
drop _merge

* Append annual consumption Ginis (no annual income Ginis per user request)
append using "$deriv/gini_2023_annual.dta"

* Set income Ginis to missing for annual observations
replace gini_fincbtax = . if quarter == .
replace gini_fsalaryx = . if quarter == .

order year quarter gini_core gini_broad gini_fincbtax gini_fsalaryx
save "$deriv/gini_2023_all.dta", replace

* Clean up intermediate files
erase "$deriv/gini_2023_quarterly.dta"
erase "$deriv/gini_2023_income_quarterly.dta"
erase "$deriv/gini_2023_annual.dta"

display _n "Saved:"
display "  $deriv/mtbi_2023_tagged.dta (item-level)"
display "  $deriv/cons_2023_cuq.dta (CU-quarter)"
display "  $deriv/cons_2023_cuy.dta (CU-year)"
display "  $deriv/gini_2023_all.dta (quarterly + annual Ginis)"
