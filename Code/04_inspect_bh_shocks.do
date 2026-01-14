****************************************************
* 04_inspect_bh_shocks.do
* Inspect BH shock Excel files to understand structure
****************************************************

clear all
set more off

global bh_shocks "/Volumes/SSD PRO/Github-forks/Chp3-EnergyIneq/Code/Data/BH shocks"

****************************************************
* Inspect demand shocks
****************************************************
display _n "=== DEMAND SHOCKS ===" _n
import excel "$bh_shocks/BH2_demand_shocks.xlsx", firstrow clear
describe
list in 1/20

****************************************************
* Inspect supply shocks
****************************************************
display _n "=== SUPPLY SHOCKS ===" _n
import excel "$bh_shocks/BH2_supply_shocks.xlsx", firstrow clear
describe
list in 1/20



