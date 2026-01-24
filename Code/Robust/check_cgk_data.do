* Quick check of CGK spec data
clear all
global robust_data "/Volumes/SSD PRO/Github-forks/Chp3-EnergyIneq/Code/Robust/Data"
use "$robust_data/gini_rr_merged_cgk_spec.dta", clear

display _n "=== Data Summary ==="
count
display "Total observations: " r(N)

display _n "=== Gini Summary by Year Range ==="
display "1990-1995:"
quietly count if year >= 1990 & year <= 1995
display "  Total obs: " r(N)
quietly count if year >= 1990 & year <= 1995 & !missing(gini_core)
display "  gini_core non-missing: " r(N)
quietly count if year >= 1990 & year <= 1995 & !missing(gini_broad)
display "  gini_broad non-missing: " r(N)
quietly count if year >= 1990 & year <= 1995 & !missing(gini_fincbtax)
display "  gini_fincbtax non-missing: " r(N)
quietly count if year >= 1990 & year <= 1995 & !missing(gini_fsalaryx)
display "  gini_fsalaryx non-missing: " r(N)

display _n "1996-2008:"
quietly count if year >= 1996 & year <= 2008
display "  Total obs: " r(N)
quietly count if year >= 1996 & year <= 2008 & !missing(gini_core)
display "  gini_core non-missing: " r(N)
quietly count if year >= 1996 & year <= 2008 & !missing(gini_broad)
display "  gini_broad non-missing: " r(N)
quietly count if year >= 1996 & year <= 2008 & !missing(gini_fincbtax)
display "  gini_fincbtax non-missing: " r(N)
quietly count if year >= 1996 & year <= 2008 & !missing(gini_fsalaryx)
display "  gini_fsalaryx non-missing: " r(N)

display _n "=== Sample of 1990-1995 data ==="
list year quarter gini_core gini_broad gini_fincbtax gini_fsalaryx if year >= 1990 & year <= 1995, clean noobs
