* R.Platitas, May 2021
* Do file prepares raw .txt and .csv files to produce clean datasets: trade_byitpd.dta,grav_vars.dta,tariff_hs6.dta 
* Written in Stata 15.1 on Windows 10
     

cd "$builddir/01Input"
local itpd itpd2                                         // SET the desired mapping 
 
/*
itpd- resulted from three-way merging of HS-->FAOSTAT Commodity List (FCL)-->ITPD sector for Agriculture 
	and HS-->ISIC Rev.4-->ITPD sector for Mining, and Manufacturing
itpd2-improved on 'itpd' mapping by manually filling out the sectors of unmapped HS based on product
	description and sectors of nearby products 
*/


********************************************************************************
****		Converter from ISO numeric to ISO alphabet codes	     		****
********************************************************************************

*Concordance is needed since trade flow and gravity data are identified by country's iso-alpha code
*while tariff data are identified by country's iso-numeric code

*download excel file tru: http://unstats.un.org/unsd/tradekb/Attachment440.aspx?AttachmentType=1
import excel "$builddir/01Input/Comtrade Country Code and ISO list.xlsx", sheet("Sheet1") firstrow clear
*keep if EndValidYear=="Now"      //keep current/active codes only
keeporder CountryCode CountryNameFull CountryNameAbbreviation ISO3digitAlpha

ren (CountryCode CountryNameFull CountryNameAbbreviation ISO3digitAlpha) (ctrycode ctryname_full ctryname iso)

*Adjust for Taiwan since this is identified as 'Other Asia, nes' in COMTRADE nomenclature
replace iso="TWN" if ctrycode==490    
replace ctryname="Taipei, China" if ctrycode==490    
keep if iso!="N/A"


save "$builddir/04Temp/iso_codes.dta",replace

*Import ISO codes with region classification

clear
readhtmltable https://unstats.un.org/unsd/methodology/m49/overview/,varnames
keeporder M49_Code ISO_alpha3_Code Country_or_Area Region_Name Sub_region_Name Least_Developed_Countries__LDC_ Developed___Developing_Countries
rename (M49_Code ISO_alpha3_Code Country_or_Area Region_Name Sub_region_Name Least_Developed_Countries__LDC_ Developed___Developing_Countries) (iso_num iso_code ctryname region subregion ldc devstat)

destring iso_num,replace
*Remove irregular spaces
replace ldc=ustrtrim(ldc)
replace devstat=ustrtrim( devstat)

save "$builddir/04Temp/iso_regions.dta",replace

*Attach geo and econ groupings for summary stats

use "$builddir/04Temp/iso_codes.dta",clear
gen iso_num=ctrycode
merge 1:1 iso_num using "$builddir/04Temp/iso_regions.dta",keep(match master)

*Manual adjustments for nonmatching iso_num and iso_alpha (due to historical changes,territory exclusions)

replace region="Asia" if iso=="TWN"|iso=="IND"|iso=="VNM"
replace region="Americas" if iso=="USA"
replace region="Europe" if iso=="FRA"|iso=="ITA"|iso=="CHE"|iso=="ANT"|iso=="NOR"

replace subregion="Southern Asia" if iso=="IND"
replace subregion="Eastern Asia" if iso=="TWN"
replace subregion="South-eastern Asia" if iso=="VNM"
replace subregion="Northern America" if iso=="USA"
replace subregion="Western Europe" if iso=="FRA"|iso=="CHE"|iso=="ANT"
replace subregion="Northern Europe" if iso=="NOR"
replace subregion="Southern Europe" if iso=="ITA"

replace devstat="Developing" if iso=="TWN"|iso=="IND"|iso=="VNM"
replace devstat="Developed" if iso=="USA"|iso=="FRA"|iso=="ITA"|iso=="CHE"|iso=="ANT"|iso=="NOR"


gen dmc=1 if inlist(iso,"BGD","BRN","BTN","CHN","FJI","HKG","IDN","IND","KAZ")|inlist(iso,"KHM","KOR","LAO","LKA","MDV","MNG","MYS","NPL","PAK")|inlist(iso,"PHL","SGP","THA","TWN","VNM","AFG","ARM","AZE","GEO")|inlist(iso,"KIR","MHL","FSM","MMR","NRU","PLW","PNG","WSM","SLB")|inlist(iso,"TJK","TLS","TON","TKM","TUV","UZB","VUT","COK","NIU")
replace dmc=0 if mi(dmc)
keeporder ctrycode ctryname_full ctryname iso region subregion ldc devstat dmc

save "$builddir/04Temp/iso_codes.dta",replace


********************************************************************************
****						Regional aggregates	     						****
********************************************************************************

use "$builddir/04Temp/trade_byitpd.dta",clear

keep if year==2016 & iso3_o!=iso3_d
collapse(sum)trade,by(year itpd_id iso3_o)

gen iso=iso3_o

joinby iso using "$builddir/04Temp/iso_codes.dta"
keep if !mi(trade)&!mi(region)


egen sectrade_tot=sum(trade),by(itpd_id)
gen trade_dmc=trade*dmc
replace trade_dmc=0 if mi(trade_dmc)

levelsof region,local(region)

foreach x of local region { 
    gen trade_`x' = trade if region=="`x'"
	replace trade_`x'=0 if mi(trade_`x')
}


collapse (mean)sectrade_tot (sum)trade_*,by(itpd_id)

save "$builddir/04Temp/agg_trade.dta"


********************************************************************************
****						Broader sector aggregates	   					****
********************************************************************************

import excel "$builddir/01Input/ITPD_classification.xlsx", sheet("Sheet1") firstrow clear

keeporder itpd_id itpd_desc tiva_sec itpd_lab adbmriot_sec adbmriot_seccode
duplicates drop itpd_id,force

save "$builddir/04Temp/broadsec_agg.dta",replace


********************************************************************************
****						Bilateral Trade Flow Data		        		****
****						Source: ITPD-E (USITC)        		        	****
********************************************************************************
timer on 1
fs ITPD_*.zip
local f1=`r(files)'
unzipfile `f1',replace

fs ITPD*.csv
local f2=`r(files)'
import delimited "`f2'",clear

erase `f2'

keeporder year exporter_iso3 importer_iso3 industry_id trade

ren (exporter_iso3 importer_iso3 industry_id) (iso3_o iso3_d itpd_id)  // to standardize key variable names

save "$builddir/04Temp/trade_byitpd.dta",replace
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

save "$builddir/04Temp/grvty.dta",replace
timer off 2

********************************************************************************
****						Bilateral Tariff Data					   		****
****						Source: ITC MAcMap        		        		****
********************************************************************************
timer on 3

fs bulkdownload1.zip    
foreach f in `r(files)'{    
unzipfile "`f'",replace                                         //NOTE: These are large files >4gb which can only be unzipped by Stata 15.1 or newer. 
}

fs *agr_tr.txt
foreach a in `r(files)'{
erase `a'                                                      //delete misc. files: *agr_tr.txt files contain description of the agreement codes in *agr.txt files
} 


tempfile masterfile
save `masterfile',replace empty


fs *agr.txt
foreach f in `r(files)'{

import delimited "`f'",clear

rename (*) (v#) , addnumber
keep v1-v8
rename (v1 v2 v3 v4 v5 v6 v7 v8) (nomencode iso_d_num year hs6 tarlinect agr iso_o_num ave)

*Obtain effectively applied bilateral rate by getting the minimum among all preferential and MFN rates per year-imp-exp-hs6
collapse (min) ave_applied=ave,by(year iso_o_num iso_d_num  hs6)  

tostring hs6,gen(hs_str)
replace hs_str="0"+hs_str if length(hs_str)==5

merge m:1 hs_str using hs_itpd_concord.dta,nogen keep(match)


*Aggregating tariffs from 6-dig HS levels into 153-ITPD sectors
*Method: Simple average, for other suggested methods see Documentation III.A
collapse (mean) tariff=ave_applied,by(year iso_o_num iso_d_num `itpd')
replace tariff=100*tariff   // to express in %

ren `itpd' itpd_id


*Converting ISO numeric to ISO 3-letter codes
gen ctrycode=iso_o_num
merge m:1 ctrycode using "$builddir/04Temp/iso_codes.dta",keepusing(iso) keep(match) nogen
ren iso iso3_o
replace ctrycode=iso_d_num
merge m:1 ctrycode using "$builddir/04Temp/iso_codes.dta",keepusing(iso) keep(match) nogen
ren iso iso3_d

*Ensure distict entries
egen id=concat( year iso3_o iso3_d itpd_id)
duplicates drop id,force
drop id

append using  `masterfile'
save `masterfile', replace
erase `f'   
}

keep if !mi(itpd_id)                                  //keep only mapped HS codes
save "$builddir/04Temp/tariff_byitpd.dta",replace


timer off 3

timer list












