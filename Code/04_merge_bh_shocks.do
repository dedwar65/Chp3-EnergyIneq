****************************************************
* 04_merge_bh_shocks.do
* Import BH supply and demand shocks and merge with quarterly Gini
****************************************************

clear all
set more off

global bh_shocks "/Volumes/SSD PRO/Github-forks/Chp3-EnergyIneq/Code/Data/BH shocks"
global deriv "/Volumes/SSD PRO/Github-forks/Chp3-EnergyIneq/Code/Data/CEX/derived"
global code "/Volumes/SSD PRO/Github-forks/Chp3-EnergyIneq/Code"

* Start log file
log using "$code/04_merge_bh_shocks.log", replace

****************************************************
* 1. Import demand shocks
****************************************************
import excel "$bh_shocks/BH2_demand_shocks.xlsx", firstrow clear

* Drop header rows - drop if shock value (B) is missing or non-numeric
drop if missing(B)
destring B, gen(demand_shock) force
drop if missing(demand_shock)

* Parse date string like "Jun-76" to year and month
* Convert A to string if it's numeric
capture confirm string variable A
if _rc {
    * A is numeric, convert to string
    gen date_str = string(A, "%tdMon-YY")
}
else {
    * A is already string
    gen date_str = A
}
gen month_str = substr(date_str, 1, 3)
gen year_str = substr(date_str, 5, 2)

* Convert month abbreviation to number
gen month = .
replace month = 1 if month_str == "Jan"
replace month = 2 if month_str == "Feb"
replace month = 3 if month_str == "Mar"
replace month = 4 if month_str == "Apr"
replace month = 5 if month_str == "May"
replace month = 6 if month_str == "Jun"
replace month = 7 if month_str == "Jul"
replace month = 8 if month_str == "Aug"
replace month = 9 if month_str == "Sep"
replace month = 10 if month_str == "Oct"
replace month = 11 if month_str == "Nov"
replace month = 12 if month_str == "Dec"

* Convert 2-digit year to 4-digit (handle both 1900s and 2000s)
destring year_str, gen(year_2digit)
gen year = 1900 + year_2digit if year_2digit >= 50
replace year = 2000 + year_2digit if year_2digit < 50

* Create quarter from month
gen quarter = ceil(month/3)

* Create quarterly date for merging
gen qdate = yq(year, quarter)
format qdate %tq

* Clean up temporary variables
drop date_str month_str year_str year_2digit

* Collapse to quarterly (average monthly shocks within quarter)
collapse (mean) demand_shock, by(qdate year quarter)

* Save temporary file
tempfile demand
save `demand'

****************************************************
* 2. Import supply shocks
****************************************************
import excel "$bh_shocks/BH2_supply_shocks.xlsx", firstrow clear

* Drop header rows - drop if shock value (B) is missing or non-numeric
drop if missing(B)
destring B, gen(supply_shock) force
drop if missing(supply_shock)

* Parse date string like "Feb-75" to year and month
* Convert A to string if it's numeric
capture confirm string variable A
if _rc {
    * A is numeric, convert to string
    gen date_str = string(A, "%tdMon-YY")
}
else {
    * A is already string
    gen date_str = A
}
gen month_str = substr(date_str, 1, 3)
gen year_str = substr(date_str, 5, 2)

gen month = .
replace month = 1 if month_str == "Jan"
replace month = 2 if month_str == "Feb"
replace month = 3 if month_str == "Mar"
replace month = 4 if month_str == "Apr"
replace month = 5 if month_str == "May"
replace month = 6 if month_str == "Jun"
replace month = 7 if month_str == "Jul"
replace month = 8 if month_str == "Aug"
replace month = 9 if month_str == "Sep"
replace month = 10 if month_str == "Oct"
replace month = 11 if month_str == "Nov"
replace month = 12 if month_str == "Dec"

destring year_str, gen(year_2digit)
gen year = 1900 + year_2digit if year_2digit >= 50
replace year = 2000 + year_2digit if year_2digit < 50

* Create quarter from month
gen quarter = ceil(month/3)

* Create quarterly date for merging
gen qdate = yq(year, quarter)
format qdate %tq

* Clean up temporary variables
drop date_str month_str year_str year_2digit

* Collapse to quarterly (average monthly shocks within quarter)
collapse (mean) supply_shock, by(qdate year quarter)

* Save temporary file
tempfile supply
save `supply'

****************************************************
* 3. Merge supply and demand shocks
****************************************************
use `demand', clear
merge 1:1 qdate using `supply'
drop _merge

* Save combined shocks
save "$deriv/bh_shocks_quarterly.dta", replace

****************************************************
* 4. Merge with quarterly Gini data
****************************************************
use "$deriv/gini_1996_2023_quarterly.dta", clear

* Diagnostic: Check Gini data date range
display _n "=== GINI DATA DIAGNOSTICS ==="
count
summarize qdate
display "First 5 dates:"
list qdate year quarter in 1/5
display "Last 5 dates:"
count
local n_gini = r(N)
list qdate year quarter in `=`n_gini'-4'/`n_gini'

* Diagnostic: Check BH shocks date range
preserve
use "$deriv/bh_shocks_quarterly.dta", clear
display _n "=== BH SHOCKS DATA DIAGNOSTICS ==="
count
summarize qdate
display "First 5 dates:"
list qdate year quarter in 1/5
display "Last 5 dates:"
count
local n_shocks = r(N)
list qdate year quarter in `=`n_shocks'-4'/`n_shocks'
restore

* Now merge
merge 1:1 qdate using "$deriv/bh_shocks_quarterly.dta"
display _n "=== MERGE RESULTS ==="
tab _merge
display _n "Sample of matched observations:"
list qdate year quarter if _merge == 3 in 1/10
display _n "Sample of Gini-only (unmatched):"
list qdate year quarter if _merge == 1 in 1/10
display _n "Sample of shocks-only (unmatched):"
list qdate year quarter if _merge == 2 in 1/10

keep if _merge == 3  // Keep only matched observations
drop _merge

* Sort and save final merged dataset
sort qdate
order qdate year quarter gini_core gini_broad demand_shock supply_shock

label var demand_shock "BH demand shock"
label var supply_shock "BH supply shock"

save "$deriv/gini_bh_shocks_merged.dta", replace

display _n "Saved: $deriv/gini_bh_shocks_merged.dta"
display _n "=== FINAL MERGED DATASET SUMMARY ==="
describe
count
local n_final = r(N)
display _n "First 10 observations:"
list in 1/10
if `n_final' > 10 {
    display _n "Last 10 observations:"
    list in `=`n_final'-9'/`n_final'
}

* Close log file
log close
display _n "Log file saved: $code/04_merge_bh_shocks.log"

