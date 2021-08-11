* R.Platitas, May 2021
* Do file prepares .txt and .csv files to produce clean datasets: trade_byitpd.dta, grav_vars.dta, and tariff_hs6.dta 
* Written in Stata 15.1 on Windows 10, tested on MacOS Catalina (4 Aug. 2021)
     

* Set working directory 
cd "$builddir/01Input"
local itpd itpd2


/*
ITPD resulted from three-way merging of 
		HS --> FAOSTAT Commodity List (FCL) --> ITPD sector (for Agriculture), and
		HS --> ISIC Rev.4 --> ITPD sector (for Mining, and Manufacturing)
ITPD2-improved on 'ITPD' mapping by manually filling out the sectors of unmapped HS based on product description & sectors of nearby products 
* All of the above was done in 0_HS_to_ITPD_mapping.do 
*/


********************************************************************************
****			Converter from ISO numeric to ISO letter codes				****
********************************************************************************

* Concordance is needed as trade & gravity data are identified by countries' 3-letter ISO codes
* while tariffs are identified by countries' numeric ISO codes

* Download .xlsx from: http://unstats.un.org/unsd/tradekb/Attachment440.aspx?AttachmentType=1
import excel "$builddir/01Input/Comtrade Country Code and ISO list.xlsx", sheet("Sheet1") firstrow clear
keeporder CountryCode CountryNameFull CountryNameAbbreviation ISO3digitAlpha
ren (CountryCode CountryNameFull CountryNameAbbreviation ISO3digitAlpha) (ctrycode ctryname_full ctryname iso)

* Adjust for Taiwan (i.e., identified as 'Other Asia, nes' in COMTRADE)
replace iso="TWN" if ctrycode==490    
replace ctryname="Taipei, China" if ctrycode==490    
keep if iso!="N/A"
save "$builddir/04Temp/iso_codes.dta",replace

* Import ISO codes matching w/ region + income groups
clear
readhtmltable https://unstats.un.org/unsd/methodology/m49/overview/,varnames
keeporder M49_Code ISO_alpha3_Code Country_or_Area Region_Name Sub_region_Name Least_Developed_Countries__LDC_ Developed___Developing_Countries
rename (M49_Code ISO_alpha3_Code Country_or_Area Region_Name Sub_region_Name Least_Developed_Countries__LDC_ Developed___Developing_Countries) (iso_num iso_code ctryname region subregion ldc devstat)
destring iso_num,replace
replace ldc=ustrtrim(ldc)			// Remove irregular spaces
replace devstat=ustrtrim( devstat)	// Remove irregular spaces
save "$builddir/04Temp/iso_regions.dta",replace

* Match numeric-letter ISO codes w/ region + income groups (used later to produce summary stats )
use "$builddir/04Temp/iso_codes.dta",clear
gen iso_num=ctrycode
merge 1:1 iso_num using "$builddir/04Temp/iso_regions.dta",keep(match master)

* Manual adjustments for non-matching iso_num and iso_alpha (due to historical changes, territory exclusions)
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

* Generate dummy for ADB developing member countries (DMC)
gen dmc=1 if inlist(iso,"BGD","BRN","BTN","CHN","FJI","HKG","IDN","IND","KAZ")|inlist(iso,"KHM","KOR","LAO","LKA","MDV","MNG","MYS","NPL","PAK")|inlist(iso,"PHL","SGP","THA","TWN","VNM","AFG","ARM","AZE","GEO")|inlist(iso,"KIR","MHL","FSM","MMR","NRU","PLW","PNG","WSM","SLB")|inlist(iso,"TJK","TLS","TON","TKM","TUV","UZB","VUT","COK","NIU")
replace dmc=0 if mi(dmc)
keeporder ctrycode ctryname_full ctryname iso region subregion ldc devstat dmc
save "$builddir/04Temp/iso_codes.dta",replace


********************************************************************************
****		Save ITPD broad sector codes & sector descriptions	   			****
********************************************************************************

* Note
*	ITPD 153 broad sectors are identified by 'itpd_id'
* 	ITPD 366 more precise sectors are identified by 'item_code'

import excel "$builddir/01Input/ITPD_classification.xlsx", sheet("Sheet1") firstrow clear
duplicates drop *, force
keeporder itpd_id itpd_desc tiva_sec itpd_lab adbmriot_sec adbmriot_seccode
duplicates drop itpd_id,force
save "$builddir/04Temp/broadsec_agg.dta",replace


********************************************************************************
****					 Prepare Bilateral Trade Data		    	   		****
****						Source: ITPD-E (USITC)        		        	****
********************************************************************************
timer on 1

* Unzip data
fs ITPD_*.zip
local f1=`r(files)'
unzipfile `f1',replace

* Load unnzipped data + erase unzipped .csv files
fs ITPD*.csv
local f2=`r(files)'
import delimited "`f2'",clear
erase `f2'

* Keep useful data + Standardize variable names
keeporder year exporter_iso3 importer_iso3 industry_id trade
ren (exporter_iso3 importer_iso3 industry_id) (iso3_o iso3_d itpd_id)
save "$builddir/04Temp/trade_byitpd.dta",replace

timer off 1


********************************************************************************
****					Compute regional trade aggregates	   				****
********************************************************************************

* Sum 2016 bilateral trade data by exporter-ITPD (broad) sector
keep if year==2016 & iso3_o!=iso3_d
collapse(sum)trade,by(year itpd_id iso3_o)
gen iso=iso3_o

* Match above w/ 3-letter country ISO codes
joinby iso using "$builddir/04Temp/iso_codes.dta"
keep if !mi(trade)&!mi(region)

* Compute total exports by sector & total for DMCs
egen sectrade_tot=sum(trade),by(itpd_id)
gen trade_dmc=trade*dmc
replace trade_dmc=0 if mi(trade_dmc)

* Compute total exports by region
levelsof region,local(region)
foreach x of local region { 
    gen trade_`x' = trade if region=="`x'"
	replace trade_`x'=0 if mi(trade_`x')
}

* Compute mean exports + total regional exports by sector (@Reizle > Is this correct? Please briefly explain why you are doing this)
collapse (mean)sectrade_tot (sum)trade_*,by(itpd_id)
save "$builddir/04Temp/agg_trade.dta",replace


********************************************************************************
****						Prepare Gravity Data						   	****
****			 	Source: Dynamic Gravity Dataset (USITC) 	        	****
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
****					Prepare Bilateral Tariff Data				   		****
****						Source: ITC MAcMap        		        		****
********************************************************************************
timer on 3

clear

* Unzip ITC tariff data (unzippinng files > 4GB requires Stata >= 15.1)
fs bulkdownload1.zip    
foreach f in `r(files)'{    
unzipfile "`f'",replace
}

* Delete useless files (*agr_tr.txt files contain description of the agreement codes in *agr.txt files)
fs *agr_tr.txt
foreach a in `r(files)'{
erase `a'
} 

* Generate temporary file
tempfile masterfile
save `masterfile',replace empty

*NOTE: Tempfile becomes really large, if you don't have enough space in your machine, you may need to redirect the tempfile default folder. 
*See FAQs https://www.stata.com/support/faqs/data-management/statatmp-environment-variable/


* Prepare each individual .csv reporting tariff data (Note: This bit takes several hours)
fs *agr.txt
foreach f in `r(files)'{

	* Import the .csv, keep relevant variables, rename them
	import delimited "`f'",clear
	rename (*) (v#) , addnumber
	keep v1-v8
	rename (v1 v2 v3 v4 v5 v6 v7 v8) (nomencode iso_d_num year hs6 tarlinect agr iso_o_num ave)

	* Compute applied bilateral rate = Min(preferential + MFN tariffs) per year-imp-exp-hs6
	collapse (min) ave_applied=ave,by(year iso_o_num iso_d_num  hs6)  

	* Convert HS 6-digit codes to string
	tostring hs6,gen(hs_str)
	replace hs_str="0"+hs_str if length(hs_str)==5

	* Merge tariff data w/ HS-to-ITPD concordance
	merge m:1 hs_str using hs_itpd_concord.dta,nogen keep(match)

	* Aggregate tariffs from ~5,300 6-digit HS codes to 153 ITPD sectors
	* Method: take the simple average of all the HS codes matched to a sinngle ITPD sector
	* > For alternative methods, see Documentation III.A (Internal document)- https://asiandevbank-my.sharepoint.com/personal/rplatitas_consultant_adb_org/Documents/ERMR_Trade%20Policy%20Analysis%20Tool/03Documentation/BUILDING%20A%20THEORY-CONSISTENT%20TRADE%20POLICY%20ANALYSIS%20TOOL.docx?web=1
	collapse (mean) tariff=ave_applied,by(year iso_o_num iso_d_num `itpd')
	
	* Convert tariff to %
	replace tariff=100*tariff
	ren `itpd' itpd_id

	* Convert ISO numeric to ISO 3-letter codes
	gen ctrycode=iso_o_num
	merge m:1 ctrycode using "$builddir/04Temp/iso_codes.dta",keepusing(iso) keep(match) nogen
	ren iso iso3_o
	replace ctrycode=iso_d_num
	merge m:1 ctrycode using "$builddir/04Temp/iso_codes.dta",keepusing(iso) keep(match) nogen
	ren iso iso3_d

	* Remove any duplicates if any
	duplicates drop year iso3_o iso3_d itpd_id,force
	

	* Add to the tariff data prepared in the previous iteration of the loop
	append using  `masterfile'
	save `masterfile', replace
	erase `f'   
}

* Keep only tariffs reported for HS codes successfully mapped to ITPD sectors
keep if !mi(itpd_id)
save "$builddir/04Temp/tariff_byitpd.dta",replace

timer off 3


********************************************************************************
****					Check the duration of each step				   		****
********************************************************************************

** The durations below are for Jules' MacBook Pro (4 Aug 2021 test) // Reizle's HuaweiMate D14 (7 Aug 2021 test)
timer list
* Timer 1 (Trade, ITPD) 		= 559 sec (9 min 30 sec)        // 916 sec (15 min 16 sec)
* Timer 2 (Gravity, USITC) 		= 23 sec                       //   29 sec
* Timer 3 (Tariffs, ITC MAcMap) = 43,296 sec (12 hours)        //   59487 (16 hours 30 mins)

