

////////////////////////////////////////////////////////////////////////////////
****			    PE impact on US and PRC-All sectors    	             	****
////////////////////////////////////////////////////////////////////////////////

use iso3_o itpd_id trade_bline PEimp_lvl* if (inlist(iso3_o,"AUS","BRN","KHM","CHN","IDN","JPN","LAO","MYS","MMR")|inlist(iso3_o,"NZL","PHL","KOR","SGP","THA","VNM"))&(!mi(PEimp_lvl_GC)|!mi(PEimp_lvl_GC2)|!mi(PEimp_lvl_FE))&itpd_id<=153 using  "$anlysdir/04Temp/PEimpact_byexpsec",clear



merge m:1 itpd_id using "$builddir/04Temp/broadsec_agg.dta",keep(match) nogen
collapse (sum) trade_bline* PEimp_lvl* ,by(adbmriot_sec adbmriot_seccode iso3_o )


replace trade_bline=trade_bline/1000                    //express in USD Bln

local model GC GC2 FE
foreach m in `model'{
	replace PEimp_lvl_`m'=PEimp_lvl_`m'/1000            //express in USD Bln
	gen PEimp_pct_`m'=100*(PEimp_lvl_`m'/trade_bline)	
}



*****Broadsec level

local lvl_title ytitle("Impact on exports (USD Bn)",size(small)) 
local pct_title ytitle("Impact on exports (%)",size(small)) 

levelsof adbmriot_sec,local(sec)
local unit lvl pct
local model GC GC2 FE

foreach u in `unit'{
foreach m in `model'{
foreach s in `sec'{

graph hbar PEimp_`u'_`m' if  adbmriot_sec=="`s'"  ,over(iso3_o) title( "`s'" ,size(small)) asyvars ``u'_title'  blabel(bar, format(%12.2fc) gap(*.5) size(vsmall))
graph export "$anlysdir/03Output/PEimp_`u'_`m'_`s'.png",as(png) replace

}
}
}

/*

For Use case #1-US-PRC trade war

*use iso3_o itpd_id trade_bline PEimp_lvl* if (iso3_o=="CHN"|iso3_o=="USA")&(!mi(PEimp_lvl_GC)|!mi(PEimp_lvl_GC2)|!mi(PEimp_lvl_FE))&itpd_id<=153 using  "$anlysdir/04Temp/PEimpact_byexpsec",clear

local lvl_title ytitle("Impact on exports (USD Bn)",size(small)) 
local pct_title ytitle("Impact on exports (%)",size(small)) 

local unit lvl pct
local model GC GC2 FE


foreach u in `unit'{
foreach m in `model'{

graph hbar PEimp_`u'_`m',over(iso3_o) by(adbmriot_sec) asyvars ``u'_title'  blabel(bar, format(%12.1fc) gap(*.5) size(vsmall))

*graph hbar PEimp_`u'_`m',over(iso3_o) over( adbmriot_sec ,label(labsize(vsmall))) asyvars ``u'_title'  blabel(bar, format(%12.1fc) gap(*.5) size(vsmall))
graph export "$anlysdir/03Output/PEimp_`u'_`m'.png",as(png) replace

}
}
*/



////////////////////////////////////////////////////////////////////////////////
****				           GE effects by sector     		           	****
////////////////////////////////////////////////////////////////////////////////
use "$anlysdir/03Output/CFL_results",clear

collapse (mean)d_welfare_GC2,by( iso3_o itpd_id)
gen d_welfare_clean= d_welfare_GC2
replace d_welfare_clean=round( d_welfare_clean,.0000001)

gen xpos=-abs( d_welfare_clean)

replace xpos=-1001 if iso3_o=="CHN"       // fixing CHN and USA in the first two bars
replace xpos=-1000 if iso3_o=="USA"

bysort itpd_id : egen ranku = rank(xpos), unique

save "$anlysdir/03Output/GE_CFL_results",replace

levelsof itpd_id,local(validsec)

foreach s in `validsec'{
	use if itpd_id==`s'&ranku<=10 using "$anlysdir/03Output/GE_CFL_results",clear
	merge m:1 itpd_id using "$anlysdir/01Input/itpd_desc",keep(match) nogen
	local secname=sector[1] 
	labmask ranku,values(iso3_o)
	levelsof ranku, local(var2values)

	twoway bar d_welfare_clean ranku, xtitle("economies w/ most impact") ytitle("% change in welfare") xlabel(`var2values', valuelabels) title("`secname'")
	graph export "$anlysdir/03Output/GEimpact_`s'.png",as(png) replace
}



