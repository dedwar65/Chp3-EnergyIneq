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

* Start with earliest year
capture confirm file gini_1990_all.dta
if _rc {
    display "ERROR: gini_1990_all.dta not found!"
    exit 111
}
use gini_1990_all.dta, clear
display "Loaded gini_1990_all.dta: " _N " observations"

* Append subsequent years
forvalues y = 1991/2023 {
    capture confirm file gini_`y'_all.dta
    if !_rc {
        capture append using gini_`y'_all.dta
        if !_rc {
            display "Appended gini_`y'_all.dta: " _N " total observations"
        }
        else {
            display "WARNING: Failed to append gini_`y'_all.dta"
        }
    }
    else {
        display "WARNING: gini_`y'_all.dta not found, skipping"
    }
}

* Check date range
display _n "=== APPENDED DATA SUMMARY ==="
count
display "Total observations: " r(N)
summarize year
display "Year range: " r(min) " to " r(max)
quietly count if year >= 1990 & year <= 1995
display "Observations for 1990-1995: " r(N)
quietly count if year >= 1996 & year <= 2008
display "Observations for 1996-2008: " r(N)

****************************************************
* 2. Sort and create quarterly date variable
****************************************************
sort year quarter

* Create Stata quarterly date (for quarterly obs only)
gen qdate = yq(year, quarter) if quarter != .
format qdate %tq

* Create string date like "1990q1" for easy reading
gen str8 date_str = string(year) + "q" + string(quarter) if quarter != .
replace date_str = string(year) + " annual" if quarter == .

****************************************************
* 3. Order and save final panel
****************************************************
order year quarter qdate date_str gini_core gini_broad gini_fincbtax gini_fsalaryx
sort year quarter

label var year          "Year"
label var quarter       "Quarter (. = annual)"
label var qdate         "Stata quarterly date"
label var date_str      "Date string"
label var gini_core     "Gini coefficient - core consumption"
label var gini_broad    "Gini coefficient - broad consumption"
label var gini_fincbtax "Gini coefficient - income before taxes"
label var gini_fsalaryx "Gini coefficient - salary income"

save "$deriv/gini_1990_2023.dta", replace

* Also export quarterly-only version (for merging with monthly data)
drop if quarter == .
drop date_str
order year quarter qdate gini_core gini_broad gini_fincbtax gini_fsalaryx

* Verify quarterly file has correct date range
display _n "=== QUARTERLY FILE VERIFICATION ==="
count
display "Quarterly observations: " r(N)
summarize year
display "Year range: " r(min) " to " r(max)
quietly count if year >= 1990 & year <= 1995
display "Observations for 1990-1995: " r(N)
if r(N) == 0 {
    display "ERROR: No observations for 1990-1995 in quarterly file!"
    display "This will cause the baseline to be missing data."
}
quietly count if year >= 1996 & year <= 2008
display "Observations for 1996-2008: " r(N)

save "$deriv/gini_1990_2023_quarterly.dta", replace

display _n "Saved:"
display "  $deriv/gini_1990_2023.dta (quarterly + annual)"
display "  $deriv/gini_1990_2023_quarterly.dta (quarterly only)"

* Show summary
display _n "First 10 observations:"
list year quarter qdate gini_core gini_broad in 1/10

