* R.Platitas, May 2021
* File calculates the new tariffs under the US-PRC trade war 
* Written in Stata 15 on Windows 10

clear all

*Setting some parameters

local itpd itpd2                                          // SET the desired mapping
local baseyr=2016


timer on 1
********************************************************************************
****				Counterfactual # 1- US-PRC trade war					****
********************************************************************************

use imposedby imposedto hs tariffrate_latest status if status=="active" using  "$anlysdir/01Input/us_prc_tradewar_tariffs.dta",clear 
*This file is compiled from official documents (USTR and PRC MOFCOM),third-party sources (taxfoundation.org,PIIE,news announcements etc.)


ren (imposedby imposedto hs tariffrate_latest) (iso3_d iso3_o hs_str tariff_cfl)              //to standardize variable names
replace tariff_cfl=100*tariff_cfl                                                             //to express in %

*Aggregate at HS6 level since some trade war tariffs are at HS8 and HS10 level
replace hs_str=substr(hs_str,1,6)
collapse (mean) tariff_cfl,by(iso3_d iso3_o hs_str)

*Aggregating tariffs from 6-dig HS levels into 153-ITPD sectors
*Method: Simple average
merge m:1 hs_str using "$builddir/01Input/hs_itpd_concord.dta", keepusing(`itpd') keep(match master) nogen


ren `itpd' itpd_id
keep if !mi(itpd_id)

collapse (mean) tariff_cfl,by(iso3_d iso3_o itpd_id)

*Make sure there are no duplicates
egen id=concat(iso3_o iso3_d itpd_id)
duplicates drop id,force
drop id 

save "$anlysdir/01Input/cfl_1.dta", replace

timer off 1
timer list

********************************************************************************
****				Counterfactual # 2- RCEP					****
********************************************************************************

use year iso3_d iso3_o itpd_id tariff using "$builddir/04Temp/tariff_byitpd.dta",clear

keep if (inlist(iso3_o,"AUS","BRN","KHM","CHN","IDN","JPN","LAO","MYS","MMR")|inlist(iso3_o,"NZL","PHL","KOR","SGP","THA","VNM"))&(inlist(iso3_d,"AUS","BRN","KHM","CHN","IDN","JPN","LAO","MYS","MMR")|inlist(iso3_d,"NZL","PHL","KOR","SGP","THA","VNM"))

bysort itpd_id iso3_d iso3_o ( year): gen tariff_lastnmyr = year[_N]


keep if year==tariff_lastnmyr      //take the latest tariff data as baseline


*Reduce tariffs to zero for all bilateral trade among RCEP members
gen tariff_bline=tariff
gen tariff_cfl=0

*Make sure there are no duplicates
egen id=concat(iso3_o iso3_d itpd_id)
duplicates drop id,force
drop id 

keeporder iso3_d iso3_o itpd_id tariff_bline tariff_cfl
save "$anlysdir/01Input/cfl_2.dta", replace


////////////////////////////////////////////////////////////////////////////////
***	        GRAPHS-Plot tariff baseline v tariff counterfactual       		****
////////////////////////////////////////////////////////////////////////////////
local baseyr=2016

*Load baseline tariffs
use year iso3_o iso3_d itpd_id tariff if (year==`baseyr'&iso3_o=="CHN"&iso3_d=="USA")|(year==`baseyr'&iso3_o=="USA"&iso3_d=="CHN") using "$builddir/04Temp/tariff_byitpd.dta",clear
merge 1:1 iso3_o iso3_d itpd_id using "$anlysdir/01Input/cfl_1.dta"

gen broadsec="Agriculture" if itpd_id<=26
replace broadsec="Mining & Energy" if itpd_id>=27&itpd_id<=33
replace broadsec="Manufacturing" if itpd_id>=34

gen nochge= tariff      //  for the 45-deg line

labvars tariff tariff_cfl nochge "baseline tariff rate" "tariff rate under US-PRC trade war" "no change"


sepscatter tariff_cfl tariff if iso3_d=="USA",sep( broadsec ) name(USA) ///
legend(size(*0.75)) addplot(line nochge nochge ) title("USA tariffs on PRC exports") xtitle("baseline tariff rate")
  
 
sepscatter tariff_cfl tariff if iso3_d=="CHN",sep( broadsec ) name(CHN)  ///
legend(size(*0.75)) addplot(line nochge nochge ) title("PRC tariffs on USA exports") xtitle("baseline tariff rate")


grc1leg USA CHN, legendfrom(USA)
graph export "$anlysdir/03Output/PRCtariffs.png",replace

