* R.Platitas, June 2021
* File first extrapolates missing domestic trade flows for base year, if data on earlier years are available. 
* Then, a square data with N exporters x N importers in each sector are built around the countries with domestic flows
* Written in Stata 15 on Windows 10


********************************************************************************
***	            Extrapolating domestic flows for base year  	       		****
********************************************************************************

*Extrapolation Methods
*A.Naive method (*_cf)- carry forward last obs
*B.Linear regression (*_ols)- Linear regression of domestic trade on international trade with time trend (per country-sector)
*C.Weighted average method (*_wtdavg)-Take the mean of observed values with greater weights given to newer observations
*D1.Assume that gross output grows at the same rate as exports, derive the domestic trade as gross_output (extrapolated) - exports 
*D2.Assume that the ratio of exports growth to domestic trade growth is constant                      


cd "$anlysdir/03Output"
local baseyr=2016

use if itpd_id<=153 using "$builddir/04Temp/trade_byitpd.dta",clear

gen domtrade=1 if iso3_o== iso3_d
replace domtrade=0 if mi(domtrade)

collapse (sum)trade,by(year itpd_id iso3_d domtrade)
reshape wide trade,i(year itpd_id iso3_d) j(domtrade)

ren (trade0 trade1) (trade_intl trade_dom)


gen broadsec="Agriculture" if itpd_id<=26
replace broadsec="Mining&Energy" if itpd_id>=27&itpd_id<=33
replace broadsec="Manufacturing" if itpd_id>=34

***** Simple methods*********

*A. Naive method i.e.carry forward last obs 

*1. Locate the last obs 
*Identify last available domestic trade data per importer-sector, and which year

gen byte OK_dom = !missing(trade_dom)

bysort itpd_id iso3_d (OK_dom year): gen trade_dom_lastnmval = trade_dom[_N]
bysort itpd_id iso3_d (OK_dom year): gen trade_dom_lastnmyr = year[_N]

bysort itpd_id iso3_d (year): carryforward trade_dom,gen(pred_trade_dom_cf)


*B. Linear regression of domestic trade on international trade with time trend (per country-sector)

egen expsecid=concat(iso3_d itpd_id)
levelsof expsecid,local(expsec)

gen pred_trade_dom_ols=.
	foreach x in `expsec'{
	cap reg trade_dom trade_intl year if expsecid=="`x'"
	cap predict trade_dom_pred
	cap replace pred_trade_dom_ols=trade_dom_pred if expsecid=="`x'"
	cap drop trade_dom_pred
}

replace pred_trade_dom_ols=0 if pred_trade_dom_ols<0

*C. Average method i.e. use the mean of historical obs available
*Put greater weight on later values

gen yr_wt= 1/(2017-year)
bysort itpd_id iso3_d (year):asgen pred_trade_dom_wtdavg=trade_dom,w(yr_wt)   


*To test how this perform in countries with full set of data, we carry forward the value from 2013 (choice of year is determined by the coverage in the data)

gen check_trade_dom_cf=trade_dom[_n-3] if trade_dom_lastnmyr==2016&!mi(trade_dom)&year==2016
gen check_trade_dom_ols=pred_trade_dom_ols if trade_dom_lastnmyr==2016&!mi(trade_dom)&year==2016
gen check_trade_dom_wtdavg=pred_trade_dom_wtdavg if trade_dom_lastnmyr==2016&!mi(trade_dom)&year==2016


foreach m in cf ols wtdavg{
	gen resid_`m'= trade_dom-check_trade_dom_`m'
}




***** Using growth rates*********

*Method D1- Assume that gross output grows at the same rate as exports, derive the domestic trade as gross_output (extrapolated) - exports *

*1. Approximate gross output as sum of intl and domestic trade
gen output=trade_intl+trade_dom

*2. Compute growth rates of exports within each exporter-sector
*bysort itpd_id iso3_d (year): gen trade_intl_gr_A=100*((trade_intl/trade_intl[_n-1])-1)      //simple average
bysort itpd_id iso3_d (year): gen trade_intl_gr_A=100*((trade_intl/trade_intl[_n-1])-1)      //simple average


*3. Identify last available gross output data per importer-sector, and which year 
gen byte OK_output = !missing(output)
bysort itpd_id iso3_d (OK_output year): gen output_lastnmval = output[_N]
bysort itpd_id iso3_d (OK_output year): gen output_lastnmyr = year[_N]


*4.A. Derive gross output for years after the last available output data,otw used actual data
gen output_D1=output_lastnmval*(1+trade_intl_gr_A/100)
gen trade_dom_D1=output_D1-trade_intl
replace trade_dom_D1=0 if trade_dom_D1<0        //takes care of negative domestic trade


* Method D2- Assume that the ratio of exports growth to domestic trade growth is constant                      

*4.B. Derive domestic trade growth rates based on available international trade growth rates and computed average ratio earlier
*but only for years after the last available domestic trade data,otw used actual data

*Compute growth rates of domestic trade within each exporter-sector
bysort itpd_id iso3_d (year): gen trade_dom_gr_A=100*((trade_dom/trade_dom[_n-1])-1)

*Generate exports growth to domestic trade growth ratio
gen int_to_ext_trade= trade_dom_gr_A/trade_intl_gr_A
replace int_to_ext_trade=0 if round(trade_intl_gr_A,.0000001)==0    // !!!gets rid of infinite values when denominator is zero!!!

*Obtain average of ratio to be applied to extrapolate missing values
egen avg_int_to_ext_trade=mean(int_to_ext_trade),by(itpd_id iso3_d)

*Derive domestic trade growth rates based on available international trade growth rates and computed average ratio earlier
*Do only for years after the last available domestic trade data,otw used actual data
gen trade_dom_gr_D2=avg_int_to_ext_trade*trade_intl_gr_A if year>=output_lastnmyr
replace trade_dom_gr_D2= 0 if mi(trade_dom_gr_D2)


*Derive internal flows
bysort itpd_id iso3_d (year): gen cmltv_dom_trade_gr=exp(sum(ln(1+trade_dom_gr_D2/100)))    //
gen trade_dom_D2=trade_dom_lastnmval*cmltv_dom_trade_gr

foreach m in D1 D2{
	gen check_trade_dom_`m'=trade_dom_`m' if trade_dom_lastnmyr==2016&!mi(trade_dom)&year==2016
	gen resid_trade_dom_`m'=trade_dom-check_trade_dom_`m'
}


save "$anlysdir/04Temp/dom_trade_extrapolate.dta",replace



********************************************************************************
***	            Fill out missing domestic flows for base year  	       		****
********************************************************************************
use "$anlysdir/04Temp/dom_trade_extrapolate.dta",clear
local baseyr=2016
gen trade_dom_final=trade_dom
replace trade_dom_final=pred_trade_dom_wtdavg if year>trade_dom_lastnmyr        

keep if year==`baseyr' &itpd_id<154 
gen iso3_o=iso3_d

*xtable itpd_id,c(n trade_dom n trade_dom_final) row filename(domtrade.xlsx)

keeporder  year itpd_id iso3_d iso3_o trade_dom_final
ren trade_dom_final trade                         

keep if !mi(trade)
save "$anlysdir/04Temp/dom_trade.dta",replace


********************************************************************************
***	                       Squaring the Dataset  	       	               	****
********************************************************************************

clear
tempfile all_sec
save `all_sec',emptyok

*Begin with available domestic flows

forval i=1/153{
	if inlist(`i',5,8,14,15,17,18,154,155,161,167,168) continue     // sectors without intra-national trade for any given year
	use if itpd_id==`i' using "$anlysdir/04Temp/dom_trade.dta",clear    //load all non-missing domestic trade flows for the base year
	reshape wide trade,i(year itpd_id iso3_d ) j( iso3_o ) str
	cap mvencode _all,mv(0)
	reshape long trade,i(year itpd_id iso3_d ) j( iso3_o ) str
	ren trade trade_sq
	
	append using `all_sec'
	save `all_sec',replace
}


save "$anlysdir/04Temp/Temp_SqrdData.dta",replace




