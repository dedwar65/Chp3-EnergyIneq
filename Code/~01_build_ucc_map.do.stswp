****************************************************
* 01_build_ucc_map.do
* Build UCC mapping for 2023 from HG integrated stub
****************************************************

clear all
set more off

global stubs "/Volumes/SSD PRO/Github-forks/Chp3-EnergyIneq/Code/Data/CEX/stubs"
global deriv "/Volumes/SSD PRO/Github-forks/Chp3-EnergyIneq/Code/Data/CEX/derived"

capture mkdir "$deriv"

*---- Read hierarchical grouping stub for 2023 ----*
cd "$stubs"

infix ///
    str1 line_type      1       ///
    byte level          4       ///
    str59 name          11-69   ///
    str6 ucc_code       70-75   ///
    str1 source         80      ///
    byte factor         83      ///
    str7 section        86-92   ///
    using "CE-HG-Integ-2023.txt"

* Drop comment lines
drop if line_type=="*"

* Drop empty ucc_code rows
drop if trim(ucc_code)==""

* Keep only rows where ucc_code is all digits (real UCCs)
gen byte ucc_isnum = regexm(ucc_code, "^[0-9]+$")
keep if ucc_isnum
drop ucc_isnum

* Keep only expenditure sections
keep if inlist(section, "FOOD", "EXPEND")

* Make numeric UCC
destring ucc_code, gen(UCC) ignore(" ")

keep UCC section name
compress
save "$deriv/ucc_map_2023.dta", replace

display "Saved: $deriv/ucc_map_2023.dta"
