****************************************************
* 02_gini_2003.do
* Build 2003 consumption (core/broad) and Gini
****************************************************

clear all
set more off

global intr  "/Volumes/SSD PRO/Github-forks/Chp3-EnergyIneq/Code/Data/CEX/intrvw03/intrvw03"
global deriv "/Volumes/SSD PRO/Github-forks/Chp3-EnergyIneq/Code/Data/CEX/derived"

capture which ineqdeco
if _rc ssc install ineqdeco

****************************************************
* 1. Load MTBI expenditure microdata
****************************************************
cd "$intr"

use mtbi031x.dta, clear
foreach f in mtbi032 mtbi033 mtbi034 mtbi041 {
    append using `f'.dta
}

* Standardize variable names (1996-2020 use lowercase)
capture rename newid NEWID
capture rename ucc UCC
capture rename cost COST
capture rename ref_mo REF_MO

keep NEWID UCC COST REF_MO
destring UCC, replace

****************************************************
* 2. Merge with UCC map
****************************************************
merge m:1 UCC using "$deriv/ucc_map_2003.dta"
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
save "$deriv/mtbi_2003_tagged.dta", replace

****************************************************
* 5. Build weights file and extract income data
****************************************************
cd "$intr"
preserve
* Load first FMLI file and assign quarter
use fmli031x.dta, clear
gen quarter = 1

* Load remaining FMLI files and assign quarters sequentially
local q = 2
foreach f in fmli032 fmli033 fmli034 fmli041 {
    append using `f'.dta
    replace quarter = `q' if quarter == .
    local q = `q' + 1
}

* Standardize variable names (1996-2020 use lowercase)
capture rename newid NEWID
capture rename finlwt21 FINLWT21

* Extract income variables
keep NEWID FINLWT21 fincbtax fsalaryx quarter
gen year = 2003

* Drop missing income values
drop if missing(fincbtax) & missing(fsalaryx)

* Save income data at CU-quarter level
order NEWID year quarter fincbtax fsalaryx FINLWT21
save "$deriv/income_2003_cuq.dta", replace

* Also create weights-only file for consumption merge
keep NEWID FINLWT21
duplicates drop NEWID, force
tempfile weights
save `weights'
restore

****************************************************
* 6. Collapse to CU-quarter level + merge weights
****************************************************
use "$deriv/mtbi_2003_tagged.dta", clear
collapse (sum) cons_core_q=cons_core_item cons_broad_q=cons_broad_item, by(NEWID quarter)
gen year = 2003

merge m:1 NEWID using `weights'
keep if _merge==3
drop _merge

drop if cons_core_q <= 0 | cons_broad_q <= 0

order NEWID year quarter cons_core_q cons_broad_q FINLWT21
save "$deriv/cons_2003_cuq.dta", replace

****************************************************
* 7. Collapse to CU-year level
****************************************************
collapse (sum) cons_core_y=cons_core_q cons_broad_y=cons_broad_q (first) FINLWT21, by(NEWID)
gen year = 2003

order NEWID year cons_core_y cons_broad_y FINLWT21
save "$deriv/cons_2003_cuy.dta", replace

****************************************************
* 8. Compute quarterly consumption Ginis
****************************************************
postfile gini_post int year int quarter double gini_core double gini_broad ///
    using "$deriv/gini_2003_quarterly.dta", replace

forvalues q = 1/4 {
    quietly {
        use "$deriv/cons_2003_cuq.dta", clear
        keep if quarter == `q'
        ineqdeco cons_core_q [aw = FINLWT21]
        scalar gc = r(gini)
        ineqdeco cons_broad_q [aw = FINLWT21]
        scalar gb = r(gini)
    }
    post gini_post (2003) (`q') (gc) (gb)
}
postclose gini_post

****************************************************
* 8a. Compute quarterly income Ginis
****************************************************
postfile gini_inc_post int year int quarter double gini_fincbtax double gini_fsalaryx ///
    using "$deriv/gini_2003_income_quarterly.dta", replace

forvalues q = 1/4 {
    quietly {
        use "$deriv/income_2003_cuq.dta", clear
        keep if quarter == `q'
        * Compute Gini for fincbtax (drop missing)
        preserve
        drop if missing(fincbtax) | fincbtax <= 0
        if _N > 0 {
            ineqdeco fincbtax [aw = FINLWT21]
            scalar g_fincbtax = r(gini)
        }
        else {
            scalar g_fincbtax = .
        }
        restore
        
        * Compute Gini for fsalaryx (drop missing)
        preserve
        drop if missing(fsalaryx) | fsalaryx <= 0
        if _N > 0 {
            ineqdeco fsalaryx [aw = FINLWT21]
            scalar g_fsalaryx = r(gini)
        }
        else {
            scalar g_fsalaryx = .
        }
        restore
    }
    post gini_inc_post (2003) (`q') (g_fincbtax) (g_fsalaryx)
}
postclose gini_inc_post

****************************************************
* 9. Compute annual Gini
****************************************************
use "$deriv/cons_2003_cuy.dta", clear

ineqdeco cons_core_y [aw = FINLWT21]
scalar gini_core_annual = r(gini)

ineqdeco cons_broad_y [aw = FINLWT21]
scalar gini_broad_annual = r(gini)

clear
set obs 1
gen year       = 2003
gen quarter    = .
gen gini_core  = gini_core_annual
gen gini_broad = gini_broad_annual
save "$deriv/gini_2003_annual.dta", replace

****************************************************
* 10. Combine quarterly + annual
****************************************************
* Merge consumption and income quarterly Ginis
use "$deriv/gini_2003_quarterly.dta", clear
merge 1:1 year quarter using "$deriv/gini_2003_income_quarterly.dta"
drop _merge

* Append annual consumption Ginis (no annual income Ginis per user request)
append using "$deriv/gini_2003_annual.dta"

* Set income Ginis to missing for annual observations
replace gini_fincbtax = . if quarter == .
replace gini_fsalaryx = . if quarter == .

order year quarter gini_core gini_broad gini_fincbtax gini_fsalaryx
save "$deriv/gini_2003_all.dta", replace

* Clean up intermediate files
erase "$deriv/gini_2003_quarterly.dta"
erase "$deriv/gini_2003_income_quarterly.dta"
erase "$deriv/gini_2003_annual.dta"

display _n "Saved: gini_2003_all.dta"
