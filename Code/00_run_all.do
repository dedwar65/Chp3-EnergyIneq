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
forvalues y = 1990/2023 {
    display _n "Processing `y'..."
    do "$code/02_gini_`y'.do"
}

* Step 3: Append all years together
display _n "=== Appending all years ===" _n
do "$code/03_append_gini_all.do"

* Step 4: Merge BH shocks
display _n "=== Merging BH shocks ===" _n
do "$code/04_merge_bh_shocks.do"

* Step 5: Merge FRED data
display _n "=== Merging FRED data ===" _n
do "$code/05_merge_fred_data.do"

* Step 6: Local Projections
display _n "=== Running Local Projections ===" _n
do "$code/06_local_projections.do"

display _n "=== DONE ===" _n
display "Final Gini panel: Code/Data/CEX/derived/gini_1990_2023_quarterly.dta"
display "Final merged shocks panel: gini_bh_shocks_fred_merged.dta"
display "IRF results: Paper/Tables/lp_irf_results.csv"
display "IRF plots: Paper/Figures/irf_*.png"

