//+------------------------------------------------------------------+
//|                                        cycle_ratio_v2.0.mq5      |
//| cycle_ratio_v2.0                          Copyright 2016, fxborg |
//|                                   http://fxborg-labo.hateblo.jp/ |
//+------------------------------------------------------------------+
#property copyright "Copyright 2016, fxborg"
#property link      "http://fxborg-labo.hateblo.jp/"
#property version   "2.00"
#property indicator_separate_window
const double PI=3.14159265359;

#property indicator_buffers 13
#property indicator_plots 1
#property indicator_type1   DRAW_COLOR_HISTOGRAM
#property indicator_color1  clrRed,clrOrange,clrLime, clrGreen
#property indicator_width1 6
// Stochastic setting
int InpK=5; // K Period
int InpSlowing=2; // Slowing

input int InpPeriod=10; // Momentum Period
input int InpRSIPeriod=35; // Cycle Period
input double InpSigThreshold=55; // Threshold
input int InpDispMode=1; // Display Mode (1:Line 2:Histogram)

int InpSQPeriod=InpRSIPeriod*2; // Cycle Period
int InpLpfPeriod=8; // Smoothing
double InpThreshold=3.0; // Threshold

double SIG[];
double CLR[];
double RATE[];
double SMOV[];
double MOV[];
double WAV[];
double OSC[];
double SP[];
double UP[];
double RSI[];
double POS[];
double NEG[];
double SRSI[];
double DRSI[];
double HIST[];
double SQ[];
int min_rates_total=InpK+InpSlowing+InpSQPeriod+InpPeriod*2+1;
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {

//--- 
   if(InpDispMode==2)
     {
      PlotIndexSetInteger(0,PLOT_DRAW_TYPE,DRAW_COLOR_HISTOGRAM);
      PlotIndexSetInteger(0,PLOT_LINE_WIDTH,6);
      IndicatorSetDouble(INDICATOR_MAXIMUM,1.0);
     }
   else
     {
      PlotIndexSetInteger(0,PLOT_DRAW_TYPE,DRAW_COLOR_LINE);
      PlotIndexSetInteger(0,PLOT_LINE_WIDTH,2);
      IndicatorSetDouble(INDICATOR_MAXIMUM,100.0);
      IndicatorSetDouble(INDICATOR_MINIMUM,0.0);

     }
//--- 
   SetIndexBuffer(0,HIST,INDICATOR_DATA);
   SetIndexBuffer(1,SQ,INDICATOR_COLOR_INDEX);

   SetIndexBuffer(2,DRSI,INDICATOR_DATA);
   SetIndexBuffer(3,SMOV,INDICATOR_CALCULATIONS);
   SetIndexBuffer(4,MOV,INDICATOR_CALCULATIONS);

   SetIndexBuffer(5,WAV,INDICATOR_CALCULATIONS);
   SetIndexBuffer(6,OSC,INDICATOR_CALCULATIONS);
   SetIndexBuffer(7,RSI,INDICATOR_CALCULATIONS);
   SetIndexBuffer(8,SRSI,INDICATOR_CALCULATIONS);
   SetIndexBuffer(9,SIG,INDICATOR_CALCULATIONS);
   SetIndexBuffer(10,SP,INDICATOR_CALCULATIONS);
   SetIndexBuffer(11,UP,INDICATOR_CALCULATIONS);
   SetIndexBuffer(12,RATE,INDICATOR_CALCULATIONS);
//--- 

   PlotIndexSetDouble(0,PLOT_EMPTY_VALUE,EMPTY_VALUE);

//--- digits
   IndicatorSetInteger(INDICATOR_DIGITS,2);
   return(0);
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
   if(rates_total<=min_rates_total) return(0);
//---
   int begin_pos=min_rates_total;

   first=begin_pos;
   if(first+1<prev_calculated) first=prev_calculated-2;

//---
   for(i=first; i<rates_total && !IsStopped(); i++)
     {

      double dmax=high[ArrayMaximum(high,i-(InpK-1),InpK)];
      double dmin=low[ArrayMinimum(low,i-(InpK-1),InpK)];
      UP[i]=(close[i]-dmin);
      SP[i]=(dmax-dmin);

      dmax=high[ArrayMaximum(high,i-(InpPeriod*2-1),InpPeriod*2)];
      dmin=low[ArrayMinimum(low,i-(InpPeriod*2-1),InpPeriod*2)];
      MOV[i]=0.5*MathAbs(close[i]-close[i-InpPeriod])+(dmax-dmin);

      int i1st=begin_pos+InpSlowing+InpLpfPeriod;
      if(i<=i1st)continue;
      double up=0;
      double sp=0;
      for(int j=0;j<InpSlowing;j++)
        {
         up+=UP[i-j];
         sp+=SP[i-j];
        }

      double osc=(sp==0)?5:10*up/sp;
      OSC[i]=MathRound(osc);

      double a1,b1,c2,c3,c1;

      // SuperSmoother Filter

      a1 = MathExp( -1.414 * PI / InpLpfPeriod );
      b1 = 2 * a1 * MathCos( 1.414*PI / InpLpfPeriod );
      c2 = b1;
      c3 = -a1 * a1;
      c1 = 1 - c2 - c3;
      SMOV[i]=c1 *(MOV[i]+MOV[i-1])/2+c2*SMOV[i-1]+c3*SMOV[i-2];

      int i2nd=i1st+InpSQPeriod+1;
      if(i<=i2nd)continue;
      double wav=0;
      for(int j=0;j<InpSQPeriod;j++)
        {
         wav+=MathAbs(OSC[i-j]-OSC[i-j-1]);
        }
      WAV[i]=wav/InpSQPeriod;
      RATE[i]=(WAV[i])/(SMOV[i]);

      int i3rd=i2nd+InpRSIPeriod+1;
      if(i<=i3rd)continue;
      double sumP=_Point;
      double sumN=_Point;
      for(int j=0;j<InpRSIPeriod;j++)
        {
         double diff=RATE[i-j]-RATE[i-j-1];
         sumP+=(diff>0?diff:0);
         sumN+=(diff<0? -diff:0);
        }
      RSI[i]=100.0-(100/(1.0+sumP/sumN));
      int i4th=i3rd+3;
      if(i<=i4th)continue;
      if(SRSI[i-1]==EMPTY_VALUE)SRSI[i-1]=0;
      if(SRSI[i-2]==EMPTY_VALUE)SRSI[i-2]=0;

      SRSI[i]=c1 *(RSI[i]+RSI[i-1])/2+c2*SRSI[i-1]+c3*SRSI[i-2];

      int i5th=i4th+1;
      if(i<=i5th) continue;
      if((DRSI[i-1]+InpThreshold)<SRSI[i])DRSI[i]=SRSI[i];
      else if((DRSI[i-1]-InpThreshold)>SRSI[i])DRSI[i]=SRSI[i];
      else DRSI[i]=DRSI[i-1];

      int i6th=i5th+1;
      if(i<=i6th) continue;

      if(DRSI[i-1]<DRSI[i]) SIG[i]=1;
      else if(DRSI[i-1]>DRSI[i]) SIG[i]=0;
      else SIG[i]=SIG[i-1];

      if(InpDispMode==2) HIST[i]=1;
      else  HIST[i]=DRSI[i];
      if(DRSI[i]>=InpSigThreshold && SIG[i]==1)SQ[i]=0;
      else if(DRSI[i]<InpSigThreshold && SIG[i]==1)SQ[i]=1;
      else if(DRSI[i]>=InpSigThreshold && SIG[i]==0)SQ[i]=2;
      else SQ[i]=3;
     }
//--- return value of prev_calculated for next call
   return(rates_total);
  }
//+------------------------------------------------------------------+
