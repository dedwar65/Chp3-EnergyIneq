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
* 5. Build weights file
****************************************************
cd "$intr"
preserve
use fmli232.dta, clear
foreach f in fmli233 fmli234 fmli241 {
    append using `f'.dta
}
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
* 8. Compute quarterly Ginis
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
use "$deriv/gini_2023_quarterly.dta", clear
append using "$deriv/gini_2023_annual.dta"
order year quarter gini_core gini_broad
save "$deriv/gini_2023_all.dta", replace

* Clean up intermediate files
erase "$deriv/gini_2023_quarterly.dta"
erase "$deriv/gini_2023_annual.dta"

display _n "Saved:"
display "  $deriv/mtbi_2023_tagged.dta (item-level)"
display "  $deriv/cons_2023_cuq.dta (CU-quarter)"
display "  $deriv/cons_2023_cuy.dta (CU-year)"
display "  $deriv/gini_2023_all.dta (quarterly + annual Ginis)"
