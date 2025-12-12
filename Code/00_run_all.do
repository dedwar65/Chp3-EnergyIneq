****************************************************
* 00_run_all.do
* Master file - runs entire Gini pipeline
****************************************************

clear all
set more off

global code "/Volumes/SSD PRO/Github-forks/Chp3-EnergyIneq/Code"

* Step 1: Build all UCC maps
display _n "=== Building UCC maps ===" _n
do "$code/01_build_ucc_map.do"

* Step 2: Run each year's Gini computation
display _n "=== Computing yearly Ginis ===" _n
forvalues y = 1996/2023 {
    if `y' != 1999 {
        display _n "Processing `y'..."
        do "$code/02_gini_`y'.do"
    }
}

* Step 3: Append all years together
display _n "=== Appending all years ===" _n
do "$code/03_append_gini_all.do"

display _n "=== DONE ===" _n
display "Final output: gini_1996_2023.dta"

