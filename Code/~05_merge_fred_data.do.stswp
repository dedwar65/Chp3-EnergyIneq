****************************************************
* 05_merge_fred_data.do
* Import FRED data (industrial production, inflation, treasury yields)
* Convert to quarterly and merge with Gini-BH shocks dataset
****************************************************

clear all
set more off

global fred "/Volumes/SSD PRO/Github-forks/Chp3-EnergyIneq/Code/Data/FRED"
global deriv "/Volumes/SSD PRO/Github-forks/Chp3-EnergyIneq/Code/Data/CEX/derived"
global code "/Volumes/SSD PRO/Github-forks/Chp3-EnergyIneq/Code"

****************************************************
* 1. Import 1-year Treasury yield (GS1)
****************************************************
import delimited "$fred/GS1.csv", clear

* Parse date and create quarterly date
gen date = date(observation_date, "YMD")
format date %td
gen year = year(date)
gen month = month(date)
gen quarter = ceil(month/3)
gen qdate = yq(year, quarter)
format qdate %tq

* Rename variable (Stata converts CSV headers to lowercase)
rename gs1 treasury_1yr

* Collapse to quarterly (average monthly rates)
collapse (mean) treasury_1yr, by(qdate year quarter)

* Save temporary file
tempfile gs1
save `gs1'

display "Imported GS1: " _N " quarterly observations"

****************************************************
* 2. Import Industrial Production (INDPRO)
****************************************************
import delimited "$fred/INDPRO.csv", clear

* Parse date and create quarterly date
gen date = date(observation_date, "YMD")
format date %td
gen year = year(date)
gen month = month(date)
gen quarter = ceil(month/3)
gen qdate = yq(year, quarter)
format qdate %tq

* Rename variable and take log (Stata converts CSV headers to lowercase)
rename indpro indpro_raw
gen log_indpro = log(indpro_raw)
drop indpro_raw

* Collapse to quarterly (average of log levels)
collapse (mean) log_indpro, by(qdate year quarter)

* Save temporary file
tempfile indpro
save `indpro'

display "Imported INDPRO: " _N " quarterly observations"

****************************************************
* 3. Import Headline CPI (CPIAUCSL)
****************************************************
import delimited "$fred/CPIAUCSL.csv", clear

* Parse date and create quarterly date
gen date = date(observation_date, "YMD")
format date %td
gen year = year(date)
gen month = month(date)
gen quarter = ceil(month/3)
gen qdate = yq(year, quarter)
format qdate %tq

* Rename variable and take log (Stata converts CSV headers to lowercase)
rename cpiaucsl cpi_headline_raw
gen log_cpi_headline = log(cpi_headline_raw)
drop cpi_headline_raw

* Collapse to quarterly (average of log levels)
collapse (mean) log_cpi_headline, by(qdate year quarter)

* Compute quarterly inflation as log difference
sort qdate
gen infl_headline = log_cpi_headline - log_cpi_headline[_n-1]

* Save temporary file
tempfile cpi_headline
save `cpi_headline'

display "Imported CPIAUCSL: " _N " quarterly observations"

****************************************************
* 4. Import Core CPI (CPILFESL)
****************************************************
import delimited "$fred/CPILFESL.csv", clear

* Parse date and create quarterly date
gen date = date(observation_date, "YMD")
format date %td
gen year = year(date)
gen month = month(date)
gen quarter = ceil(month/3)
gen qdate = yq(year, quarter)
format qdate %tq

* Rename variable and take log (Stata converts CSV headers to lowercase)
rename cpilfesl cpi_core_raw
gen log_cpi_core = log(cpi_core_raw)
drop cpi_core_raw

* Collapse to quarterly (average of log levels)
collapse (mean) log_cpi_core, by(qdate year quarter)

* Compute quarterly inflation as log difference
sort qdate
gen infl_core = log_cpi_core - log_cpi_core[_n-1]

* Save temporary file
tempfile cpi_core
save `cpi_core'

display "Imported CPILFESL: " _N " quarterly observations"

****************************************************
* 5. Import Unemployment Rate (UNRATE)
****************************************************
import delimited "$fred/UNRATE.csv", clear

* Parse date and create quarterly date
gen date = date(observation_date, "YMD")
format date %td
gen year = year(date)
gen month = month(date)
gen quarter = ceil(month/3)
gen qdate = yq(year, quarter)
format qdate %tq

* Variable is already lowercase (no rename needed)
* unrate is the variable name

* Collapse to quarterly (average monthly rates)
collapse (mean) unrate, by(qdate year quarter)

* Save temporary file
tempfile unrate
save `unrate'

display "Imported UNRATE: " _N " quarterly observations"

****************************************************
* 6. Merge all FRED data together
****************************************************
use `gs1', clear

merge 1:1 qdate using `indpro'
drop _merge

merge 1:1 qdate using `cpi_headline'
drop _merge

merge 1:1 qdate using `cpi_core'
drop _merge

merge 1:1 qdate using `unrate'
drop _merge

* Save combined FRED data
save "$deriv/fred_quarterly.dta", replace

display _n "=== FRED DATA SUMMARY ==="
describe
summarize qdate
list in 1/10

****************************************************
* 7. Merge with existing Gini-BH shocks dataset
****************************************************
use "$deriv/gini_bh_shocks_merged.dta", clear

display _n "=== GINI-BH SHOCKS DATA ==="
count
summarize qdate

* Merge with FRED data
merge 1:1 qdate using "$deriv/fred_quarterly.dta"

display _n "=== MERGE RESULTS ==="
tab _merge

* Keep only matched observations (or adjust as needed)
keep if _merge == 3
drop _merge

* Sort and order variables
sort qdate
order qdate year quarter gini_core gini_broad demand_shock_agg demand_shock_oil supply_shock ///
    treasury_1yr log_indpro log_cpi_headline log_cpi_core infl_headline infl_core unrate

* Add variable labels
label var treasury_1yr "1-year Treasury yield (%)"
label var log_indpro "Log Industrial Production (quarterly average)"
label var log_cpi_headline "Log Headline CPI (quarterly average)"
label var log_cpi_core "Log Core CPI (quarterly average)"
label var infl_headline "Headline inflation (quarterly, log difference)"
label var infl_core "Core inflation (quarterly, log difference)"
label var unrate "Unemployment rate (%)"

* Save final merged dataset
save "$deriv/gini_bh_shocks_fred_merged.dta", replace

display _n "=== FINAL MERGED DATASET ==="
describe
count
local n_final = r(N)
display _n "First 10 observations:"
list in 1/10
if `n_final' > 10 {
    display _n "Last 10 observations:"
    list in `=`n_final'-9'/`n_final'
}

display _n "Final dataset saved: $deriv/gini_bh_shocks_fred_merged.dta"

