****************************************************
* 02_gini_2021.do
* Build 2021 consumption (core/broad) and Gini
****************************************************

clear all
set more off

global intr  "/Volumes/SSD PRO/Github-forks/Chp3-EnergyIneq/Code/Data/CEX/intrvw21"
global deriv "/Volumes/SSD PRO/Github-forks/Chp3-EnergyIneq/Code/Data/CEX/derived"

capture which ineqdeco
if _rc ssc install ineqdeco

****************************************************
* 1. Load MTBI expenditure microdata
****************************************************
cd "$intr"

use mtbi212.dta, clear
foreach f in mtbi213 mtbi214 mtbi221 {
    append using `f'.dta
}

keep NEWID UCC COST REF_MO
destring UCC, replace

****************************************************
* 2. Merge with UCC map
****************************************************
merge m:1 UCC using "$deriv/ucc_map_2021.dta"
keep if _merge==3
drop _merge

****************************************************
* 3. Classify core vs broad consumption
****************************************************
gen uppername = upper(name)

gen excl_core = ///
    (strpos(uppername,"MORTGAGE")>0)  | ///
    (strpos(uppername,"RENT")>0)      | ///
    (strpos(uppername,"HEALTH")>0)    | ///
    (strpos(uppername,"MEDICAL")>0)   | ///
    (strpos(uppername,"EDUC")>0)

gen cons_broad_item = COST if inlist(section,"FOOD","EXPEND")
gen cons_core_item = cons_broad_item
replace cons_core_item = . if excl_core

destring REF_MO, replace ignore(" ")
gen quarter = ceil(REF_MO/3)

****************************************************
* 4. Save item-level tagged file
****************************************************
save "$deriv/mtbi_2021_tagged.dta", replace

****************************************************
* 5. Build weights file
****************************************************
cd "$intr"
preserve
use fmli212.dta, clear
foreach f in fmli213 fmli214 fmli221 {
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
use "$deriv/mtbi_2021_tagged.dta", clear
collapse (sum) cons_core_q=cons_core_item cons_broad_q=cons_broad_item, by(NEWID quarter)
gen year = 2021

merge m:1 NEWID using `weights'
keep if _merge==3
drop _merge

drop if cons_core_q <= 0 | cons_broad_q <= 0

order NEWID year quarter cons_core_q cons_broad_q FINLWT21
save "$deriv/cons_2021_cuq.dta", replace

****************************************************
* 7. Collapse to CU-year level
****************************************************
collapse (sum) cons_core_y=cons_core_q cons_broad_y=cons_broad_q (first) FINLWT21, by(NEWID)
gen year = 2021

order NEWID year cons_core_y cons_broad_y FINLWT21
save "$deriv/cons_2021_cuy.dta", replace

****************************************************
* 8. Compute quarterly Ginis
****************************************************
postfile gini_post int year int quarter double gini_core double gini_broad ///
    using "$deriv/gini_2021_quarterly.dta", replace

forvalues q = 1/4 {
    quietly {
        use "$deriv/cons_2021_cuq.dta", clear
        keep if quarter == `q'
        ineqdeco cons_core_q [aw = FINLWT21]
        scalar gc = r(gini)
        ineqdeco cons_broad_q [aw = FINLWT21]
        scalar gb = r(gini)
    }
    post gini_post (2021) (`q') (gc) (gb)
}
postclose gini_post

****************************************************
* 9. Compute annual Gini
****************************************************
use "$deriv/cons_2021_cuy.dta", clear

ineqdeco cons_core_y [aw = FINLWT21]
scalar gini_core_annual = r(gini)

ineqdeco cons_broad_y [aw = FINLWT21]
scalar gini_broad_annual = r(gini)

clear
set obs 1
gen year       = 2021
gen quarter    = .
gen gini_core  = gini_core_annual
gen gini_broad = gini_broad_annual
save "$deriv/gini_2021_annual.dta", replace

****************************************************
* 10. Combine quarterly + annual
****************************************************
use "$deriv/gini_2021_quarterly.dta", clear
append using "$deriv/gini_2021_annual.dta"
order year quarter gini_core gini_broad
save "$deriv/gini_2021_all.dta", replace

erase "$deriv/gini_2021_quarterly.dta"
erase "$deriv/gini_2021_annual.dta"

display _n "Saved: gini_2021_all.dta"
