****************************************************
* 01_build_ucc_map.do
* Build UCC mappings for all years 1996-2023
****************************************************

clear all
set more off

global stubs "/Volumes/SSD PRO/Github-forks/Chp3-EnergyIneq/Code/Data/CEX/stubs"
global deriv "/Volumes/SSD PRO/Github-forks/Chp3-EnergyIneq/Code/Data/CEX/derived"

capture mkdir "$deriv"

****************************************************
* Loop through all years and build UCC maps
****************************************************
forvalues year = 1996/2023 {
    
    display _n "Processing year `year'..."
    
    cd "$stubs"
    
    quietly {
        infix ///
            str1 line_type      1       ///
            byte level          4       ///
            str59 name          11-69   ///
            str6 ucc_code       70-75   ///
            str1 source         80      ///
            byte factor         83      ///
            str7 section        86-92   ///
            using "CE-HG-Integ-`year'.txt", clear
        
        * Drop comment lines
        drop if line_type=="*"
        
        * Drop empty ucc_code rows
        drop if trim(ucc_code)==""
        
        * Keep only rows where ucc_code is all digits (real UCCs)
        gen byte ucc_isnum = regexm(ucc_code, "^[0-9]+$")
        keep if ucc_isnum
        drop ucc_isnum
        
        * Extract section name (handles both "FOOD" and "1  FOOD" formats)
        gen section_clean = word(section, -1)  // gets last word
        
        * Map abbreviations to full names
        replace section_clean = "EXPEND" if section_clean == "EXPE"
        replace section_clean = "ADDENDA" if section_clean == "ADDE"
        replace section_clean = "ASSETS" if section_clean == "ASSE"
        replace section_clean = "CUCHARS" if section_clean == "CUCH"
        replace section_clean = "INCOME" if section_clean == "INCO"
        
        * Keep only expenditure sections
        keep if inlist(section_clean, "FOOD", "EXPEND")
        drop section
        rename section_clean section
        
        * Make numeric UCC
        destring ucc_code, gen(UCC) ignore(" ")
        
        keep UCC section name
        compress
        save "$deriv/ucc_map_`year'.dta", replace
    }
    
    display "  Saved: ucc_map_`year'.dta"
}

display _n "Done. UCC maps saved for 1996-2023."
