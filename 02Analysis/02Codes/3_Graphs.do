
////////////////////////////////////////////////////////////////////////////////
****			    PE impact on US and PRC-All sectors    	             	****
////////////////////////////////////////////////////////////////////////////////

*Load results for USA-PRC pairs only  
use if (iso3_o=="CHN"&iso3_d=="USA")|(iso3_o=="USA"&iso3_d=="CHN") using "$anlysdir/03Output/CFL_results",clear
keeporder iso3_o itpd_id d_trade_PEeffect_GC 

reshape wide d_trade_PEeffect_GC,i(itpd_id) j(iso3_o) string
ren (d_trade_PEeffect_GCCHN d_trade_PEeffect_GCUSA) (PE_effect_CHN PE_effect_USA) 

replace PE_effect_USA= -PE_effect_USA         //to create mirror bars

labvars itpd_id PE_effect_CHN PE_effect_USA "ITPD sector" "Impact on PRC exports" "Impact on USA exports"
twoway bar PE_effect_CHN itpd_id, horizontal xtitle("% change in exports") || bar PE_effect_USA itpd_id, horizontal legend(size(*0.75))

graph export "$anlysdir/03Output/PEimpact.png",replace


////////////////////////////////////////////////////////////////////////////////
****				           GE effects by sector     		           	****
////////////////////////////////////////////////////////////////////////////////
use "$anlysdir/03Output/CFL_results_`currdate'",clear

collapse (mean)d_welfare_GC,by( iso3_o itpd_id)
gen d_welfare_clean= d_welfare_GC
replace d_welfare_clean=round( d_welfare_clean,.00001)

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
	graph export "$anlysdir/03Output/GEimpact_`s'.png",replace
}



