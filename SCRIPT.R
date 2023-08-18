# Setup
library(dplyr)
library(readxl)
library(readr)
library(tidyr)
library(ggplot2)
library(assertthat)
library(broom)
library(stringr)

# we need only the African regions
african_regions <- c('Eastern_Africa', 'Western_Africa', 'Southern_Africa', 'Northern_Africa')



temperatures <- read_csv("temperatures.csv") 

View(temperatures)

ipcc_2006_africa<- read_excel("IEA_EDGAR_CO2_1970-2021.xlsx", sheet = "IPCC 2006", skip = 10) %>% 
                    filter(C_group_IM24_sh %in% african_regions)



totals_by_country_africa <- read_excel("IEA_EDGAR_CO2_1970-2021.xlsx", sheet = "TOTALS BY COUNTRY", skip = 10) %>%
                              filter(C_group_IM24_sh %in% african_regions)


#Instruction 1: Clean and tidy the datasets


ipcc_2006_africa <- ipcc_2006_africa %>% rename(Region = C_group_IM24_sh, Code = Country_code_A3, Industry = ipcc_code_2006_for_standard_report_name) %>% 
                  select(-IPCC_annex,-ipcc_code_2006_for_standard_report, -Substance)%>% 
                   pivot_longer(cols = starts_with("Y_"), names_to = "Year", values_to = "C02", values_drop_na =  TRUE) %>% 
                    mutate(Year= str_replace(Year, "Y_", ""), Year = as.integer(Year)) 
View(ipcc_2006_africa)

totals_by_country_africa<- totals_by_country_africa %>% rename(Region = C_group_IM24_sh, Code = Country_code_A3) %>%
                          select(-IPCC_annex, -Substance) %>%
                            pivot_longer(cols = starts_with("Y_"), names_to = "Year", values_to = "C02", values_drop_na = TRUE) %>%
                             mutate(Year= str_replace(Year, "Y_", ""), Year = as.integer(Year)) 
View(totals_by_country_africa)

#Instruction 2: Show the trend of CO2 levels across the African regions
co2_level_by_region_per_year <- totals_by_country_africa %>%
                          group_by(Region, Name, Year) %>% summarise(C02_Mean = mean(C02))
                           co2_level_by_region_per_year

trend_of_CO2_emission_plot <- ggplot(data = co2_level_by_region_per_year, aes(x= Year, y= log10(C02_Mean), color=  Region)) +
                                geom_line() +
                                  ggtitle("CO2 levels across the African Regions between 1970 and 2021") +
                                    theme_classic()

trend_of_CO2_emission_plot

#Instruction 3: Determine the relationship between time and CO2 levels in each African region

relationship_btw_time_CO2 <- totals_by_country_africa %>% 
                              group_by(Region) %>% 
                                summarise(correlation = cor(C02, Year, method = "spearman"))

relationship_btw_time_CO2


#Instruction 4: Determine if there is a significant difference in the CO2 levels among the African Regions

aov_results <- aov(C02 ~ Region, data = totals_by_country_africa)

pw_ttest_result <- pairwise.t.test(totals_by_country_africa$C02, totals_by_country_africa$Region,  p.adjust.method = "bonferroni")

    # Check if CO2 levels of Southern_Africa and Northern_Africa differ significantly
significant_diff <- pw_ttest_result$p.value["Southern_Africa", "Northern_Africa"] < 0.05
print(significant_diff)

#Instruction 5: Determine the most common (top 5) industries in each African region.

top_5_industries <- ipcc_2006_africa %>%
                      group_by(Region) %>%
                        count(Industry, name = "Number", sort = TRUE) %>%
                          slice_max(n= 5, order_by = Number)
top_5_industries


#Instruction 6: Determine the industry responsible for the most amount of CO2 (on average) in each African Region

top_industry_by_co2_emission <- ipcc_2006_africa %>%
                                  group_by(Region, Industry) %>%
                                    summarise(Mean = mean(C02)) %>%
                                      arrange(desc(Mean)) %>%
                                       slice_max(n=4, order_by = Mean)
top_industry_by_co2_emission


#Instruction 7: Predict the CO2 levels (at each African region) in the year 2025

    # create a dataframe for the year 2025 (provided for you)
newdata <- data.frame(Year = 2025, Region = african_regions)


model <- lm(log10(C02) ~Year  + Region , data = totals_by_country_africa) 

predicted_co2_log <- predict(model, newdata = newdata)


    # Convert predicted CO2 levels from log base 10 to decimals
predicted_co2 <- 10^predicted_co2_log

    # Combine the prediction with the original data frame
newdata$Predicted_CO2 <- predicted_co2

    # Print the results
print(newdata)



#Instruction 8: Determine if CO2 levels affect the annual temperature in the selected African countries

selected_countries <- totals_by_country_africa %>%
                        select(Name, Year, C02) %>%
                          filter( Name %in% c("Ethiopia", "Mozambique", "Nigeria", "Tunisia"))


temp_long <- temperatures %>%
              pivot_longer(cols = starts_with(c("Ethiopia", "Mozambique", "Nigeria", "Tunisia")), names_to = "Name", values_to = "Temperature")
temp_long


joined <- selected_countries %>%
            inner_join(temp_long, by = c("Year", "Name"))

View(joined)

joined_plt <- ggplot(joined, aes(x = log10(C02), y = Temperature, color= Name)) +
                geom_point() +
                 labs(title = "Relationship between Temperature and CO2",
                  y = "Temperature (C)",
                    x = "CO2 (kt) in log base 10") + 
                      theme_classic()
joined_plt

model_temp <- lm(Temperature ~ log10(C02) + Name, data = joined)
model_temp

#Temperature segments 

ggplot(joined, aes(x = Year, y= Temperature, color = Name)) + 
  geom_line() + 
    theme_classic()  +
     labs(title = "Temperature Levels from 1970 - 2020",
       y = "Temperature (C)",
       x = "Year")
 

#Top 10 Industries in Ghana C02 Levels 
Top10_Ghana_C02 <- head(ipcc_2006_africa %>% filter(Name == 'Ghana') %>% group_by(Industry) %>% summarise(TotalC02 = sum(C02))%>% arrange(desc(TotalC02)),10)

Top10_Ghana_C02
 
ggplot(Top10_Ghana_C02, aes(TotalC02, Industry)) + 
  geom_col() +
    theme_classic() +
      labs(title = "Top 10 Industries In Ghana C02 Levels")
        