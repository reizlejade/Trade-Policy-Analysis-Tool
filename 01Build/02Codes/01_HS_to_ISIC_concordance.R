# Install concordance_2.1.0 manually (get files to paste manually in the local R library folder)

# Also attempted, but failed
#install.packages("devtools")
#library(devtools)
#install_github("insongkim/concordance", dependencies=TRUE)
#install.packages("concordance") # This installs concordance_2.0.0

#install.packages("dplyr")
#install.packages("concordance")
#install.packages("foreign")
#install.packages("haven")

library(dplyr)
library(concordance)
library(foreign)
library(haven)

rm(list=ls())

#Set directory according to user
uname<-Sys.info()[["user"]]

if (uname=='rjcpl'){
  dataOutputDir1<-"D:/07 Trade Policy Analysis tool/01Build/04Temp/"
}  else {
  dataOutputDir1<-"/Users/h83/Desktop/Asian Development Bank/Reizle Jade C. Platitas - ERMR_Trade Policy Analysis Tool/01Build/04Temp/"
}

setwd(dataOutputDir1)


#Produce concordance of HS versions
hs_ver<-list(hs5_hs4,hs4_hs3,hs3_hs2,hs2_hs1,hs1_hs0)

for (i in 1:5){
  nam<-paste("mat",i,sep="_")
  assign(nam,data.frame(hs_ver[i]))
}


hs_allver<-full_join(mat_1,mat_2,by='HS4_6d')
hs_allver<-full_join(hs_allver,mat_3,by='HS3_6d')
hs_allver<-full_join(hs_allver,mat_4,by='HS2_6d')
hs_allver<-full_join(hs_allver,mat_5,by='HS1_6d')

hs_convrtr<-hs_allver%>%select(contains("6d"))
hs_convrtr<-hs_convrtr%>%rename(
  hs2017=HS5_6d,
  hs2012=HS4_6d,
  hs2007=HS3_6d,
  hs2002=HS2_6d,
  hs1996=HS1_6d,
  hs1992=HS0_6d
  )

#Get concordance from HS to ISIC (direct)
hs_isic<-list(hs_isic2,hs_isic3,hs_isic31,hs_isic4)

for (i in 1:4){
  namISIC<-paste("matISIC",i,sep="_")
  assign(namISIC,data.frame(hs_isic[i]))
}

hs_isic<-full_join(matISIC_1,matISIC_2,by='HS_6d')
hs_isic<-full_join(hs_isic,matISIC_3,by='HS_6d')
hs_isic<-full_join(hs_isic,matISIC_4,by='HS_6d')

hs_isicf<-hs_isic%>%select("HS_6d",contains("ISIC")&contains("4d"))
hs_isicf<-hs_isicf%>%rename(
  hs_str=HS_6d,
  isic2=ISIC2_4d,
  isic3=ISIC3_4d,
  isic31=ISIC3.1_4d,
  isic4=ISIC4_4d
)
hs_isicf<-hs_isicf %>% distinct(hs_str,isic3, .keep_all = TRUE)


#Get concordance from HS to ISIC (via SITC)

isic_sitc<-full_join(isic3_isic2,sitc2_isic2,by='ISIC2_4d')
isic_hs<-full_join(isic_sitc,hs_sitc2,by='SITC2_5d')
hs_isicf2<-isic_hs%>%select("HS_6d",contains("ISIC")&contains("4d"))
hs_isicf2<-hs_isicf2%>%rename(
  hs_str=HS_6d,
  isic2=ISIC2_4d,
  isic3=ISIC3_4d,
)

hs_isicf2<-hs_isicf2%>%filter(!is.na(isic3))
hs_isicf2<-hs_isicf2 %>% distinct(hs_str,isic3, .keep_all = TRUE)

#Get Hs descriptions, all levels and all versions
hsdesc=hs_desc
isicver=isic4_isic3

#Outputs to be used by Stata
write_dta(hsdesc,"hs_desc.dta")
write_dta(hs_convrtr,"hs_convrtr.dta")
write_dta(hs_isicf,"hs_isic.dta")
write_dta(hs_isicf2,"hs_isic2.dta")
write_dta(isicver,"isic4_isic3.dta")



