* R.Platitas, June 2021
* File first extrapolates missing domestic trade flows for base year, if data on earlier years are available. 
* Then, a square data with N exporters x N importers in each sector are built around the countries with domestic flows
* Written in Stata 15 on Windows 10


cd "$anlysdir/03Output"
local baseyr=2016


********************************************************************************
***	            Fill out missing domestic flows for base year  	       		****
********************************************************************************
use "$builddir/04Temp/trade_byitpd.dta",clear

gen domtrade=1 if iso3_o== iso3_d
replace domtrade=0 if mi(domtrade)

collapse (sum)trade,by(year itpd_id iso3_d domtrade)
reshape wide trade,i(year itpd_id iso3_d) j(domtrade)

ren (trade0 trade1) (trade_intl trade_dom)

*Compute growth rates of external and internal trade within each importer-sector
*Note:_A refers to actual data, _E refers to extrapolated/derived data
bysort itpd_id iso3_d (year): gen trade_intl_gr_A=100*((trade_intl/trade_intl[_n-1])-1)
bysort itpd_id iso3_d (year): gen trade_dom_gr_A=100*((trade_dom/trade_dom[_n-1])-1)

*Generate Internal trade growth rate to External trade growth rate ratio
gen int_to_ext_trade= trade_dom_gr_A/trade_intl_gr_A
replace int_to_ext_trade=0 if round(trade_intl_gr_A,.0000001)==0    // !!!gets rid of infinite values when denominator is zero!!!


*Obtain average of ratio to be applied to extrapolate missing values
egen avg_int_to_ext_trade=mean(int_to_ext_trade),by(itpd_id iso3_d)


*Identify last available domestic trade data per importer-sector, and which year

gen byte OK = !missing(trade_dom)
bysort itpd_id iso3_d (OK year): gen last_nmval = trade_dom[_N]
bysort itpd_id iso3_d (OK year): gen last_nmyr = year[_N]


*Derive domestic trade growth rates based on available international trade growth rates and computed average ratio earlier
*but only for years after the last available domestic trade data,otw used actual data
gen trade_dom_gr_E=avg_int_to_ext_trade*trade_intl_gr_A if year>=last_nmyr
replace trade_dom_gr_E= 0 if mi(trade_dom_gr_E)


*Derive internal flows
bysort itpd_id iso3_d (year): gen cmltv_dom_trade_gr=exp(sum(ln(1+trade_dom_gr_E/100)))
gen trade_dom_E=last_nmval*cmltv_dom_trade_gr

save "$anlysdir/04Temp/dom_trade_check.dta",replace     //  save for vetting extrapolated results


*Fill out the missing flows with extrapolated values, otherwise keep actual observations
gen trade_dom_final=trade_dom
replace trade_dom_final=trade_dom_E if year>last_nmyr        

keep if year==`baseyr' &itpd_id<154 
gen iso3_o=iso3_d

xtable itpd_id,c(n trade_dom n trade_dom_final) row filename(domtrade.xlsx)

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
	mvencode _all,mv(0)
	reshape long trade,i(year itpd_id iso3_d ) j( iso3_o ) str
	ren trade trade_sq
	
	append using `all_sec'
	save `all_sec',replace
}



save "$anlysdir/04Temp/Temp_SqrdData.dta",replace




////////////////////////////////////////////////////////////////////////////////
***	                GRAPHS-Plot domestic flows improvement   	       		****
////////////////////////////////////////////////////////////////////////////////

import excel "D:\07 Trade Policy Analysis tool\02Analysis\03Output\domtrade.xlsx", sheet("Sheet1") clear

ren (A B C) (itpd_id actual_fl drvd_fl)
labvars itpd_id actual_fl drvd_fl "ITPD sector" "Actual flows" "Extrapolated flows"

keep if length(itpd_id)<=3&length(actual_fl)!=0
destring,replace

gen domflow=0 if actual_fl==0&drvd_fl==0	
replace actual_fl=. if domflow==0
replace drvd_fl=. if domflow==0

gen broadsec="Agriculture" if itpd_id<=26
replace broadsec="Mining&Energy" if itpd_id>=27&itpd_id<=33
replace broadsec="Manufacturing 1" if itpd_id>=34&itpd_id<=60
replace broadsec="Manufacturing 2" if itpd_id>=61&itpd_id<=90
replace broadsec="Manufacturing 3" if itpd_id>=91&itpd_id<=120
replace broadsec="Manufacturing 4" if itpd_id>=121&itpd_id<=153


levelsof broadsec,local(bs)

foreach s in `bs'{
graph dot actual_fl drvd_fl domflow if broadsec=="`s'" ,over(itpd_id,label(labsize(small))) ytitle("no.of countries") ///
marker(1, msize(small) mcolor(blue)) marker(2, msize(small) mcolor(green)) marker(3, msize(small) mcolor(red) msymbol(x)) title("`s'") ///
legend(label(1 "Actual flows") label(2 "Extrapolated flows") label(3 "No domestic flows"))

graph export "$anlysdir/03Output/DomesticFlows_`s'.png",replace
}
													


////////////////////////////////////////////////////////////////////////////////
***	                GRAPHS-Fit of extrapolated domestic flows  	       		****
////////////////////////////////////////////////////////////////////////////////


use year iso3_d itpd_id trade_dom trade_dom_E if !mi( trade_dom)&year==2016&itpd_id<=153 using "$anlysdir/04Temp/dom_trade_check.dta",clear  
levelsof itpd_id,local(sec)

foreach s in `sec'{

	use year iso3_d itpd_id trade_dom trade_dom_E if itpd_id==`s'&!mi( trade_dom)&year==2016 using "$anlysdir/04Temp/dom_trade_check.dta",clear  
	gen diff=abs(trade_dom-trade_dom_E)
	gen ctry_lab=iso3_d if diff>100      // identify countries w/ large discrepancies ~$1Bn
	
	merge m:1 itpd_id using "$anlysdir/01Input/itpd_desc",keep(match) nogen
	local secname=sector[1] 
	labvars trade_dom_E trade_dom "predicted domestic trade(USD Mn)" "actual domestic trade (USD Mn)" 

	twoway scatter trade_dom_E trade_dom ,mlab(ctry_lab) || line trade_dom_E trade_dom_E,legend(off) title("`secname'") ytitle() xtitle("actual domestic trade (USD Mn)" )
	graph export "$anlysdir/03Output/check_domtrade_`s'.png",replace

}

