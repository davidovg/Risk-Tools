knitr::opts_chunk$set(message = FALSE)
rm(list=ls())

#choose directory
setwd("T://DAB")

#invisible(lapply(c("tidyverse","gmodels","readr","lubridate","questionr"),         function(x) suppressPackageStartupMessages(require(x, character.only=TRUE))))

library(readxl)
library(writexl)
library(lubridate)
library(dplyr)
library(tidyr)
library(ggplot2)
library(formattable)
library(knitr)
library(kableExtra)
library(openxlsx)
library(tidyverse)


#read data
datavolume<-read_excel("T://DAB/Fees_details.xlsm", sheet = "DATA VOLUME", col_names = TRUE, col_types = NULL, na = "", skip = 0)
database<-read_excel("T://DAB/Fees_details.xlsm", sheet = "DATABASE", col_names = TRUE, col_types = NULL, na = "", skip = 0)

database<-subset(database, SubCategory=="Brokerage")

volume_grouped<-datavolume %>% group_by(Nat,exch,brk, bu) %>% 
  summarize( Euro_volume=sum(Euro), Qty = sum(Qty) )

fees_grouped<-database %>% group_by(Nationality,Exchange, Counterparty, BusinessUnit) %>%
  summarize( Fees_AmountInEur = sum(AmountInEur) )

#clean data by removing rows without amount of fees 
fees_grouped<-fees_grouped %>% drop_na(Fees_AmountInEur)


# merge the two dataframes
final_table<-merge(fees_grouped, volume_grouped, by.x = c("Nationality","Exchange", "Counterparty", "BusinessUnit"),  
                   by.y = c("Nat", "exch","brk",	"bu"), all.x=TRUE)

final_filtered <-subset(final_table, Counterparty %in% c("BYLN","INLN","MSLN"))
final_filtered<-final_filtered %>% drop_na()

final_filtered$Fees_for_1bps<- round((final_filtered$Euro_volume/final_filtered$Fees_AmountInEur)/10000,2)
final_filtered$Fees_for_1bps[final_filtered$Nat=="US"] <- round((final_filtered$Qty[final_filtered$Nat=="US"]/final_filtered$Fees_AmountInEur[final_filtered$Nat=="US"])/10000,2)



wb<-createWorkbook("fees_details_output.xlsx")
addWorksheet(wb, sheetName = "Fees Summary whole period")
writeData(wb, sheet = "Fees Summary whole period", final_filtered, colNames = T,
          borders = c("columns"),
          borderColour = getOption("openxlsx.borderColour", "black"),
          borderStyle = getOption("openxlsx.borderStyle", "thin"))


#######################################
#Filter by Category, Strategy and Month
#######################################

# make month column
database$Month<-month(as.POSIXlt(database$Date, format="%Y/%m/%d"))
datavolume$Month<-month(as.POSIXlt(datavolume$Dt, format="%Y/%m/%d"))

database_sparse<-subset(database, SubCategory=="Brokerage")

#group data by relevant keys - Nationality, Exchange, Broker, B.Unit
volume_grouped_sparse<-datavolume %>% group_by(Nat,exch,brk, bu, Month) %>% 
  summarize( Euro_volume=sum(Euro,na.rm = TRUE ), Qty = sum(Qty, na.rm=TRUE) )

fees_grouped_sparse<-database_sparse %>% group_by(Nationality,Exchange, Counterparty, BusinessUnit, Month) %>%
  summarize( Fees_AmountInEur = sum(AmountInEur, na.rm=TRUE ) )

#clean data by removing rows without amount of fees 
#fees_grouped_sparse<-fees_grouped_sparse %>% drop_na(Fees_AmountInEur)

# merge the two dataframes
final_sparse<-merge(fees_grouped_sparse, volume_grouped_sparse, by.x = c("Nationality","Exchange", "Counterparty", "BusinessUnit", "Month"),  
                   by.y = c("Nat", "exch","brk",	"bu", "Month"), all.y=TRUE)

filtered_sparse <-subset(final_sparse, Counterparty %in% c("BYLN","INLN","MSLN"))

filtered_sparse_clean<-filtered_sparse %>% drop_na(Fees_AmountInEur)


filtered_sparse_clean$Fees_for_1bps<-round((filtered_sparse_clean$Euro_volume/filtered_sparse_clean$Fees_AmountInEur)/10000,2)
filtered_sparse_clean$Fees_for_1bps[filtered_sparse_clean$Nat=="US"] <- round((filtered_sparse_clean$Qty[filtered_sparse_clean$Nat=="US"]/filtered_sparse_clean$Fees_AmountInEur[filtered_sparse_clean$Nat=="US"])/10000,2)

#filter to leave only Inter strategy
filtered_sparse <- subset(filtered_sparse, BusinessUnit == "Inter")
filtered_sparse_clean <- subset(filtered_sparse_clean, BusinessUnit == "Inter")
filtered_sparse$Volume_Amt_EUR<-filtered_sparse$Euro_volume



spreaded_DF<-filtered_sparse_clean %>%
  spread(Month, Fees_for_1bps)


spreaded_DF<-spreaded_DF %>% 
  rename(
    "Jun" = "6",
    "Jul" = "7",
    "Aug" = "8",
    "Sep" = "9",
    "Oct" = "10")

addWorksheet(wb, sheetName = "Fees per bps Summary by month")
writeData(wb, sheet = "Fees per bps Summary by month", spreaded_DF, colNames = T)
        

#######################################
#Simulation all current brokers
#######################################
# By current brokers we mean such that trades 
# have already been executed with in the current period
# not including other possible broker

agg_byMonth<-filtered_sparse %>% group_by(Nationality,Exchange, Month) %>%
summarize(Euro_volume = sum(Euro_volume, na.rm=TRUE))

fees_sim<-merge(filtered_sparse, agg_byMonth, by.x = c("Nationality","Exchange","Month"),  
                   by.y = c("Nationality", "Exchange","Month"), all.x=TRUE)


fees<-suppressWarnings(suppressMessages(read_excel("T://DAB/Fees_details.xlsm", sheet = "FEES PARAMETRAGE", col_names = TRUE, col_types = NULL, na = "", skip = 0)))


fees_distinct<- fees %>% distinct(TIE_CODE, PLA_CODE_MIC, SellBps, .keep_all = TRUE)
fees_distinct_highest<- fees_distinct %>%
  group_by(TIE_CODE, PLA_CODE_MIC) %>%
  summarise(SellBps= max(SellBps))


fees_sim_summary<-merge(fees_sim, fees_distinct_highest[, c("TIE_CODE", "PLA_CODE_MIC", "SellBps")], by.x = c("Counterparty","Exchange"),  
                by.y = c("TIE_CODE", "PLA_CODE_MIC"), all.x=TRUE)

fees_sim_summary<-fees_sim_summary[c(3,2,1,4:8,11,9,10)]

fees_sim_summary<-fees_sim_summary[
  with(fees_sim_summary, order(Nationality, Exchange, Month)),
]

colnames(fees_sim_summary)[colnames(fees_sim_summary)=="Euro_volume.y"]<-"All Volume on Exch"
colnames(fees_sim_summary)[colnames(fees_sim_summary)=="Volume_Amt_EUR"]<-"Actual Volume with Broker"

fees_sim_summary$`Amount Paid at Exch`<-fees_sim_summary$Fees_AmountInEur
fees_sim_summary$`Amount Paid at Exch`[is.na(fees_sim_summary$Fees_AmountInEur)]<-
  fees_sim_summary$`Actual Volume with Broker`[is.na(fees_sim_summary$Fees_AmountInEur)]*(fees_sim_summary$SellBps[is.na(fees_sim_summary$Fees_AmountInEur)]/10000)
  

fees_sim_summary1<-fees_sim_summary %>% group_by(Nationality,Exchange,Month) %>%
  summarize(`Amount Paid at Exch` = sum(`Amount Paid at Exch`, na.rm=TRUE))

fees_sim_end<-merge(fees_sim_summary, fees_sim_summary1, by.x = c("Nationality","Exchange", "Month"),  
                    by.y = c("Nationality", "Exchange", "Month"), all.x=TRUE)


colnames(fees_sim_end)[colnames(fees_sim_end)=="Amount Paid at Exch.x"]<-"All Amount Paid with Broker"

colnames(fees_sim_end)[colnames(fees_sim_end)=="Amount Paid at Exch.y"]<-"All Amount Paid on Exch"

fees_sim_end$Simulated<-fees_sim_end$`All Volume on Exch`*(fees_sim_end$`SellBps`/10000)

fees_sim_end$Potential_Gain<-fees_sim_end$`All Amount Paid on Exch`- fees_sim_end$Simulated
#fees_sim_end$Potential_Gain>0

fees_sim_end$pct_gain<-(fees_sim_end$Potential_Gain/fees_sim_end$`All Amount Paid on Exch`)

fees_sim_end<-subset(fees_sim_end, fees_sim_end$Nationality != "US")

pct_gain<-(fees_sim_end$Potential_Gain/fees_sim_end$`All Amount Paid on Exch`)

qplot((1:length(pct_gain)),pct_gain, geom='point',color=pct_gain > 0, xlab="#Cases", ylab="Potential Gain", main="Potential Gain Analysis")


#x<-as.numeric(fees_sim_end %>% rownames_to_column() %>% top_n(10, `All Amount Paid on Exch`) %>% pull(rowname))
#x_table<-fees_sim_end[x,c(1,2,3,4,12,14,15,16)]

#x_table

x<-as.numeric(fees_sim_end %>% rownames_to_column() %>% top_n(10, Potential_Gain) %>% pull(rowname))
x_table<-fees_sim_end[x,c(1,2,3,4,12,14,15,16)]

x_table

fees_sim_end<-formattable(fees_sim_end)

addWorksheet(wb, sheetName = "Fees_Simulation_Existing")
writeData(wb, sheet = "Fees_Simulation_Existing", fees_sim_end, colNames = T,
borders = c("columns"),
borderColour = getOption("openxlsx.borderColour", "black"),
borderStyle = getOption("openxlsx.borderStyle", "thin"))

##################################################
#Simulation all possible brokers at exchange
##################################################
# 
# agg<-spreaded_DF %>% group_by(Nationality,Exchange) %>%
#   summarize(Euro_volume = sum(Euro_volume, na.rm=TRUE))
datavolume<-read_excel("T://DAB/Fees_details.xlsm", sheet = "DATA VOLUME", col_names = TRUE, col_types = NULL, na = "", skip = 0)
database<-read_excel("T://DAB/Fees_details.xlsm", sheet = "DATABASE", col_names = TRUE, col_types = NULL, na = "", skip = 0)

database$Month<-month(as.POSIXlt(database$Date, format="%Y/%m/%d"))
datavolume$Month<-month(as.POSIXlt(datavolume$Dt, format="%Y/%m/%d"))

database_sparse<-subset(database, SubCategory=="Brokerage")
database_sparse<-subset(database_sparse, Nationality != "US")
database_sparse<-subset(database_sparse, BusinessUnit == "Inter")
datavolume<-subset(datavolume, bu == "Inter")


#group data by relevant keys - Nationality, Exchange, Broker, B.Unit
volume_grouped_sparse<-datavolume %>% group_by(Month, Nat,exch,brk) %>% 
  summarize( Euro_volume=sum(Euro,na.rm = TRUE ), Qty = sum(Qty, na.rm=TRUE) )

fees_grouped_sparse<-database_sparse %>% group_by(Month,Nationality, Exchange, Counterparty, BusinessUnit) %>%
  summarize( Fees_AmountInEur = sum(AmountInEur, na.rm=TRUE ) )

#clean data by removing rows without amount of fees 
fees_grouped_sparse<-fees_grouped_sparse %>% drop_na(Fees_AmountInEur)

# merge the two dataframes
final_sparse<-merge(fees_grouped_sparse, volume_grouped_sparse, by.x = c("Month","Nationality","Exchange", "Counterparty"),  
                    by.y = c("Month","Nat","exch","brk"), all.y=TRUE)

final_sparse<-final_sparse %>% drop_na(Fees_AmountInEur)

filtered_sparse <-subset(final_sparse, Counterparty %in% c("BYLN","INLN","MSLN"))

fees<-suppressWarnings(suppressMessages(read_excel("T://DAB/Fees_details.xlsm", sheet = "FEES PARAMETRAGE", col_names = TRUE, col_types = NULL, na = "", skip = 0)))
#fees[fees$SellBps==0,]<-fees[fees$SellBps==0,]$SellCts

fees<-subset(fees, fees$SellBps != 0)

fees_distinct<- fees %>% distinct(TIE_CODE, PLA_CODE_MIC, PLA_NOM, NAT_CODE_2, SellBps, .keep_all = TRUE)
fees_distinct_highest<- fees_distinct %>%
  group_by(TIE_CODE, PLA_CODE_MIC, NAT_CODE_2, PLA_NOM) %>%
  summarise(SellBps= min(SellBps), SellCts = min(SellCts))


fees_sim_summary<-merge(filtered_sparse, fees_distinct_highest[, c("TIE_CODE", "PLA_CODE_MIC", "NAT_CODE_2","PLA_NOM", "SellBps", "SellCts")], by.x = c("Exchange"),  
                        by.y = c("PLA_CODE_MIC"), all.x=TRUE)


fees_sim_summary<-fees_sim_summary[
  with(fees_sim_summary, order(Nationality,Exchange)),
]

#change columns order, for reading simplicity
fees_sim_summary<-fees_sim_summary[c(2,3,1,11,10,5,4,8,7,6,9,12)]


colnames(fees_sim_summary)[colnames(fees_sim_summary)=="Nationality"]<-"Security Nat"
colnames(fees_sim_summary)[colnames(fees_sim_summary)=="Exchange"]<-"Market MIC"
colnames(fees_sim_summary)[colnames(fees_sim_summary)=="PLA_NOM"]<-"Market Name"
colnames(fees_sim_summary)[colnames(fees_sim_summary)=="NAT_CODE_2"]<-"Market Nat"


spreaded_DF<-fees_sim_summary %>%
  spread(TIE_CODE, SellBps)


spreaded_DF<-spreaded_DF[
  with(spreaded_DF, order(`Security Nat`,`Market MIC`,Month)),
]

#spreaded_DF<- spreaded_DF %>% 
#  mutate(Best_Broker = apply(.[,c("BYLN","INLN","MSLN")], 1, function(x) names(x)[which.min(x)]))


spreaded_DF<- spreaded_DF %>% 
  mutate(Best_Broker = apply(.[,c("BYLN","INLN","MSLN")], 1, function(x) names(x)[which(x==min(x, na.rm=T))]))


for (i in 1:length(spreaded_DF[,1])){
  spreaded_DF$Keep_Current_Broker[i]<-ifelse(sum(spreaded_DF$Counterparty[i]==spreaded_DF$Best_Broker[[i]])>=1, "YES", "NO") 
}

#spreaded_DF$Keep_Current_Broker<-ifelse(sum(spreaded_DF$Counterparty==spreaded_DF$Best_Broker)>=1, "YES", "NO")


for (i in 1:length(spreaded_DF[,1])) {
  if (rowSums(is.na(spreaded_DF[i,c("INLN","BYLN","MSLN")]))==2) {spreaded_DF$Potential_Gain_Loss[i]=0} else {
  if (spreaded_DF$Counterparty[i]=="BYLN") {
    spreaded_DF$Simulated_Fees[i]<-spreaded_DF$Euro_volume[i]*(min(spreaded_DF[i,c("INLN","MSLN")],na.rm=TRUE)/10000)
    spreaded_DF$Potential_Gain_Loss[i]= spreaded_DF$Fees_AmountInEur[i] - spreaded_DF$Euro_volume[i]*(min(spreaded_DF[i,c("INLN","MSLN")],na.rm=TRUE)/10000)
    } else { 
    if (spreaded_DF$Counterparty[i]=="INLN") {
      spreaded_DF$Simulated_Fees[i]<-spreaded_DF$Euro_volume[i]*(min(spreaded_DF[i,c("BYLN","MSLN")],na.rm=TRUE)/10000)
      spreaded_DF$Potential_Gain_Loss[i]= spreaded_DF$Fees_AmountInEur[i] - spreaded_DF$Euro_volume[i]*(min(spreaded_DF[i,c("BYLN","MSLN")],na.rm=TRUE)/10000)
    } else { 
      spreaded_DF$Simulated_Fees[i]<-spreaded_DF$Euro_volume[i]*(min(spreaded_DF[i,c("BYLN","INLN")],na.rm=TRUE)/10000)
      spreaded_DF$Potential_Gain_Loss[i]= spreaded_DF$Fees_AmountInEur[i] - spreaded_DF$Euro_volume[i]*(min(spreaded_DF[i,c("BYLN","INLN")],na.rm=TRUE)/10000)
    }}}
}

spreaded_DF$Potential_Gain_Loss<-ifelse(spreaded_DF$Keep_Current_Broker=="YES",0, spreaded_DF$Potential_Gain_Loss)

spreaded_DF$Pct_Potential_Gain=(spreaded_DF$Potential_Gain_Loss/spreaded_DF$Fees_AmountInEur)

colnames(spreaded_DF)[colnames(spreaded_DF)=="Counterparty"]<-"Current Broker"

df <- apply(spreaded_DF,2,as.character)
write.csv(df,"fees_data_studio.csv", row.names = FALSE)

addWorksheet(wb, sheetName = "Fees_Simulation_Potential_Gain")
writeData(wb, sheet = "Fees_Simulation_Potential_Gain", spreaded_DF, colNames = T,
          borders = c("columns"),
          borderColour = getOption("openxlsx.borderColour", "black"),
          borderStyle = getOption("openxlsx.borderStyle", "thin"))
saveWorkbook(wb, "fees_details_output.xlsx" ,overwrite = T)

qplot((1:length(spreaded_DF$Pct_Potential_Gain)),spreaded_DF$Pct_Potential_Gain, geom='point',color=spreaded_DF$Pct_Potential_Gain > 0,
      xlab="#Cases", ylab="Potential Gain", main="Potential Gain Analysis", ylim = c(-3,3))

# spreaded_DF_top<-spreaded_DF[
#        with(spreaded_DF, order(Euro_volume)),
#    ]
# 
# spreaded_DF_top50<-spreaded_DF_top[1:50,]
# hist(count(spreaded_DF_top50$Best_Broker))
# df <- spreaded_DF_top50 %>%
#   group_by(Keep_Current_Broker) %>%
#   summarise(counts = n())
# hist(df$counts)
# 
# ggplot(df, aes(x = c("MSLN","BYLN","INLN"), y = counts)) +
#     geom_bar(fill = "#0073C2FF", stat = "identity") +
#   geom_text(aes(label = c("MSLN","BYLN","INLN")), vjust = -0.3) + 
#   theme_pubclean()
# 
# ggplot(df, aes(x = "", y = counts, fill = Best_Broker)) +
#   geom_bar(width = 1, stat = "identity", color = "white") +
#   geom_text(aes(y = lab.ypos, label = counts), color = "white")+
#   coord_polar("y", start = 0)+
#   ggpubr::fill_palette("jco")+
#   theme_void()


latency<-read_excel("T://DAB/Latences par place.xlsx", col_names = TRUE, col_types = NULL, na = "", skip = 0)
writeData(wb, sheet = "latency_row", latency, colNames = T,
          borders = c("columns"),
          borderColour = getOption("openxlsx.borderColour", "black"),
          borderStyle = getOption("openxlsx.borderStyle", "thin"))

latency <- latency %>% mutate(ExDestination=recode(ExDestination, 
                        `BATS_DIRECT` ="BATE",
                        BATS_NXTG = "BATE",
                        BATS_SPEEDWAY ="BATE",
                        BS ="BATE",
                        CHI = "CHIX",
                        TQ = "TRQX",
                        DE="XETR"))


final_latency<-merge( spreaded_DF, latency[, c("Broker", "MarketPlace", "ExDestination", "OrderType", "NumberOfRoundTrips", "MedianInMicroSeconds", "90thPercentileInMicroSeconds")], by.x = c("Current Broker",  "Market Name"),  
                    by.y = c("Broker", "MarketPlace"), all.x=TRUE)


# wb_output<-createWorkbook("fees_details_output.xlsx")
# addWorksheet(wb_output, sheetName = "latency")
# writeData(wb_output, sheet = "latency", final_latency, colNames = T,
#           borders = c("columns"),
#           borderColour = getOption("openxlsx.borderColour", "black"),
#           borderStyle = getOption("openxlsx.borderStyle", "thin"))
# saveWorkbook(wb_output,"fees_details_output.xlsx", overwrite = T)

final_latency1<-final_latency

final_latency1 %>% mutate_if(is.list, as.character) -> mutated_df

final_latency_best<-merge( mutated_df, latency[, c("Broker", "MarketPlace", "ExDestination", "OrderType", "NumberOfRoundTrips", "MedianInMicroSeconds", "90thPercentileInMicroSeconds")], by.x = c("Best_Broker",  "Market Name", "OrderType", "ExDestination"),  
                      by.y = c("Broker", "MarketPlace", "OrderType", "ExDestination"), all.x=TRUE)

colnames(final_latency_best)[colnames(final_latency_best)=="NumberOfRoundTrips.x"]<-"CurrentBrk_NumberOfRoundTrips"
colnames(final_latency_best)[colnames(final_latency_best)=="MedianInMicroSeconds.x"]<-"CurrentBrk_MedianInMicroSeconds"
colnames(final_latency_best)[colnames(final_latency_best)=="90thPercentileInMicroSeconds.x"]<-"CurrentBrk_90thPercentileInMicroSeconds"

colnames(final_latency_best)[colnames(final_latency_best)=="NumberOfRoundTrips.y"]<-"BestBrk_NumberOfRoundTrips"
colnames(final_latency_best)[colnames(final_latency_best)=="MedianInMicroSeconds.y"]<-"BestBrk_MedianInMicroSeconds"
colnames(final_latency_best)[colnames(final_latency_best)=="90thPercentileInMicroSeconds.y"]<-"BestBrk_90thPercentileInMicroSeconds"


final_latency_best<-final_latency_best[,c(6,7,2,8,9, 10:16, 1, 5, 17, 18:20, 3,4,21:26)]

final_latency_best<-final_latency_best[
  with(final_latency_best, order(`Security Nat`, `Market MIC`, Month)),
  ]


#wb_output<-createWorkbook("fees_details_output.xlsx")
addWorksheet(wb, sheetName = "Fees_Details_Latency")
writeData(wb, sheet = "Fees_Details_Latency", final_latency_best, colNames = T,
          borders = c("columns"),
          borderColour = getOption("openxlsx.borderColour", "black"),
          borderStyle = getOption("openxlsx.borderStyle", "thin"))
saveWorkbook(wb,"fees_details_output.xlsx", overwrite = T)


################## count duplicates
library(data.table)
library(hutils)


duplicated_rows(latency, by = c("Broker", "MarketPlace"), order = FALSE)

x<-duplicated_rows(data.table(latency), by = c("Broker", "MarketPlace"), order = FALSE)

latency %>%
  count_duplicates(Broker,MarketPlace)

dupes<-get_dupes(latency, Broker, MarketPlace)



