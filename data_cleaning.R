#Final Project

#Packages
library(tidyverse)
library(tigris)
library(stringr)

#Reading in data
corn_yield<-read_csv("corn_yield.csv")
corn_yield$state_code<-corn_yield$State
corn_yield$County<-str_replace(corn_yield$County,"St ","St.")

air_quality<-read_csv("corn_counties_aq.csv")
air_quality<-air_quality%>%
             mutate(state_code=State)
x<-air_quality$state_code
state_abbreviations<-state.abb[match(x,state.name)]
air_quality$state_code<-c(state_abbreviations)
air_quality$County<-str_replace(air_quality$County,"Saint","St.")

drought<-read_csv("drought_means.csv")
drought<-drought[-c(1)]
county_names<-str_remove(drought$County,"County")
county_names<-str_remove(drought$County,"Parish")
drought$County<-c(county_names)
drought$County<-str_replace(drought$County,"Saint","St.")
drought$state_county<-trimws(drought$state_county)


#New Column With State + County
##air_quality
air_quality$state_county<-paste(air_quality$state_code,air_quality$County,sep=",")
corn_yield$state_county<-paste(corn_yield$state_code,corn_yield$County,sep=",")
drought$state_county<-paste(drought$State,drought$County,sep=",")

#Cleaning data and joining data frames
corn_harvested<-corn_yield[-c(3,4)]
air_and_corn<-left_join(air_quality,corn_harvested,by="state_county")
air_and_corn<-air_and_corn[-c(3,4,11:19,21,22,24)]
air_and_corn<-air_and_corn%>%
              rename("State"="State.x",
                     "County"="County.x",
                     "Quantity_Harvested"="Quantity Harvested")%>%
             relocate(state_county,.after=County)%>%
             relocate(Quantity_Harvested,.after=state_county)
#Some had corn data for fields harvested, but did not have an associated quantity
air_and_corn<-na.omit(air_and_corn)

#Having trouble joining drought data with air and corn
air_corn_drought<-left_join(air_and_corn,drought,by="state_county")
air_corn_drought<-air_corn_drought[,-c(11:16,26:30)]
air_corn_drought<-air_corn_drought[,-c(11:15,17:18)]


#FIPS Code
FIPS_CODES<-data("fips_codes")
fips_codes$state_county<-paste(fips_codes$state,fips_codes$county,sep=",")
fips_codes$code<-paste(fips_codes$state_code,fips_codes$county_code)
fips_codes$state_county<-str_remove(fips_codes$state_county,"County")
fips_codes$state_county<-trimws(fips_codes$state_county)
air_and_corn<-left_join(air_and_corn,fips_codes,by="state_county")

#County geographies
counties<-counties()
counties$code<-paste(counties$STATEFP,counties$COUNTYFP)

#Joining
air_corn_drought<-left_join(air_corn_drought,counties,by="code.y")
air_corn_drought<-air_corn_drought[,-c(13:29)]
air_corn_drought<-air_corn_drought[,-c(11)]

