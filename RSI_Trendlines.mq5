//+------------------------------------------------------------------+
//|                                        RSI_Trendlines_Breakouts.mq5 |
//|                                                                     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property link      ""
#property version   "1.00"
#property indicator_separate_window
//#property indicator_chart_window
#property indicator_minimum 0
#property indicator_maximum 100
#property indicator_buffers 8
#property indicator_plots   7
#property indicator_color1  clrSteelBlue
#property indicator_color2  clrRed
#property indicator_color3  clrMediumSeaGreen
#property indicator_color4  clrRed
#property indicator_color5  clrMediumSeaGreen
#property indicator_color6  clrRed
#property indicator_color7  clrMediumSeaGreen
//--- Flechas para señales: 159 - puntos; 233/234 - flechas;
#define ARROW_BUY  159 
#define ARROW_SELL 159
// Indicator buffers
double RSIBuffer[];
double PivotLowBuffer[];
double PivotHighBuffer[];
double TrendlineLowBuffer[];
double TrendlineHighBuffer[];
double BreakoutLowBuffer[];
double BreakoutHighBuffer[];
double WorkBuffer[];
//double pos_buffer[];
//double neg_buffer[];
//--- Valores de los niveles del indicador horizontal.
double up_level   =0;
double down_level =0;
bool pivoth1 = false;
bool pivoth2 = false;
bool pivotl1 = false;
bool pivotl2 = false;
bool breakOuth = false;
bool breakOutl = false;
int posph1 = NULL;
double rsiph1 = NULL;
int posph2 = NULL;
double rsiph2 = NULL;
int pospl1 = NULL;
double rsipl1 = NULL;
int pospl2 = NULL;
double rsipl2 = NULL;
bool isLowPivot = false;
bool isHighPivot = false;
int contador = 0;
// Input parameters
input int                 RSI_Length = 14;          // RSI Length
input int                 Lookback_Range = 10;       // Lookback Range
input ENUM_APPLIED_PRICE RSI_Source = PRICE_CLOSE; // RSI Source
input int                 RSI_Difference = 3;       // RSI Difference
input color              RSI_Color = clrBlue;      // RSI Color
input color              Pivot_Low_Color = clrRed;  // Pivot Low Color
input color              Pivot_High_Color = clrGreen; // Pivot High Color
input int                Line_Width = 2;           // Line Width
input bool               Repainting = false;        // Repainting Mode
input  double           SignalLevel =30;        // Signal Level
//--- Período del indicador
int period_rsi=0;
int start_pos = 0;
// Global variables
int rsi_handle;
datetime lastAlert = 0;
//+------------------------------------------------------------------+
//| Custom indicator initialization function                           |
//+------------------------------------------------------------------+
int OnInit()
{
   if(RSI_Length<1)
     {
      period_rsi=2;
      Print("Incorrect value for input variable PeriodRSI =",RSI_Length,
            "Indicator will use value =",period_rsi,"for calculations.");
     }
   else
   period_rsi=RSI_Length;
    // Create RSI handle
    rsi_handle = iRSI(_Symbol, PERIOD_CURRENT, RSI_Length, RSI_Source);
    if(rsi_handle == INVALID_HANDLE)
    {
        Print("Error creating RSI indicator handle");
        return(INIT_FAILED);
    }
   inicializaBuffers();
   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Custom indicator iteration function                                |
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
   //contador = contador + 1;
   //Print("Cont=", contador, " rates_total=", rates_total, " prev_calculated=", prev_calculated);
   if(rates_total < Lookback_Range+1) return(0);
//   Print("rates_total=",rates_total);
   int copy = CopyBuffer(rsi_handle, 0, 0, rates_total, RSIBuffer);
//   Print("copy=", copy);
   if(copy <= 0) return(0);   
   if(prev_calculated >0){
      start_pos = prev_calculated;
    }else{
       start_pos = rates_total - 200;
    }
   if(!BarsEnough(start_pos))
       return(0);
   datetime fh = 0;
   datetime fh2 = 0;

//   Print("start_pos antes de ciclo: ", start_pos);
   if(prev_calculated<rates_total){
   for(int i = start_pos; i < rates_total && !::IsStopped(); i++)
      {
          isLowPivot = false;
          isHighPivot = false;
          int j = i - Lookback_Range;
          fh = fechaHora(0);
          fh2 = fechaHora(Lookback_Range);
//          Print("prev_calculated=",i," rates_total=", rates_total, " j=",j);
          is_pivotlow(j);
          is_pivothigh(j);
          Print("i=", fh, " j=", fh2, " PL=", isLowPivot, " PH=", isHighPivot, " RSI(",j,")=", RSIBuffer[j]);
          PivotLowBuffer[j] = isLowPivot ? RSIBuffer[j] : NULL;
          PivotHighBuffer[j] = isHighPivot ? RSIBuffer[j] : NULL;
          Print("PivotLowBuffer[j]=", PivotLowBuffer[j], " PivotHighBuffer[j]=", PivotHighBuffer[j], " PL=", isLowPivot, " PH=", isHighPivot, " RSI(",j,")=", RSIBuffer[j]);

           Print("j=", fh2, " pl1=", pivotl1, " pl2=", pivotl2, " pol1=", pospl1, " pol2=", pospl2, " rspl1=", rsipl1, " rspl2=", rsipl2);            
           Print("j=", fh2, " ph1=", pivoth1, " ph2=", pivoth2, " poh1=", posph1, " poh2=", posph2, " rsph1=", rsiph1, " rsph2=", rsiph2);  
           CalculateTrendlinesl(j);
           CalculateTrendlinesh(j);

           Print("j=", fh2, " pl1=", pivotl1, " pl2=", pivotl2, " pol1=", pospl1, " pol2=", pospl2, " rspl1=", rsipl1, " rspl2=", rsipl2);
           Print("j=", fh2, " ph1=", pivoth1, " ph2=", pivoth2, " poh1=", posph1, " poh2=", posph2, " rsph1=", rsiph1, " rsph2=", rsiph2);        
      }
     }
 return(rates_total);
}

//+------------------------------------------------------------------+
//| Check if we have enough bars for calculation                       |
//+------------------------------------------------------------------+
bool BarsEnough(int bars_needed)
{
    return(Bars(_Symbol, PERIOD_CURRENT) >= bars_needed);
}


//--------------------------------------------------------------------------------------------------------  
double getY(int pos1, double rsi1, int pos2, double rsi2, int pos){
   double m = (rsi2-rsi1)/(pos2-pos1);
   double b = rsi1 - m*pos1;
   Print("m=", m, " b=", b, " pos1=", pos1," rsi1=", rsi1," pos2=", pos2," rsi2=", rsi2," pos=", pos);
   Print("Y=", m*pos + b);
   return m*pos + b;
}
//--------------------------------------------------------------------------------------------------------  
datetime fechaHora(int i){
   return iTime(_Symbol, PERIOD_CURRENT, i);
}
//-----------------------------------------------------------------------------
//    PIVOTS
//----------------------------------------------------------------------------  
void is_pivotlow(int j){
    isLowPivot = RSIBuffer[j] > 1 ? true : false;
    int k = j;
    double rsi_eval = RSIBuffer[j];
    //if((RSIBuffer[j-1]- 0.5) > rsi_eval){
    if((RSIBuffer[j-1]) > rsi_eval){
         j= j+1;
         for(j; j < (k + Lookback_Range); j++)
         {
            if(rsi_eval >= RSIBuffer[j]){
               isLowPivot = false;
               continue;
            }
         }
      }else{
          isLowPivot = false;
     }
     Print("PL rsi(",k,")=",  rsi_eval, " rsi(", j, ")=", RSIBuffer[j], " isLowPivot=", isLowPivot);
}
//-------------------------------------------------------------------------------------------------------- 
void is_pivothigh(int j){
    isHighPivot = RSIBuffer[j] > 1 ? true : false;
    int k = j;
    double rsi_eval = RSIBuffer[j];
//    if(RSIBuffer[j-1]+0.5 < rsi_eval){
    if(RSIBuffer[j-1] < rsi_eval){
         j = j + 1;
         for(j; j < (k + Lookback_Range); j++)
         {
            if(rsi_eval <= RSIBuffer[j]){
               isHighPivot = false;
               continue;
            }
         }
      }else{
          isHighPivot = false;
     }
   Print("PH rsi(",k,")=", rsi_eval, " rsi(", j, ")=",RSIBuffer[j], " isHighPivot=", isHighPivot);   
} 

//+------------------------------------------------------------------+
//| Check for breakouts of trendlines                                  |
//+------------------------------------------------------------------+
//void CheckBreakoutsl(int index, const datetime &time[])
void CheckBreakoutsl(int index)
{
    //if(TrendlineLowBuffer[index] != EMPTY_VALUE &&
    //   RSIBuffer[index] <= (TrendlineLowBuffer[index] - RSI_Difference))
    if(RSIBuffer[index] <= (TrendlineLowBuffer[index] - RSI_Difference))
    {
        Print("BreakL:", RSIBuffer[index]);   
        breakOutl = true;
        for(int i = pospl1; i<=index;i++){
            BreakoutLowBuffer[i]=TrendlineLowBuffer[i];
            TrendlineLowBuffer[i]=NULL;
        }
    }
}
//--------------------------------------------------------------------------------------------------------  
//void CheckBreakoutsh(int index, const datetime &time[])
void CheckBreakoutsh(int index)
{
    //if(index < 1) return;
//    if(TrendlineHighBuffer[index] != EMPTY_VALUE &&
       //RSIBuffer[index] >= (TrendlineHighBuffer[index] + RSI_Difference))
    if(RSIBuffer[index] >= (TrendlineHighBuffer[index] + RSI_Difference))
    {
        Print("Breakh:", RSIBuffer[index]);
        breakOuth=true;
        for(int i = posph1; i<=index;i++){
            BreakoutHighBuffer[i]=TrendlineHighBuffer[i];
            TrendlineHighBuffer[i]=NULL;
        }
    }
}
//+------------------------------------------------------------------+
//| Calculate trendlines from pivot points                             |
//+------------------------------------------------------------------+
//void CalculateTrendlinesl(int current_bar, int total_bars, const datetime &time[])
void CalculateTrendlinesl(int i)
{
   int j = 0;
   if(i>0){
      if(!pivotl1 && isLowPivot){
         pivotl1 = true;
         pospl1 = i;
         rsipl1 = PivotLowBuffer[i];
         TrendlineLowBuffer[i] = rsipl1;
       }else if(pivotl1 && !pivotl2 && isLowPivot){
         if(PivotLowBuffer[i] <= (PivotLowBuffer[pospl1]-0.5) || (i - pospl1)>= 12){
            TrendlineLowBuffer[pospl1] = NULL;
            pospl1 = i;
            rsipl1 = PivotLowBuffer[i];    
            TrendlineLowBuffer[i] = rsipl1;
         }else{
            pivotl2 = true;
            pospl2 = i;
            rsipl2 = PivotLowBuffer[i];
            TrendlineLowBuffer[i] = rsipl2;
            j = pospl1;
            Print("pivotl1=", pivotl1, " pivotl2=", pivotl2);
            for(j; j < i + Lookback_Range; j++)
            {
               if (TrendlineLowBuffer[j]==NULL){
                  Print("pospl1=", pospl1," rsipl1=", rsipl1," pospl2=",pospl2," rsipl2=",rsipl2);
                  TrendlineLowBuffer[j] = getY(pospl1,rsipl1,pospl2,rsipl2,j);
                  }
               Print("TL(j)=", TrendlineLowBuffer[j], " TL(j-1)=",TrendlineLowBuffer[j-1]);
               CheckBreakoutsl(j);
               if (breakOutl){
                 pospl1=NULL;
                 pospl2=NULL;
                 rsipl1=NULL;
                 rsipl2=NULL;
                 pivotl1=false;
                 pivotl2=false;
                 breakOutl=false;  
                  continue;
               }
            }
         }
      }else if(pivotl1 && pivotl2){
         j = i +1;
         for(j; j < i + Lookback_Range; j++)
            {
            Print("pivotl1=", pivotl1, " pivotl2=", pivotl2);
            if (TrendlineLowBuffer[j]==NULL){
               Print("pospl1=", pospl1," rsipl1=", rsipl1," pospl2=",pospl2," rsipl2=",rsipl2);
               TrendlineLowBuffer[j] = getY(pospl1,rsipl1,pospl2,rsipl2,j);
               }
            Print("TL(j)=", TrendlineLowBuffer[j], " TL(j-1)=",TrendlineLowBuffer[j-1]);
            CheckBreakoutsl(j);
            if (breakOutl){
              pospl1=NULL;
              pospl2=NULL;
              rsipl1=NULL;
              rsipl2=NULL;
              pivotl1=false;
              pivotl2=false;
              breakOutl=false;
              Print("Reinicio pivotl1=", pivotl1, " pivotl2=", pivotl2);              
               continue;
             }
          }
      }
   }
}


//--------------------------------------------------------------------------------------------------------   
void CalculateTrendlinesh(int i)
{
  int j = 0;
  if(i>0){
         if(!pivoth1 && isHighPivot){
            pivoth1 = true;
            posph1 = i;
            rsiph1 = PivotHighBuffer[i];
            TrendlineHighBuffer[i] = rsiph1;
         }else if(pivoth1 && !pivoth2 && isHighPivot){
            if(PivotHighBuffer[i] >= (PivotHighBuffer[posph1]+0.5) || (i - posph1)>= 12){
               TrendlineHighBuffer[posph1] = NULL;
               posph1 = i;
               rsiph1 = PivotHighBuffer[i];    
               TrendlineHighBuffer[i] = rsiph1;
            }else{
               pivoth2 = true;
               posph2 = i;
               rsiph2 = PivotHighBuffer[i];
               TrendlineHighBuffer[i] = rsiph2;
               j = posph1;
               Print("pivoth1=", pivoth1, " pivoth2=", pivoth2);
               for(j; j < (i + Lookback_Range); j++)
               {
                  if (TrendlineHighBuffer[j]==NULL){
                     TrendlineHighBuffer[j] = getY(posph1,rsiph1,posph2,rsiph2,j);
                  }
                  Print("TH(j)=", TrendlineHighBuffer[j], " TH(j-1)=",TrendlineHighBuffer[j-1]);
                   CheckBreakoutsh(j);
                  if (breakOuth){
                    pivoth1=false;
                    pivoth2=false;  
                    posph1=NULL;
                    posph2=NULL;
                    rsiph1=NULL;
                    rsiph2=NULL;
                    breakOuth=false;
                    Print("Reinicio pivoth1=", pivoth1, " pivoth2=", pivoth2);
                   continue;
                  }                         
               }
            }
         }else if(pivoth1 && pivoth2){
            j = i +1;
            for(j; j < (i + Lookback_Range); j++)
               {
               Print("pivoth1=", pivoth1, " pivoth2=", pivoth2);
               if (TrendlineHighBuffer[j]==NULL){
                  TrendlineHighBuffer[j] = getY(posph1,rsiph1,posph2,rsiph2,j);
                  }
               Print("TH(j)=", TrendlineHighBuffer[j], " TH(j-1)=",TrendlineHighBuffer[j-1]);
               CheckBreakoutsh(j);
               if (breakOuth){
                    pivoth1=false;
                    pivoth2=false;  
                    posph1=NULL;
                    posph2=NULL;
                    rsiph1=NULL;
                    rsiph2=NULL;
                    breakOuth=false;
                   continue;
                  }         
               }
         }else{
         }
  }else{
  }

 }
//--------------------------------------------------------------------------------------------------------   
void inicializaBuffers(){
    // Initialize buffers
    SetIndexBuffer(0, RSIBuffer, INDICATOR_DATA);
    SetIndexBuffer(1, PivotLowBuffer, INDICATOR_DATA);
    SetIndexBuffer(2, PivotHighBuffer, INDICATOR_DATA);
    SetIndexBuffer(3, TrendlineLowBuffer, INDICATOR_DATA);
    SetIndexBuffer(4, TrendlineHighBuffer, INDICATOR_DATA);
    SetIndexBuffer(5, BreakoutLowBuffer, INDICATOR_DATA);
    SetIndexBuffer(6, BreakoutHighBuffer, INDICATOR_DATA);
    SetIndexBuffer(7, WorkBuffer, INDICATOR_CALCULATIONS);
//    SetIndexBuffer(8,pos_buffer,INDICATOR_CALCULATIONS);
//    SetIndexBuffer(9,neg_buffer,INDICATOR_CALCULATIONS);
//--- Inicializando matrices
    ZeroIndicatorBuffers();
    PlotIndexSetInteger(0,PLOT_DRAW_TYPE,DRAW_LINE);
    PlotIndexSetInteger(1,PLOT_DRAW_TYPE,DRAW_ARROW);
    PlotIndexSetInteger(2,PLOT_DRAW_TYPE,DRAW_ARROW);    
    PlotIndexSetInteger(3,PLOT_DRAW_TYPE,DRAW_LINE);
    PlotIndexSetInteger(4,PLOT_DRAW_TYPE,DRAW_LINE);
    PlotIndexSetInteger(5,PLOT_DRAW_TYPE,DRAW_LINE);
    PlotIndexSetInteger(6,PLOT_DRAW_TYPE,DRAW_LINE);    
    PlotIndexSetInteger(1,PLOT_ARROW,ARROW_BUY);
    PlotIndexSetInteger(2,PLOT_ARROW,ARROW_SELL);
    PlotIndexSetInteger(0,PLOT_DRAW_BEGIN,period_rsi);
    PlotIndexSetInteger(1,PLOT_DRAW_BEGIN,period_rsi);
    PlotIndexSetInteger(2,PLOT_DRAW_BEGIN,period_rsi);
    PlotIndexSetInteger(3,PLOT_DRAW_BEGIN,period_rsi);
    PlotIndexSetInteger(4,PLOT_DRAW_BEGIN,period_rsi);
   //--- Número de niveles de indicadores horizontales
   ::IndicatorSetInteger(INDICATOR_LEVELS,2);
//--- Valores de los niveles del indicador horizontal.
   up_level   =100-SignalLevel;
   down_level =SignalLevel;
   ::IndicatorSetDouble(INDICATOR_LEVELVALUE,0,down_level);
   ::IndicatorSetDouble(INDICATOR_LEVELVALUE,1,up_level);
//--- Estilo de línea
   ::IndicatorSetInteger(INDICATOR_LEVELSTYLE,0,STYLE_DOT);
   ::IndicatorSetInteger(INDICATOR_LEVELSTYLE,1,STYLE_DOT);
   PlotIndexSetDouble(0,PLOT_EMPTY_VALUE,0);
   PlotIndexSetDouble(1,PLOT_EMPTY_VALUE,0);
   PlotIndexSetDouble(2,PLOT_EMPTY_VALUE,0);
   PlotIndexSetDouble(3,PLOT_EMPTY_VALUE,0);
   PlotIndexSetDouble(4,PLOT_EMPTY_VALUE,0);
   PlotIndexSetDouble(5,PLOT_EMPTY_VALUE,0);
   PlotIndexSetDouble(6,PLOT_EMPTY_VALUE,0);
   // Set indicator labels
   IndicatorSetString(INDICATOR_SHORTNAME, "RSI Trendlines with Breakouts");
  }
//--------------------------------------------------------------------------------------------------------  

  void ZeroIndicatorBuffers(void)
  {
   ::ArrayInitialize(RSIBuffer,0);
   ::ArrayInitialize(PivotLowBuffer,0);
   ::ArrayInitialize(PivotHighBuffer,0);
   ::ArrayInitialize(TrendlineLowBuffer,0);
   ::ArrayInitialize(TrendlineHighBuffer,0);
  }
  
 //+------------------------------------------------------------------+
//| Custom indicator deinitialization function                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    IndicatorRelease(rsi_handle);
}
//             ResetLastError(); // Reseteamos el error antes de ejecutar
             //int errorCode = GetLastError();
             //if(errorCode!=0){
             //     return(0);
             //     }
             
        //if(lastAlert != time[index])
        //{
        //    Alert("RSI Low Breakout at ", SymbolInfoDouble(_Symbol, SYMBOL_BID));
        //    lastAlert = time[index];
        //}             