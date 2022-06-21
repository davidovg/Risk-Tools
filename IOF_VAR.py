import pandas as pd
import os
import numpy as np

from sqlalchemy import create_engine
import re
import time
from datetime import datetime
from quant_utils import *
from scipy.stats import norm
import matplotlib.pyplot as plt

#################################
#################################
####To be remembered#############
## 1) This code implements EWMA VaR on the NAV of IOF
## 2) To be run in the morning to compare it with NAV from previous day
## 3) As the NAV is used to gauge the performance at the moment different assets' contribution not implemented
#################################
#################################

wd_lt = "P:\\Boyan Davidov\\VAR_IOF"


Schema = "quantdb"
User = "t_gfg_2"
Pwd = "bqdoit"
Host = "PC-14"

ParamsMySQLconnection = create_engine("mysql://" + User + ":" + Pwd + "@" + Host + "/" + Schema)

BACKTEST_BEGIN = date(2018, 12, 31)
#BACKTEST_END = date(2021, 9, 27)

BACKTEST_END = datetime.today().date()

EX_AOD = fromPy2Excel(BACKTEST_END)
EX_START_DATE = fromPy2Excel(BACKTEST_BEGIN)


#VaR_date = datetime(2021, 9, 27).date()
#IOF_VaR_name = wd_lt+"\\IOF_VaR_"+VaR_date.isoformat().replace("-", "")+'.xlsx'


NAV_TIMESERIES_QUERY = "SELECT * FROM t_timeseries_data WHERE ts_id = 1143" \
                     " AND date_id >= "+ str(EX_START_DATE)+" AND date_id <= "+str(EX_AOD)
nav_ts_raw = pd.read_sql(NAV_TIMESERIES_QUERY, con=ParamsMySQLconnection)

nav_ts_raw = nav_ts_raw.drop(["ts_id"], axis = 1)

nav_ts_raw["date_id"].map(fromExcel2Py)

nav_ts_raw["date_id"] = nav_ts_raw["date_id"].map(fromExcel2Py)
nav_ts_raw = nav_ts_raw.set_index('date_id')
#
# nav_ts_raw=nav_ts_raw.append(pd.Series(100.357, index=nav_ts_raw.columns, name=date(2021, 10, 27)))
#nav_ts_raw=nav_ts_raw.append(pd.Series(100.3441, index=nav_ts_raw.columns, name=date(2021, 11, 5)))

nav_ts_raw.to_excel(wd_lt + "\\IOF_NAV_today.xlsx")



periodInterval = 21
EWMAstdev = np.empty([len(nav_ts_raw) - periodInterval, ])

dSumWtdRet = 0
lamb = 0.72




def EWMA(ts, lamb=0.72, conf = 0.99):
    dSumWtdRet = 0
    periodInterval = len(ts)
    for i in range((periodInterval)-1,0,-1):
        dLogRet = np.log(ts.iloc[i]/ts.iloc[i-1])
        dlogRetSq = pow(dLogRet,2)
        w = (1-lamb) * pow( lamb, (periodInterval-1-i))
        dwRet = w * dlogRetSq
        dSumWtdRet = dSumWtdRet + dwRet
    ewmaPeriod = (pow(dSumWtdRet, 0.5) * norm.ppf(conf)) * pow(10,0.5)
    return ewmaPeriod


rollPeriod = len(nav_ts_raw) - periodInterval


varDF = pd.DataFrame(index=nav_ts_raw.iloc[-rollPeriod+1:].index,columns=["VaR"])
for i in range(0,(rollPeriod-1)):
    varDF.iloc[i] = -(EWMA(nav_ts_raw.iloc[(-len(nav_ts_raw)+i):(-rollPeriod+i+1)])).values


#calculate 10d log return and plot it
varDF[["10d_Ret"]] = np.log(nav_ts_raw) - np.log(nav_ts_raw.shift(9))

#overshootings
varDF["Overshootings"] = np.where(varDF['10d_Ret'] < varDF['VaR'], varDF['10d_Ret'], np.nan)

#varDF[["10d_Ret"]].plot(kind="bar", label = "10d Ret", legend=True)
varDF.VaR.plot(color = "b", linewidth=0.5)
plt.bar(varDF.index, varDF[["10d_Ret"]].values.reshape(len(varDF[["10d_Ret"]])), color = "k", label = "10d Ret")
plt.legend(["VaR", "10d Ret"])
plt.xlabel("Date")
plt.title("IOF - VaR/Return/Overshootings")


overshootings = varDF[["Overshootings"]].dropna()
plt.plot(overshootings.index, overshootings,linestyle="None", marker='v', color='g')
plt.axhline(y=-0.01, color='r', linestyle='--',lw=0.5,  label='1% VaR alert')

plt.show()

#plot also returns as text next to overshootings
# for i in range(overshootings.shape[0]):
#     plt.text(overshootings.index[i], np.asarray(float(overshootings.iloc[i].values.reshape(1)), str(overshootings.iloc[i].values).strip('[]')))

storefile_lt = "P:\\GFG LAB\\DailyReportsIOF\\Report_"
Report_output_file = storefile_lt+datetime.today().date().isoformat().replace("-", "")+'.xlsx'
varDF.to_excel(Report_output_file, sheet_name='VaR', engine='xlsxwriter')

overshootings

varDF.tail()

