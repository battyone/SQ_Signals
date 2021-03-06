//+------------------------------------------------------------------+
//|                                                Boundary_line.mq5 |
//| Boundary Line v1.00                       Copyright 2015, fxborg |
//|                                   http://fxborg-labo.hateblo.jp/ |
//+------------------------------------------------------------------+
#property copyright "Copyright 2015, fxborg"
#property link      "http://fxborg-labo.hateblo.jp/"
#property version   "1.00"

#include <MovingAverages.mqh>

#property indicator_buffers 8
#property indicator_plots   1
#property indicator_chart_window
#property indicator_type1 DRAW_LINE

#property indicator_color1 Gold
#property indicator_width1 2
#property indicator_style1 STYLE_SOLID


//--- input parameters
input double InpScaleFactor=0.75; // Scale factor
input int    InpMaPeriod=3;       // Smooth Period
input int    InpVolatilityPeriod=55; //  Volatility Period

int    InpFastPeriod=int(InpVolatilityPeriod/7); //  Fast Period

//---- will be used as indicator buffers
double MainBuffer[];
double MiddleBuffer[];
double HighBuffer[];
double LowBuffer[];
double CloseBuffer[];
double VolatBuffer[];
double VolatMaBuffer[];
double SmMaBuffer[];
//---- declaration of global variables
int min_rates_total;
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//---- Initialization of variables of data calculation starting point
   min_rates_total=1+InpFastPeriod+InpVolatilityPeriod+InpMaPeriod+InpMaPeriod+1;
//--- indicator buffers mapping

//--- indicator buffers
   SetIndexBuffer(0,MainBuffer,INDICATOR_DATA);
   SetIndexBuffer(1,MiddleBuffer,INDICATOR_DATA);
   SetIndexBuffer(2,SmMaBuffer,INDICATOR_CALCULATIONS);
   SetIndexBuffer(3,HighBuffer,INDICATOR_CALCULATIONS);
   SetIndexBuffer(4,LowBuffer,INDICATOR_CALCULATIONS);
   SetIndexBuffer(5,CloseBuffer,INDICATOR_CALCULATIONS);
   SetIndexBuffer(6,VolatBuffer,INDICATOR_CALCULATIONS);
   SetIndexBuffer(7,VolatMaBuffer,INDICATOR_CALCULATIONS);

//---

   PlotIndexSetDouble(0,PLOT_EMPTY_VALUE,0);
   PlotIndexSetDouble(1,PLOT_EMPTY_VALUE,0);
   PlotIndexSetDouble(2,PLOT_EMPTY_VALUE,0);
   PlotIndexSetDouble(3,PLOT_EMPTY_VALUE,0);
   PlotIndexSetDouble(4,PLOT_EMPTY_VALUE,0);
   PlotIndexSetDouble(5,PLOT_EMPTY_VALUE,0);
   PlotIndexSetDouble(6,PLOT_EMPTY_VALUE,0);
   PlotIndexSetDouble(7,PLOT_EMPTY_VALUE,0);
//---

   PlotIndexSetInteger(0,PLOT_DRAW_BEGIN,min_rates_total);
//---

   string short_name="Boundary Line";

   IndicatorSetString(INDICATOR_SHORTNAME,short_name);

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
   int i,first;
   if(rates_total<=min_rates_total)
      return(0);
//---

//+----------------------------------------------------+
//|Set Median Buffeer                                |
//+----------------------------------------------------+
   int begin_pos=min_rates_total;

   first=begin_pos;
   if(first+1<prev_calculated) first=prev_calculated-2;

//---
   for(i=first; i<rates_total && !IsStopped(); i++)
     {
      int i1st=begin_pos+InpMaPeriod+InpFastPeriod+1;
      if(i<=i1st)continue;
      //---
      double h,l,c;
      //---
      h=SimpleMA(i,InpMaPeriod,high);
      l=SimpleMA(i,InpMaPeriod,low);
      c=SimpleMA(i,InpMaPeriod,close);
      //---
      double prev_ma=(SmMaBuffer[i-1]==0)? SimpleMA(i-1,InpFastPeriod,close):SmMaBuffer[i-1];
      SmMaBuffer[i]=SmoothedMA(i,InpFastPeriod,prev_ma,close);
      //---
      int i2nd=i1st+InpFastPeriod+1;
      if(i<=i2nd)continue;
      //---
      double sum=0.0;
      for(int j=0;j<InpFastPeriod;j++)
         sum+=MathPow(close[i-j]-SmMaBuffer[i],2);
      VolatBuffer[i]=MathSqrt(sum/InpFastPeriod);
      //---
      int i3rd=i2nd+InpVolatilityPeriod+1;
      if(i<=i3rd)continue;
      VolatMaBuffer[i]=SimpleMA(i,InpVolatilityPeriod,VolatBuffer);
      //---
      double v=VolatMaBuffer[i];
      double base=v*InpScaleFactor;
      //--- high
      if((h-base)>HighBuffer[i-1]) HighBuffer[i]=h;
      else if(h+base<HighBuffer[i-1]) HighBuffer[i]=h+base;
      else HighBuffer[i]=HighBuffer[i-1];
      //--- low
      if(l+base<LowBuffer[i-1]) LowBuffer[i]=l;
      else if((l-base)>LowBuffer[i-1]) LowBuffer[i]=l-base;
      else LowBuffer[i]=LowBuffer[i-1];
      //--- middle
      if((c-base/2)>CloseBuffer[i-1]) CloseBuffer[i]=c-base/2;
      else if(c+base/2<CloseBuffer[i-1]) CloseBuffer[i]=c+base/2;
      else CloseBuffer[i]=CloseBuffer[i-1];
      //---
      MiddleBuffer[i]=(HighBuffer[i]+LowBuffer[i]+CloseBuffer[i]*2)/4;
      int i4th=i3rd+InpMaPeriod+1;
      if(i<=i4th)continue;
      //---
      MainBuffer[i]=SimpleMA(i,InpMaPeriod,MiddleBuffer);
     }
//----    

   return(rates_total);
  }
//+------------------------------------------------------------------+
