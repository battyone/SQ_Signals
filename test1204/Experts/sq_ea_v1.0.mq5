//+------------------------------------------------------------------+
//|                                                   sq_ea_v1.0.mq5 |
//|                                           Copyright 2015, fxborg |
//|                                  http://blog.livedoor.jp/fxborg/ |
//+------------------------------------------------------------------+
#property copyright "Copyright 2015, fxborg"
#property link      "http://blog.livedoor.jp/fxborg/"
#property version   "1.00"
#property strict


#include <Trade\Trade.mqh>


//---

#define PIP      ((_Digits <= 3) ? 0.01 : 0.0001)

//---
input ENUM_TIMEFRAMES  Timeframe_Bar=PERIOD_M5;
input ENUM_TIMEFRAMES  Timeframe_Main= PERIOD_H1;
input ENUM_TIMEFRAMES  Timeframe_Slow= PERIOD_D1;
//---

//---
input string  Order_Settings=" Trade Settings: ";
input double  Lot         = 0.1;
input int     SL          = 200;
input int     TP          = 200;
//---
input double  Slippage    = 3.0;
input ulong   Magic       = 6516001;
input int     SpreadLimit=10;
input double  MaxSpread=10;
input bool    AutoLots=false;
//---

//---
input string  StartTime   = "10:00";
input string  EndTime     = "02:00";
input int     PositionExpire=60;
input int     Friday_CloseTime=2200;
input bool    LunchTimeTrade=false;

input string Description2="--- Boundary Line Settings---";

input double InpBL_ScaleFactor=0.75; // Scale factor
input int    InpBL_MaPeriod=2;       // Smooth Period
input int    InpBL_VolatilityPeriod=55; //  Volatility Period

input string Description3="--- SQI Settings---";

input int InpSQ1_VolatPeriod=10; //1st Volatility Period
input int InpSQ1_VolatSmooth=2; // 1st Volatility Smooth Period
input int InpSQ1_VolatSlowPeriod=40; // 1st Volatility Slow Period 
input int InpSQ2_VolatPeriod=15; //2nd Volatility Period
input int InpSQ2_VolatSmooth=3; // 2nd Volatility Smooth Period
input int InpSQ2_VolatSlowPeriod=60; // 2nd Volatility Slow Period 
input double InpSQ_VolatLv1=0.3; // Volatility Level 1
input double InpSQ_VolatLv2=0.5; // Volatility Level 2

input string Description4="--- Other Settings---";
input int InpMomPeriod=10; // Momentum Period

//---
ENUM_SYMBOL_TRADE_EXECUTION execution;
int Slippage_P;
double  NormLot,SL_P,TP_P,StepTrail_P,SpreadLimit_P,BrakeEven_P;
double  STOP_LEVEL,FREEZE_LEVEL,VOL_STEP,VOL_MIN,VOL_MAX;
//---

// Globals variables
CTrade  trade;
MqlTick tick;
int BL_Handle;
int MOM_Handle;
int SQI1_Handle;
int SQI2_Handle;
int StartTimeInt,EndTimeInt;
int PositionExpireSec;
int min_rates_total;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {

//---
   StartTimeInt=TimeHour(StringToTime(StartTime))*100+TimeMinute(StringToTime(StartTime));
   EndTimeInt=TimeHour(StringToTime(EndTime))*100+TimeMinute(StringToTime(EndTime));
//---

//---
   PositionExpireSec=PositionExpire*3600;
//---

//---
   SpreadLimit_P=NormalizeDouble(SpreadLimit*PIP/_Point,0);
   Slippage_P=(int)NormalizeDouble(Slippage*PIP/_Point,0);
//---
   execution=(ENUM_SYMBOL_TRADE_EXECUTION) SymbolInfoInteger(_Symbol,SYMBOL_TRADE_EXEMODE);
//---

//---
   STOP_LEVEL       = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * PIP;
   FREEZE_LEVEL     = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL) * PIP;
   VOL_STEP         = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   VOL_MIN          = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   VOL_MAX          = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
//---

//---
   SL_P=NormDbl(SL * (PIP/_Point) * _Point);
   TP_P=NormDbl(TP * (PIP/_Point) * _Point);
//---

//---
   trade.SetExpertMagicNumber(Magic);
   trade.SetDeviationInPoints(Slippage_P);
   trade.SetTypeFilling(ORDER_FILLING_RETURN);
   trade.SetAsyncMode(true);
//---

//---
   min_rates_total=100;

//---
   BL_Handle=iCustom(NULL,Timeframe_Main,"boundary_line"
                     ,InpBL_ScaleFactor,InpBL_MaPeriod,InpBL_VolatilityPeriod);

//---
   if(BL_Handle==INVALID_HANDLE)
     {
      Alert("Error in loading of Boundary line. Error = ",GetLastError());
      return(INIT_FAILED);
     }
//---

   SQI1_Handle=iCustom(NULL,Timeframe_Main,"SQI"
                       ,InpSQ1_VolatPeriod,InpSQ1_VolatSmooth,InpSQ1_VolatSlowPeriod,InpSQ_VolatLv1,InpSQ_VolatLv2);

//---
   if(SQI1_Handle==INVALID_HANDLE)
     {
      Alert("Error in loading of SQI. Error = ",GetLastError());
      return(INIT_FAILED);
     }
   SQI2_Handle=iCustom(NULL,Timeframe_Main,"SQI"
                       ,InpSQ2_VolatPeriod,InpSQ2_VolatSmooth,InpSQ2_VolatSlowPeriod,InpSQ_VolatLv1,InpSQ_VolatLv2);

//---
   if(SQI2_Handle==INVALID_HANDLE)
     {
      Alert("Error in loading of SQI. Error = ",GetLastError());
      return(INIT_FAILED);
     }
//---
   MOM_Handle=iCustom(NULL,Timeframe_Main,"AdvMomentum",InpMomPeriod);

//---
   if(MOM_Handle==INVALID_HANDLE)
     {
      Alert("Error in loading of AdvMomentum Handle. Error = ",GetLastError());
      return(INIT_FAILED);
     }

//---
   ChartIndicatorAdd(ChartID(),0,BL_Handle);
   ChartIndicatorAdd(ChartID(),1,SQI1_Handle);
   ChartIndicatorAdd(ChartID(),2,SQI2_Handle);
   ChartIndicatorAdd(ChartID(),3,MOM_Handle);
//---

//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---

  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   static datetime LastTime;

//---
   if(Bars(_Symbol, Timeframe_Main) <=  min_rates_total) return;
//---

//---
   datetime now[1];
   if(CopyTime(_Symbol,Timeframe_Bar,0,1,now) != 1 ) return;
//---

//---
   if(!SymbolInfoTick(_Symbol, tick)) return;
//---

//---
   if(PositionSelect(_Symbol) && PositionGetInteger(POSITION_MAGIC)==Magic)
     {
      datetime openTime=(datetime)PositionGetInteger(POSITION_TIME);
      CheckClose(openTime,(ENUM_POSITION_TYPE) PositionGetInteger(POSITION_TYPE));
     }
//---

//---
   if(LastTime!=now[0])
     {
      LastTime=now[0];
      //---
      int allow_open=false;
      //---
      if(DayOfWeek()!=5)
        {
         if((StartTimeInt<=EndTimeInt) && (now[0]>=StartTimeInt && now[0]<EndTimeInt))
            allow_open=true;
         if((StartTimeInt>EndTimeInt) && (now[0]>=StartTimeInt || now[0]<EndTimeInt))
            allow_open=true;
        }
      //---
      if(!LunchTimeTrade && now[0]==12) allow_open=false;
      if(!allow_open)return;

      //---
      if(( tick.ask-tick.bid) > SpreadLimit_P) return;

      //---

      //---
      ENUM_POSITION_TYPE position_type=NULL;
      double position_volume=0.0;
      double autolot=(AutoLots==false)? Lot:(MathRound(AccountInfoDouble(ACCOUNT_BALANCE)/100)/100);
      //---
      if(PositionSelect(_Symbol) && PositionGetInteger(POSITION_MAGIC)==Magic)
        {
         position_type=(ENUM_POSITION_TYPE) PositionGetInteger(POSITION_TYPE);
         position_volume=PositionGetDouble(POSITION_VOLUME);
        }
      else
        {
         position_type=NULL;
         position_volume=0;
        }
      //---
      //AccountBalance 200%  < position volume return 
      if((autolot * 2) < position_volume) return;
      //---

      //---

      int sig=0;
      sig=CheckSignal();
      //---

      if(sig==1)
         //--- BUY
        {
         //--- every buy deals check ( close sell too) 
         if(hasDeal(12,DEAL_TYPE_BUY))return;
         if(position_volume==0.0)
            //--- Probing Buy
           {
            OpenOrder(ORDER_TYPE_BUY,autolot,SL,TP,"Buy");
            return;

           }
         else if(position_type==POSITION_TYPE_BUY)
         //--- Retracement Buy
           {
            OpenOrder(ORDER_TYPE_BUY,autolot*0.5,SL,TP,"Buy");
            return;
           }

        }

      else if(sig==-1)
      //--- SELL
        {
         //--- every sell deals check ( close buy too) 
         if(hasDeal(12,DEAL_TYPE_SELL))return;

         if(position_volume==0)
           {
            OpenOrder(ORDER_TYPE_SELL,autolot,SL,TP,"Sell");
            return;
           }

         else if(position_type==POSITION_TYPE_SELL)
         //--- Retracement Sell
           {
            OpenOrder(ORDER_TYPE_SELL,autolot*0.5,SL,TP,"Sell");
            return;
           }

        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int CheckSignal()
  {
//---

   double MomBuffer[];
   double MomAngleBuffer[];
   double MomUpBuffer[];
   double MomDnBuffer[];
   double MaBuffer[];
   double BLBuffer[];
   double AtrBuffer[];
   double SQ1stBuffer[];
   double SQ2ndBuffer[];
   double SlowTrendBuffer[];
   double TrendBuffer[];
//---
   Comment("Year");

//---
   ArraySetAsSeries(MaBuffer,true);
   ArraySetAsSeries(MomBuffer,true);
   ArraySetAsSeries(MomAngleBuffer,true);
   ArraySetAsSeries(MomUpBuffer,true);
   ArraySetAsSeries(MomDnBuffer,true);

   ArraySetAsSeries(BLBuffer,true);
   ArraySetAsSeries(SQ1stBuffer,true);
   ArraySetAsSeries(SQ2ndBuffer,true);
   ArraySetAsSeries(TrendBuffer,true);
   ArraySetAsSeries(SlowTrendBuffer,true);

//---

//---
   if(CopyBuffer(MOM_Handle   , 0, 1, 20, MomBuffer) == -1)   return 0;
   if(CopyBuffer(MOM_Handle   , 1, 1, 3, MomAngleBuffer) == -1)   return 0;
   if(CopyBuffer(MOM_Handle   , 2, 1, 20, MomUpBuffer) == -1)   return 0;
   if(CopyBuffer(MOM_Handle   , 3, 1, 20, MomDnBuffer) == -1)   return 0;
   if(CopyBuffer(BL_Handle   , 0, 1, 5, BLBuffer) == -1)   return 0;
   if(CopyBuffer(SQI1_Handle   , 1, 1, 30, SQ1stBuffer) == -1)     return 0;
   if(CopyBuffer(SQI2_Handle   , 1, 1, 30, SQ2ndBuffer) == -1)     return 0;


//---

//--- check buy or sell 
   int sig=0;
//---

// Sqeeze ?
   if((SQ1stBuffer[0]+ SQ2ndBuffer[0])/2 <2 )return 0;
   int brakepos=-1;
   for(int i=0;i<10;i++)
     {
      bool hasMom=(MomUpBuffer[i]<MomBuffer[i] || MomDnBuffer[i]>MomBuffer[i]);
      double sqi=(SQ1stBuffer[i]+SQ2ndBuffer[i])/2;
      if(hasMom && sqi>=2)
        {
         brakepos=i;
         break;
        }
     }
   if(brakepos== -1)return 0;

   bool isSQ=false;
   for(int i=brakepos;i<=27;i++)
     {
      double sqi0=(SQ1stBuffer[i]+SQ2ndBuffer[i])/2;
      double sqi1 = (SQ1stBuffer[i+1] + SQ2ndBuffer[i+1])/2;
      double sqi2 = (SQ1stBuffer[i+2] + SQ2ndBuffer[i+2])/2;
      if(sqi0<1 && sqi1<1 && sqi2<1)
        {
         isSQ=true;
         break;
        }
     }
   if(!isSQ)return 0;

   MqlRates rt[4];
//--- go trading only for first ticks of new bar
   if(CopyRates(NULL,Timeframe_Main,1,4,rt)!=4)
     {
      Print("CopyRates of ",_Symbol," failed, no history");
      return 0;
     }

//--- Low Spread   
   double sp3=rt[3].high-rt[3].low;
   double sp2=rt[2].high-rt[2].low;
   double sp1=rt[1].high-rt[1].low;
   double sp0=rt[0].high-rt[0].low;

   bool tooHigh= rt[0].close > BLBuffer[0] +15*PIP;
   bool tooLow = rt[0].close < BLBuffer[0] -15*PIP;

   if( MomDnBuffer[0]<MomBuffer[0] &&  MomAngleBuffer[0]==4 && !tooHigh)
      sig=1;

   if(MomUpBuffer[0]>MomBuffer[0] && MomAngleBuffer[0]==0 && !tooLow)
      sig=-1;

//---
   return(sig);
//---

  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double NormalizeLots(double __lots)
  {
//---
   int _lotsteps   = (int)(__lots / VOL_STEP);
   double _Nlots   = _lotsteps * VOL_STEP;
//---
   if(_Nlots < VOL_MIN) _Nlots = VOL_MIN;
   if(_Nlots > VOL_MAX) _Nlots = VOL_MAX;
//---

   return(_Nlots);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int TimeHour(datetime date)
  {
   MqlDateTime tm;
   TimeToStruct(date,tm);
   return(tm.hour);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int TimeMinute(datetime date)
  {
   MqlDateTime tm;
   TimeToStruct(date,tm);
   return(tm.min);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double NormDbl(double value)
  {
   return NormalizeDouble(value, _Digits);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CheckClose(datetime ordertime,ENUM_POSITION_TYPE pos_type)
  {
//---
   bool is_stop=false;
   int now=TimeHour(TimeCurrent())*100+TimeMinute(TimeCurrent());
//---

//---
   if(PositionExpire>0 && (TimeCurrent()-PositionExpireSec)>ordertime) is_stop=true;
   if(Friday_CloseTime>=0 && DayOfWeek()==5 && now>Friday_CloseTime) is_stop=true;

//---

//---

/*
   double Trend_Buffer[];
   ArraySetAsSeries(Trend_Buffer,true);
   if(CopyBuffer(BSI_Handle   , 3, 1, 3, Trend_Buffer) != -1)
    {
    
      if(pos_type==POSITION_TYPE_BUY &&
         Trend_Buffer[2]==0 &&
         Trend_Buffer[1]==0 &&
         Trend_Buffer[0]==0)
         {
         is_stop=true;
         }
      if(pos_type==POSITION_TYPE_SELL &&
         Trend_Buffer[2]==4 &&
         Trend_Buffer[1]==4 &&
         Trend_Buffer[0]==4)
         {
          is_stop=true;
         }
    }
*/

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
   if(is_stop)
     {
      trade.PositionClose(_Symbol);
     }

   return is_stop;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int DayOfWeek()
  {
   MqlDateTime tm;
   TimeCurrent(tm);
   return(tm.day_of_week);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool _OrderSend(ENUM_ORDER_TYPE type,double lots,double price,double stoploss,double takeprofit,string comment)
  {
   bool isECN=(execution == SYMBOL_TRADE_EXECUTION_MARKET);
   double sl = isECN ? 0.0: stoploss;
   double tp = isECN ? 0.0: takeprofit;

   trade.PositionOpen(_Symbol,type,lots,price,sl,tp,comment);

   if(trade.ResultRetcode()!=TRADE_RETCODE_DONE)
     {
      Print("PositionOpen Error: ",trade.ResultRetcodeDescription());
      return false;

     }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
   if(isECN && (stoploss>0 || takeprofit>0))
     {
      Sleep(100);
      trade.PositionModify(_Symbol,stoploss,stoploss);
      if(trade.ResultRetcode()!=TRADE_RETCODE_DONE)
        {
         Print("PositionModify Error: ",trade.ResultRetcodeDescription());
         return false;
        }

     }
   return true;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OpenOrder(ENUM_ORDER_TYPE cmd,double lot,int stop_loss,int take_profit,string comment)
  {
//---
   double sl = 0;
   double tp = 0;
   double price=0.0;
//---
   if(cmd==ORDER_TYPE_SELL)
     {
      sl=(SL==0) ? 0.0: NormDbl(tick.bid  + SL * PIP);
      tp=(TP==0) ? 0.0: NormDbl(tick.bid  - TP * PIP);
      price=tick.bid;
     }
//---
   else if(cmd==ORDER_TYPE_BUY)
     {
      sl=(SL==0) ? 0.0: NormDbl(tick.ask - SL * PIP);
      tp=(TP==0) ? 0.0: NormDbl(tick.ask + TP * PIP);
      price=tick.ask;
     }
   else
      return;

   _OrderSend(cmd,NormalizeLots(lot),price,sl,tp,comment);

  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool hasDeal(int barCount,ENUM_DEAL_TYPE type)
  {
//---
   datetime from=(TimeCurrent() -(barCount*PeriodSeconds(Timeframe_Main)));
   HistorySelect(from,TimeCurrent());
//---
   for(int k=HistoryDealsTotal()-1; k>=0; k--)
     {
      //---
      ulong ticket=HistoryDealGetTicket(k);
      if(HistoryDealGetString(ticket,DEAL_SYMBOL)!=_Symbol) continue;
      long hist_magic=HistoryDealGetInteger(ticket,DEAL_MAGIC);
      ENUM_DEAL_TYPE hist_order_type=(ENUM_DEAL_TYPE)HistoryDealGetInteger(ticket,DEAL_TYPE);
      //---
      if(hist_magic == Magic && hist_order_type == type)   return true;
      //---
     }

//---
   return false;
//---
  }
//+------------------------------------------------------------------+
