****************************************************
* 03_append_gini_all.do
* Append all yearly Gini files into one panel
* with quarterly date format for merging
****************************************************

clear all
set more off

global deriv "/Volumes/SSD PRO/Github-forks/Chp3-EnergyIneq/Code/Data/CEX/derived"

****************************************************
* 1. Append all yearly Gini files
****************************************************
cd "$deriv"

use gini_1996_all.dta, clear

forvalues y = 1997/2023 {
    capture append using gini_`y'_all.dta
}

****************************************************
* 2. Sort and create quarterly date variable
****************************************************
sort year quarter

* Create Stata quarterly date (for quarterly obs only)
gen qdate = yq(year, quarter) if quarter != .
format qdate %tq

* Create string date like "1996q1" for easy reading
gen str8 date_str = string(year) + "q" + string(quarter) if quarter != .
replace date_str = string(year) + " annual" if quarter == .

****************************************************
* 3. Order and save final panel
****************************************************
order year quarter qdate date_str gini_core gini_broad
sort year quarter

label var year       "Year"
label var quarter    "Quarter (. = annual)"
label var qdate      "Stata quarterly date"
label var date_str   "Date string"
label var gini_core  "Gini coefficient - core consumption"
label var gini_broad "Gini coefficient - broad consumption"

save "$deriv/gini_1996_2023.dta", replace

* Also export quarterly-only version (for merging with monthly data)
drop if quarter == .
drop date_str
order year quarter qdate gini_core gini_broad
save "$deriv/gini_1996_2023_quarterly.dta", replace

display _n "Saved:"
display "  $deriv/gini_1996_2023.dta (quarterly + annual)"
display "  $deriv/gini_1996_2023_quarterly.dta (quarterly only)"

* Show summary
list in 1/20

