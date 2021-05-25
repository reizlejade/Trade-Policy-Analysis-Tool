* R.Platitas, May 2021
* Do file prepares raw .txt and .csv files to produce clean datasets: trade_byitpd.dta,grav_vars.dta,tariff_hs6.dta 
* Written in Stata 15.1 on Windows 10



********************************************************************************
****						Preliminary Settings							****
********************************************************************************
clear all
version 15.1.0
cap log close
set more off, perm
set mem 1g
set matsize 11000, perm
set maxvar 32767
set type double
macro drop _all
graph drop _all
timer clear


local projdir "D:\07 Trade Policy Analysis tool"
local builddir "`projdir'\01Build"
local anlysdir "`projdir'\02Analysis"      

cd "`builddir'\01Input"
********************************************************************************
****						Bilateral Trade Flow Data		        		****
****						Source: ITPD-E (USITC)        		        	****
********************************************************************************
timer on 1
fs ITPD_*
local f1=`r(files)'
unzipfile `f1',replace

fs ITPD*.csv
local f2=`r(files)'
import delimited "`f2'",clear

erase `f2'

keeporder year exporter_iso3 importer_iso3 industry_id trade

ren (exporter_iso3 importer_iso3 industry_id) (iso3_o iso3_d itpd_id)  // to standardize key variable names

save "`builddir'\03Output\trade_byitpd.dta",replace
timer off 1

********************************************************************************
****						Gravity variables Data					   		****
****			 Source: Dynamic Gravity Dataset (USITC) 	        		****
********************************************************************************

timer on 2
fs release_*
local f1=`r(files)'
unzipfile `f1',replace

fs release*.csv
local f2=`r(files)'
import delimited "`f2'",clear

erase `f2'

keep if year>1999                                         
*keeporder year iso3_o iso3_d distance common_language colony_ever contiguity agree_fta agree_cu 

save "`builddir'\03Output\grvty.dta",replace
timer off 2

********************************************************************************
****						Bilateral Tariff Data					   		****
****						Source: ITC MAcMap        		        		****
********************************************************************************
local projdir "D:\07 Trade Policy Analysis tool"
local builddir "`projdir'\01Build"
local anlysdir "`projdir'\02Analysis"      

cd "`builddir'\01Input"

timer on 3
fs bulkdownload*.zip    

foreach f in `r(files)'{    
unzipfile "`f'",replace                                         //NOTE: These are large files >4gb which can only be unzipped by Stata 15.1 or newer. 
}

fs *agr_tr.txt
foreach a in `r(files)'{
erase `a'                                                      //delete extra files
} 


tempfile masterfile
save `masterfile',replace empty

local itpd itpd3                                              // SET the desired mapping

fs *agr.txt
foreach f in `r(files)'{

import delimited "`f'",clear

rename (*) (v#) , addnumber
keep v1-v8
rename (v1 v2 v3 v4 v5 v6 v7 v8) (nomencode iso_d_num year hs6 tarlinect agr iso_o_num ave)

*Obtain effectively bilateral applied rate by getting the minimum among all preferential and MFN rates per year-imp-exp-hs6
collapse (min) ave_applied=ave,by(year iso_o_num iso_d_num  hs6)  

tostring hs6,gen(hs_str)
replace hs_str="0"+hs_str if length(hs_str)==5

merge m:1 hs_str using "`projdir'\04Misc\hs_itpd_concord.dta",nogen keep(match)


*Aggregating tariffs from 6-dig HS levels into 153-ITPD sectors
*Method: Simple average
collapse (mean) ave_applied,by( year iso_o_num iso_d_num `itpd')
replace ave_applied=100*ave_applied   // to express in %

ren (`itpd' ave_applied) (itpd_id tariff)

gen ctrycode=iso_o_num
merge m:1 ctrycode using "`projdir'\04Misc\baci_iso.dta",keepusing(iso) keep(match) nogen
ren iso iso3_o
replace ctrycode=iso_d_num
merge m:1 ctrycode using "`projdir'\04Misc\baci_iso.dta",keepusing(iso) keep(match) nogen
ren iso iso3_d

egen id=concat( year iso3_o iso3_d itpd_id)
duplicates drop id,force
drop id

append using  `masterfile'
save `masterfile', replace
erase `f'   
}

save "`builddir'\03Output\tariff_byitpd.dta",replace


timer off 3

timer list












