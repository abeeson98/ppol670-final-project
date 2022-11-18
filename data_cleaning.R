#Final Project

#Packages
library(tidyverse)
library(stringr)

#Reading in data
corn_yield<-read_csv("corn_yield.csv")
corn_yield$state_code<-corn_yield$State

air_quality<-read_csv("corn_counties_aq.csv")
air_quality<-air_quality%>%
             mutate(state_code=State)
x<-air_quality$state_code
state_abbreviations<-state.abb[match(x,state.name)]
air_quality$state_code<-c(state_abbreviations)


drought<-read_csv("drought_means.csv")
drought<-drought[-c(1)]
county_names<-str_remove(drought$County,"County")
drought$County<-c(county_names)


#New Column With State + County
##air_quality
air_quality$state_county<-paste(air_quality$state_code,air_quality$County,sep=",")
corn_yield$state_county<-paste(corn_yield$state_code,corn_yield$County,sep=",")
drought$state_county<-paste(drought$State,drought$County,sep=",")

#Cleaning data
corn_harvested<-corn_yield[-c(3,4)]
air_and_corn<-left_join(air_quality,corn_harvested,by="state_county")
                        

