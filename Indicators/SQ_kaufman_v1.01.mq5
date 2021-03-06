//+------------------------------------------------------------------+
//|                                              SQ_Kaufman_v1.0.mq5 |
//| SQ_Kaufman v1.01                          Copyright 2015, fxborg |
//|                                  http://blog.livedoor.jp/fxborg/ |
//+------------------------------------------------------------------+
#property copyright "Copyright 2015, fxborg"
#property link      "http://blog.livedoor.jp/fxborg/"
#property version   "1.01"

#property indicator_separate_window
#property indicator_buffers 9
#property indicator_plots   2

#property indicator_type1   DRAW_LINE
#property indicator_color1  DodgerBlue
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrRed


#property indicator_width1 2
#property indicator_width2 1

#property indicator_style2 STYLE_DOT

//---
input ENUM_TIMEFRAMES CalcTF=PERIOD_M5; // Calclation TimeFrame
input int VolatPeriod=7; // Volatility Period
input int SmoothPeriod=3; // Smooth Period
input int SlowPeriod=70; // SlowPeriod 

//---
//input  ENUM_MA_METHOD MaMethod=MODE_EMA; // Ma Method 
//input  ENUM_APPLIED_PRICE MaPriceMode=PRICE_TYPICAL; // Ma Price Mode 

//---
int Scale=PeriodSeconds(PERIOD_CURRENT)/PeriodSeconds(CalcTF);
//---

//---

//---
double SmoothSQBuffer[];
double SlowSQBuffer[];
double SQBuffer[];
double SlowVolatBuffer[];
double SlowStdDevBuffer[];
double BarVolatBuffer[];
double VolatBuffer[];
double MaBuffer[];
double PriceMaBuffer[];

double StdDevBuffer[];
double PriceBuffer[];
//---
//---- declaration of global variables
int min_rates_total;
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {

   if(PeriodSeconds(PERIOD_CURRENT)<PeriodSeconds(CalcTF))
     {
      Alert("Calclation Time Frame is too Large");
      return(INIT_FAILED);
     }
   if(VolatPeriod<5)
     {
      Alert("VolatPeriod is too Small");
      return(INIT_FAILED);
     }

//---- Initialization of variables of data calculation starting point
   min_rates_total=VolatPeriod*10;
//--- indicator buffers mapping
   SetIndexBuffer(0,SmoothSQBuffer,INDICATOR_DATA);
   SetIndexBuffer(1,SlowSQBuffer,INDICATOR_DATA);
   SetIndexBuffer(2,SQBuffer,INDICATOR_CALCULATIONS);
   SetIndexBuffer(3,VolatBuffer,INDICATOR_CALCULATIONS);
   SetIndexBuffer(4,StdDevBuffer,INDICATOR_CALCULATIONS);
   SetIndexBuffer(5,BarVolatBuffer,INDICATOR_CALCULATIONS);
   SetIndexBuffer(6,MaBuffer,INDICATOR_CALCULATIONS);
   SetIndexBuffer(7,PriceBuffer,INDICATOR_CALCULATIONS);
   SetIndexBuffer(8,PriceMaBuffer,INDICATOR_CALCULATIONS);
//--- set drawing line empty value
   PlotIndexSetDouble(0,PLOT_EMPTY_VALUE,0);
   PlotIndexSetDouble(1,PLOT_EMPTY_VALUE,0);
   PlotIndexSetDouble(2,PLOT_EMPTY_VALUE,0);
   PlotIndexSetDouble(3,PLOT_EMPTY_VALUE,0);
   PlotIndexSetDouble(4,PLOT_EMPTY_VALUE,0);
   PlotIndexSetDouble(5,PLOT_EMPTY_VALUE,EMPTY_VALUE);
   PlotIndexSetDouble(6,PLOT_EMPTY_VALUE,0);
   PlotIndexSetDouble(7,PLOT_EMPTY_VALUE,0);
   PlotIndexSetDouble(8,PLOT_EMPTY_VALUE,0);
//---
   PlotIndexSetInteger(0,PLOT_DRAW_BEGIN,min_rates_total);
   PlotIndexSetInteger(1,PLOT_DRAW_BEGIN,min_rates_total);
   PlotIndexSetInteger(2,PLOT_DRAW_BEGIN,min_rates_total);
   PlotIndexSetInteger(3,PLOT_DRAW_BEGIN,min_rates_total);
//---
   IndicatorSetInteger(INDICATOR_DIGITS,_Digits+1);
   string shortname="SQ_Kaufman_v1.01";
   IndicatorSetString(INDICATOR_SHORTNAME,shortname);
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
//---
   int i,first,begin_pos;
   begin_pos=VolatPeriod;
//--- check for bars count
   if(rates_total<=min_rates_total)
      return(0);
//---

   first=begin_pos;

   if(first+1<prev_calculated)
      first=prev_calculated-2;

//---
   for(i=first; i<rates_total && !IsStopped(); i++)
     {
       //---

      //---
      bool isNewBar=(i==rates_total-1);
      //---
      double up_vol=0;
      double dn_vol=0;
      //---
      MqlRates tf_rates[];
      //---
      datetime from=(datetime)(time[i-1]-10);
      datetime to=(isNewBar)?TimeCurrent()+10:(datetime)(time[i+1]-10);
      int tf_rates_total=CopyRates(Symbol(),CalcTF,from,to,tf_rates);
      if(tf_rates_total<1) continue;
      //---
      double dsum=0;
      int tf_bar_count=0;
      for(int pos=0;pos<tf_rates_total;pos++)
        {
         //---
         
         if(tf_rates[pos].time>(time[i]-10))
           {
            double prev_price= tf_rates[pos].open;
            if((tf_bar_count==0 && pos>0 )||tf_bar_count>0)
               prev_price= tf_rates[pos-1].close;

            dsum+=MathAbs(prev_price-tf_rates[pos].close);
            tf_bar_count++;  
           }
         //---
        }
      //---
      BarVolatBuffer[i]=dsum;
      int second=begin_pos+VolatPeriod+SmoothPeriod;
      //---
      if(i<=second)continue;
      double v=0.0;
      for(int j=0;j<VolatPeriod;j++)v+=BarVolatBuffer[i-j];
      VolatBuffer[i]=v;

      //---
      int third=second+VolatPeriod;
      if(i<=third)continue;
      double dmax=high[i];
      double dmin=low[i];
      for(int j=0;j<VolatPeriod;j++)
       {
         if(dmax<high[i-j])dmax=high[i-j];
         if(dmin>low[i-j])dmin=low[i-j];
       }
      SQBuffer[i]=(dmax-dmin)/VolatBuffer[i];
     
      int forth = third+MathMax(SmoothPeriod,SlowPeriod);
      if(i<=forth)continue;
      double avg=0;
      for(int j=0;j<SmoothPeriod;j++)
          avg+=SQBuffer[i-j];
      SmoothSQBuffer[i]=avg/SmoothPeriod;
      avg=0;
      for(int j=0;j<SlowPeriod;j++)
          avg+=SQBuffer[i-j];
      SlowSQBuffer[i]=avg/SlowPeriod;
      
    
      


     }

//--- return value of prev_calculated for next call
   return(rates_total);
  }
