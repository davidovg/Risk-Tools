library(writexl)
library(openxlsx)
library(readxl)
library(stringr)
library(lubridate)

currentDate <-Sys.Date()
# end of previous month:
eopm <- currentDate - days(day(currentDate))
# [1] "2012-10-31"

# start of previous month:
sopm <- currentDate - days(day(currentDate))
sopm <- sopm - days(day(sopm) - 1)
# [1] "2012-10-01"

recDate <- format(Sys.Date(), "%m-%Y")

recDateY <- format(Sys.Date(), "%Y")

dirKPPA <- paste("I://Abc/Portefeuille/Suivi_Ordres/confirmations_brokers/KPPA", recDateY, recDate, sep = "/")
#setwd("I://Abc/Portefeuille/Suivi_Ordres/confirmations_brokers/KPPA/2020/06-2020")

setwd(dirKPPA)

file_list <- list.files(path=dirKPPA)

auj_day<-as.numeric(format(Sys.Date(), "%d"))


dates<-(str_extract(file_list, "(?<=_).*(?=.csv)"))
dates_days<-as.numeric(substr(dates, start = 1, stop = 2))

files_to_look<-which(dates_days>((auj_day)-8))
data_final<-c()

if (auj_day - 8 < 0) {
  eopm_day<-as.numeric(format(eopm, "%d"))
  recDate <- format(eopm, "%m-%Y")
  recDateY <- format(eopm, "%Y")
  dirKPPA_prev<-paste("I://Abc/Portefeuille/Suivi_Ordres/confirmations_brokers/KPPA", recDateY, recDate, sep = "/")
  setwd(dirKPPA_prev)
  file_list_prev <- list.files(path=dirKPPA_prev)
  dates<-(str_extract(file_list_prev, "(?<=_).*(?=.csv)"))
  dates_days<-as.numeric(substr(dates, start = 1, stop = 2))
  files_to_look_prev<-which(dates_days>(eopm_day - abs(auj_day-8)))
  for (i in files_to_look_prev){
    temp_data <- read.csv(file_list_prev[i], header=T, sep=";")
    data_final<-rbind(data_final,temp_data)
  }
  setwd(dirKPPA)
}
  

for (i in files_to_look){
  temp_data <- read.csv(file_list[i], header=T, sep=";")
  data_final<-rbind(data_final,temp_data)
}

data_final$Deal.Date <- strptime(as.character(data_final$Deal.Date), "%m/%d/%Y")
data_final$Deal.Date <- format(data_final$Deal.Date, "%d/%m/%Y")

data_final$Settlement.Date<-strptime(as.character(data_final$Settlement.Date), "%m/%d/%Y")
data_final$Settlement.Date<-format(data_final$Settlement.Date, "%d/%m/%Y")

setwd("T://SAY")
#wb <- loadWorkbook("confirmation abcarbitrage KPPA.xlsx")


x<-read_excel("confirmation abcarbitrage KPPA.xlsx")

kepler<-do.call("rbind", replicate(nrow(data_final), x, simplify = FALSE))

for (i in 1:nrow(kepler)) {
  if (data_final$Side[i]=="Buy") {
    kepler$QA[i]<-data_final$Quantity[i]
    kepler$PA[i]<-data_final$Gross.Price[i]
  } else {
    kepler$QV[i]<-data_final$Quantity[i]
    kepler$PV[i]<-data_final$Gross.Price[i]
  }
}

kepler$`Date Négo`<-data_final$Deal.Date
kepler$`Date Intv`<-data_final$Deal.Date
kepler$`Date Valeur`<-data_final$Settlement.Date

kepler<-kepler[c(1:3,5:10,12:16,4,11,17)]
kepler$`Broker ID`<-NA
kepler$`Allocation ID`<-NA


colnames(kepler)[colnames(kepler) == "Broker ID"] <- "-"
colnames(kepler)[colnames(kepler) == "Allocation ID"] <- "-"

keplerM <- as.matrix(kepler)

#colnames(keplerM)[colnames(keplerM) == "Broker ID"] <- NA
#colnames(keplerM)[colnames(keplerM) == "Allocation ID"] <- NA



auj<-format(Sys.Date(), "%d-%m")
wb_name<-paste("confirmation abcarbitrage KPPA ", auj,".xlsx", sep="")

wb<-createWorkbook(wb_name)
addWorksheet(wb, sheetName = "KPPA")
writeData(wb, sheet = "KPPA", kepler, colNames = T,
          borders = c("columns"),
          borderColour = getOption("openxlsx.borderColour", "black"),
          borderStyle = getOption("openxlsx.borderStyle", "thin"))
saveWorkbook(wb,wb_name,overwrite = T)
