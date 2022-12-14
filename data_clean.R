---
  title: "Final Project"
format: html
editor: visual
editor_options: 
  chunk_output_type: console
execute: 
  warning: false
self-contained: true
---
###Loading in packages
  
#Packages
library(tidyverse)
library(stringr)
library(readr)
library(tigris)
library(tidymodels)
library(yardstick)
library(tidycensus)


###Reading in data

#fips codes data
data("fips_codes")

#yield data
corn_yield<-read_csv("corn_yield.csv")
corn_yield$state_code<-corn_yield$State 
corn_yield$County<-str_replace(corn_yield$County,"St ","St.") 
corn_yield$state_county<-paste(corn_yield$state_code,corn_yield$County,sep=",")
corn_harvested<-corn_yield[-c(3,4)]

#air quality data
air_quality<-read_csv("corn_counties_aq.csv")
air_quality<-air_quality%>%
  mutate(state_code=State) 
x<-air_quality$state_code
state_abbreviations<-state.abb[match(x,state.name)]
air_quality$state_code<-c(state_abbreviations)
air_quality$County<-str_replace(air_quality$County,"Saint","St.") 
air_quality$state_county<-paste(air_quality$state_code,air_quality$County,sep=",")
#air_quality$state_county<-trimws(air_quality$state_county)

#drought data 2017
drought<-read_csv("drought_means.csv")
drought<-drought[-c(1)]
county_names<-str_remove(drought$County,"County")
drought$County <-str_remove(drought$County, "County")
county_names<-str_remove(drought$County,"Parish")
drought$County<-c(county_names)
drought$County<-str_replace(drought$County,"Saint","St.")
#adding state + county
drought$state_county<-paste(drought$State,drought$County,sep=",")
drought$state_county<-trimws(drought$state_county)

#drought data 2016
drought_2016 <- read.csv("dm_export_20160101_20161231.csv")

drought_2016_average <- drought_2016 %>%
  group_by(State, County) %>%
  summarise(mean(DSCI)) %>%
  rename(meanDSCI2016 = "mean(DSCI)")

county_names<-str_remove(drought_2016_average$County,"County")
drought_2016_average$County <-str_remove(drought_2016_average$County, "County")
county_names<-str_remove(drought_2016_average$County,"Parish")
drought_2016_average$County <-str_remove(drought_2016_average$County, "Parish")
county_names<-str_remove(drought_2016_average$County,"Borough")
drought_2016_average$County <-str_remove(drought_2016_average$County, "Borough")
county_names<-str_remove(drought_2016_average$County,"Census Area")
drought_2016_average$County <-str_remove(drought_2016_average$County, "Census Area")
#adding state + county
drought_2016_average$state_county<-paste(drought_2016_average$State,drought_2016_average$County,sep=",")
drought_2016_average$state_county<-trimws(drought_2016_average$state_county)

###Joining model data together

#Joinig data 

air_and_corn<-left_join(air_quality,corn_harvested,by="state_county")
air_and_corn<-air_and_corn%>%
  rename("State"="State.x",
         "County"="County.x",
         "Quantity_Harvested"="Quantity Harvested")%>%
  relocate(state_county,.after=County)%>%
  relocate(Quantity_Harvested,.after=state_county)
#Some had corn data for fields harvested, but did not have an associated quantity
air_and_corn<-na.omit(air_and_corn)

#Joining drought data with air and corn
air_corn_drought<-left_join(air_and_corn,drought,by="state_county") 
air_corn_drought <- left_join(air_corn_drought,drought_2016_average,by="state_county")

#Cleaning up results of join
air_corn_drought <- air_corn_drought %>%
  select(-c("County.y.y", "State.y.y", "state_code.y","County.y","State.y","state_code.x"))%>%
  rename(state=State.x)%>%
  rename(county=County.x)%>%
  filter(!is.na(meanDSCI2016)) %>%
  mutate(log_quantityharvested = log(Quantity_Harvested, base = 10))


### Joining geographic data

#FIPS Code
FIPS_CODES<-data("fips_codes")
fips_codes$state_county<-paste(fips_codes$state,fips_codes$county,sep=",")
fips_codes$code<-paste(fips_codes$state_code,fips_codes$county_code)
fips_codes$state_county<-str_remove(fips_codes$state_county,"County")
fips_codes$state_county<-trimws(fips_codes$state_county)

#County geographies
counties<-counties()
counties$code<-paste(counties$STATEFP,counties$COUNTYFP)

#Joining
air_corn_drought_gps<-left_join(air_corn_drought,fips_codes,by="state_county") #merging in fips codes
air_corn_drought_gps<-left_join(air_corn_drought_gps,counties,by="code") #merging in geometries

#Cleaning up results of join
air_corn_drought_gps <- air_corn_drought_gps %>%
  select(-c("NAMELSAD", "NAME", "county.y", "COUNTYFP", "STATEFP", "state_name", "state.y"))%>%
  rename(state = state.x)%>%
  rename(county = county.x)%>%
  relocate(c("state", "county", "state_county", "state_code", "county_code", "code"))

#adding drought categories
air_corn_drought_gps <- air_corn_drought_gps %>%
  mutate(drought_category = case_when(
    meanDSCI <= 99 ~ "None",
    meanDSCI >=100 & meanDSCI <= 199 ~ "D0",
    meanDSCI >=200 & meanDSCI <= 299 ~ "D1",
    meanDSCI >=300 & meanDSCI <= 399 ~ "D2",
    meanDSCI >=400 & meanDSCI <= 499 ~ "D3",
    meanDSCI == 500 ~ "D4"))

### Exploratory Data Visualizations

#top 10 corn producing states 
corn_plot <- air_corn_drought_gps %>%
  group_by(state) %>%
  summarize(corn_total = sum(Quantity_Harvested))%>%
  arrange(desc(corn_total)) %>%
  slice(1:10)

my_factor_levels <- c("Iowa", "Illinois", "Indiana", "Minnesota", "Ohio","Wisconsin","Michigan","Nebraska","South Dakota","Pennsylvania")

corn_plot$state <- factor(corn_plot$state, levels = my_factor_levels)

corn_plot%>%
  ggplot() +
  geom_col(mapping = aes(x = state, y = corn_total), fill = "#6A8C69", width = .7) +
  theme_minimal() +
  scale_y_continuous(labels = scales::number_format(accuracy = 1000000))+
  labs(
    title = "What are the top 10 corn producing states in our sample?",
    subtitle = "Plot shows corn production quantities for the year 2017 in bushels for the top 10 corn producing states in our sample.",
    y = "Bushels of Corn Produced",
    x = NULL
  )+
  theme(plot.title = element_text(face="bold"))


#histogram of drought dispersion within states

air_corn_drought_gps$drought_category <- factor(air_corn_drought_gps$drought_category, levels = c("None", "D0", "D1", "D2", "D3", "D4"))

air_corn_drought_gps %>%
  ggplot()+
  geom_histogram(aes(x = meanDSCI, fill = drought_category), binwidth = 5) +
  geom_vline(xintercept = 100, size = .2)+
  facet_wrap(~state) +
  scale_fill_manual(values = c("#5B8A07", "#FFCB00", "#D65B00"), name = "Drought Category",
                    labels = c("No Drought", "Moderate Drought (D1)", "Severe Drought (D2)"))+
  theme_minimal() +
  labs(title = "What is the frequency of drought within our sample?",
       subtitle = "Plot shows the average score of drought severity for counties within each state of our sample for the year 2017. Drought categories are derived from Drought Severity\n and Coverage Index by the University of Nebraska Lincoln.",
       y = "Mean Drought Severity and Coverage Index",
       x = NULL) +
  theme(plot.title = element_text(face="bold")) 


### Modeling

set.seed(835555635)

split <- initial_split(air_corn_drought, prop = .75, strata = "log_quantityharvested")
corn_train <- training(split)
corn_test <- testing(split)

corn_recipe <- recipe(log_quantityharvested ~., data = corn_train)%>%
  step_rm(all_nominal_predictors())%>%
  step_rm("Year")%>%
  step_rm("Quantity_Harvested")%>%
  #step_log(all_outcomes(), base = 10) %>%
  step_normalize(all_numeric_predictors())%>%
  prep()

corn_baked <- bake(corn_recipe, new_data = corn_train)

set.seed(923809584)

folds <- vfold_cv(corn_train, v=10)

forest_model <- rand_forest()%>%
  set_engine("ranger", importance = "impurity")%>%
  set_mode("regression")

lasso_grid <- grid_regular(penalty(), levels = 10)

lasso_model <- linear_reg(penalty = tune(), mixture = 1)%>%
  set_engine("glmnet")%>%
  set_mode("regression")

corn_forest_wkflw <- workflow()%>%
  add_recipe(corn_recipe)%>%
  add_model(forest_model)

corn_lasso_wkflw <- workflow()%>%
  add_recipe(corn_recipe)%>%
  add_model(lasso_model)

corn_forest_fit <- corn_forest_wkflw %>%
  fit_resamples(
    resamples=folds)

corn_lasso_fit <- corn_lasso_wkflw %>%
  tune_grid(resamples = folds, 
            grid = lasso_grid)

lasso_metrics <- collect_metrics(corn_lasso_fit, summarize = FALSE) %>%
  filter(.metric == "rmse")%>%
  group_by(id) %>%
  summarize(rmse = mean(.estimate))

forest_metrics <- collect_metrics(corn_forest_fit, summarize = FALSE)%>%
  filter(.metric == "rmse")%>%
  rename(rmse = .estimate)

combined_metrics <- bind_rows(
  `lasso` = lasso_metrics, 
  `rforest` = forest_metrics, 
  .id = "models") %>%
  select(-c(".metric", ".estimator", ".config"))

combined_metrics%>%
  ggplot(aes(x=id, y = rmse, group = models, color = models)) +
  geom_point()+
  geom_line()+
  theme_minimal()+
  #scale_y_continuous(limits = c(0, 2))+
  labs(title = "RMSE for different estimated models",
       x=NULL)

final_model <- corn_forest_fit %>%
  select_best(metric = "rmse")

final_workflow <- finalize_workflow(corn_forest_wkflw,
                                    parameters=final_model)

corn_final_fit<-final_workflow%>%
  fit(data=corn_train)

#Predicting on testing data
corn_predictions_testing<-bind_cols(corn_test,
                                    predict(object=corn_final_fit,
                                            new_data=corn_test))


metrics(corn_predictions_testing, truth = log_quantityharvested, estimate = .pred)

--------------------------------------------------------------------------------
#Visualizations
  
#Visualization 1: Corn in the U.S.
library(usmap)
corn_fips_codes<-air_corn_drought_gps%>%
                 select("code","Quantity_Harvested")%>%
                 rename(fips=code)

#removed white spaces
new_fips<-str_replace_all(corn_fips_codes$fips, " ","")
corn_fips_codes<-corn_fips_codes%>%bind_cols(corn_fips_codes,new_fips)%>%
                 select(c(4,5))

corn_fips_codes$harvested<-corn_fips_codes$Quantity_Harvested...4
corn_fips_codes$fips<-corn_fips_codes$...5
corn_fips_codes<-corn_fips_codes%>%select(c(3,4))

#Decent map
corn_map<-
  plot_usmap(regions = "counties",
           data = corn_fips_codes, 
           values = "harvested", 
           color = "#0E4436",
           size=0.001) + 
  scale_fill_gradient(low="#ECFFE8",
                    high="#1C876B",
                    na.value="white",
  name = "Corn Harvested (2017)",
  label = scales::comma)+ 
  labs(title="Corn Harvested in the United States (2017)")+
  theme(legend.position = "right",
        panel.background=element_rect(colour = "#0E4436", fill = "#0E4436"))
corn_map

#Visualization 2: Bad air quality for corn producing counties

##Making Data Usuable
bad_aq_fips_codes<-air_corn_drought_gps%>%
  select("code","Unhealthy Days")%>%
  rename(fips=code)

bad_aq_fips_codes<-bad_aq_fips_codes%>%bind_cols(bad_aq_fips_codes,new_fips)%>%
  select(c(4,5))

bad_aq_fips_codes$bad_days<-bad_aq_fips_codes$'Unhealthy Days...4'
bad_aq_fips_codes$fips<-bad_aq_fips_codes$...5
bad_aq_fips_codes<-bad_aq_fips_codes%>%select(c(3,4))

#Map
bad_aq_map<-
  plot_usmap(regions = "counties",
             data = bad_aq_fips_codes, 
             values = "bad_days", 
             color = "#00233D",
             size=0.001) + 
  scale_fill_gradient2(low="#97BDE2",
                       high="#0859A9",
                       na.value="white",
                       name = "Days w/ bad air quality (2017)",
                       label = scales::comma)+ 
  labs(title="Bad AQ days in the United States (2017)")+
  theme(legend.position = "right",
        panel.background=element_rect(colour = "#00233D", fill = "#00233D"))
bad_aq_map

#Visualization 3: Highest Drought Levels in the United States (2017)

#Making data usuable
drought_fips_codes<-air_corn_drought_gps%>%
  select("code","meanDSCI")%>%
  rename(fips=code)

drought_fips_codes<-drought_fips_codes%>%bind_cols(drought_fips_codes,new_fips)%>%
  select(c(4,5))

drought_fips_codes$drought_levels<-drought_fips_codes$meanDSCI...4
drought_fips_codes$fips<-drought_fips_codes$...5
drought_fips_codes<-drought_fips_codes%>%select(c(3,4))

#Map
drought_map<-
  plot_usmap(regions = "counties",
             data = drought_fips_codes, 
             values = "drought_levels", 
             color = "#520B00",
             size=0.001) + 
  scale_fill_gradient2(low=muted("#CA2E16"),
                       high="#CA2E16",
                       na.value="white",
                       name = "Mean drought index (2017)",
                       label = scales::comma)+ 
  labs(title="Mean drought index in the United States (2017)")+
  theme(legend.position = "right",
        panel.background=element_rect(colour = "#520B00", fill = "#520B00"))
drought_map
