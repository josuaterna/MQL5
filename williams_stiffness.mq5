//+------------------------------------------------------------------+
//|                              Williams Stiffness Strategy Bot MT5 |
//|                                        Copyright 2025, Trading Bot |
//|                                              https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Trading Bot"
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\PositionInfo.mqh>

//--- Input parameters
input group "=== Williams Stiffness Strategy ==="
input bool EnableTrading = true;         // Enable Trading
input double BaseLotSize = 0.01;         // Base Lot Size
input double RiskPercent = 2.0;          // Risk per trade (%)
input double TakeProfitRatio = 1.5;      // Take Profit Ratio (1:X)
input int MaxPositions = 1;              // Maximum positions

input group "=== Williams Percent Range ==="
input int WPR_Period = 14;               // WPR Period
input int WPR_MA_Period = 10;            // WPR Moving Average Period
input ENUM_MA_METHOD WPR_MA_Method = MODE_SMA; // WPR MA Method

input group "=== Trend Acam (Baseline) ==="
input int Acam_FastPeriod = 10;          // Fast Period
input int Acam_SlowPeriod = 21;          // Slow Period
input ENUM_MA_METHOD Acam_Method = MODE_EMA; // MA Method

input group "=== Coppock Curve ==="
input int Coppock_WMA_Length = 10;       // WMA Length
input int Coppock_Long_RoC = 14;         // Long RoC Length
input int Coppock_Short_RoC = 11;        // Short RoC Length

input group "=== Stiffness Index ==="
input int Stiffness_Period1 = 100;       // Period 1
input ENUM_MA_METHOD Stiffness_Method1 = MODE_SMA; // MA Method 1
input int Stiffness_Period3 = 60;        // Summation Period
input int Stiffness_Period2 = 3;         // Period 2
input ENUM_MA_METHOD Stiffness_Method2 = MODE_SMA; // MA Method 2
input double Stiffness_Threshold = 10.0; // Stiffness Threshold

input group "=== ATR Settings ==="
input int ATR_Period = 14;               // ATR Period
input double ATR_Multiplier = 2.5;       // ATR Multiplier for Stop Loss

input group "=== Timeframe Settings ==="
input ENUM_TIMEFRAMES Trading_Timeframe = PERIOD_H1; // Trading Timeframe

//--- Global variables
CTrade trade;
CSymbolInfo symbolInfo;
CPositionInfo positionInfo;

// Indicator handles
int handle_WPR;
int handle_WPR_MA;
int handle_Acam_Fast;
int handle_Acam_Slow;
int handle_Coppock_Long_RoC;
int handle_Coppock_Short_RoC;
int handle_ATR;

// Indicator buffers
double wpr_buffer[];
double wpr_ma_buffer[];
double acam_fast_buffer[];
double acam_slow_buffer[];
double coppock_long_roc_buffer[];
double coppock_short_roc_buffer[];
double atr_buffer[];
double stiffness_buffer[];
double coppock_buffer[];

// Custom calculation variables
double stiffness_data[];
double stiffness_ma_buffer[];

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    Print("Initializing Williams Stiffness Strategy Bot...");
    
    // Initialize indicator handles
    handle_WPR = iWPR(_Symbol, Trading_Timeframe, WPR_Period);
    handle_Acam_Fast = iMA(_Symbol, Trading_Timeframe, Acam_FastPeriod, 0, Acam_Method, PRICE_CLOSE);
    handle_Acam_Slow = iMA(_Symbol, Trading_Timeframe, Acam_SlowPeriod, 0, Acam_Method, PRICE_CLOSE);
    handle_ATR = iATR(_Symbol, Trading_Timeframe, ATR_Period);
    
    // Rate of Change handles for Coppock Curve
    handle_Coppock_Long_RoC = iMomentum(_Symbol, Trading_Timeframe, Coppock_Long_RoC, PRICE_CLOSE);
    handle_Coppock_Short_RoC = iMomentum(_Symbol, Trading_Timeframe, Coppock_Short_RoC, PRICE_CLOSE);
    
    // Check handles
    if(handle_WPR == INVALID_HANDLE || handle_Acam_Fast == INVALID_HANDLE || 
       handle_Acam_Slow == INVALID_HANDLE || handle_ATR == INVALID_HANDLE ||
       handle_Coppock_Long_RoC == INVALID_HANDLE || handle_Coppock_Short_RoC == INVALID_HANDLE) {
        Print("Failed to initialize indicators");
        return(INIT_FAILED);
    }
    
    // Initialize arrays
    ArraySetAsSeries(wpr_buffer, true);
    ArraySetAsSeries(wpr_ma_buffer, true);
    ArraySetAsSeries(acam_fast_buffer, true);
    ArraySetAsSeries(acam_slow_buffer, true);
    ArraySetAsSeries(coppock_long_roc_buffer, true);
    ArraySetAsSeries(coppock_short_roc_buffer, true);
    ArraySetAsSeries(atr_buffer, true);
    ArraySetAsSeries(stiffness_buffer, true);
    ArraySetAsSeries(stiffness_data, true);
    ArraySetAsSeries(stiffness_ma_buffer, true);
    ArraySetAsSeries(coppock_buffer, true);
    
    Print("Williams Stiffness Strategy Bot initialized successfully");
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                               |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    Print("Deinitializing Williams Stiffness Strategy Bot...");
    
    // Release indicator handles
    if(handle_WPR != INVALID_HANDLE) IndicatorRelease(handle_WPR);
    if(handle_Acam_Fast != INVALID_HANDLE) IndicatorRelease(handle_Acam_Fast);
    if(handle_Acam_Slow != INVALID_HANDLE) IndicatorRelease(handle_Acam_Slow);
    if(handle_ATR != INVALID_HANDLE) IndicatorRelease(handle_ATR);
    if(handle_Coppock_Long_RoC != INVALID_HANDLE) IndicatorRelease(handle_Coppock_Long_RoC);
    if(handle_Coppock_Short_RoC != INVALID_HANDLE) IndicatorRelease(handle_Coppock_Short_RoC);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
    // Update indicator data
    if(!UpdateIndicatorData()) return;
    
    // Calculate custom indicators
    CalculateWPR_MA();
    CalculateCoppockCurve();
    CalculateStiffnessIndex();
    
    // Check for new signals
    CheckTradingSignals();
    
    // Manage existing positions
    ManagePositions();
}

//+------------------------------------------------------------------+
//| Update indicator data                                           |
//+------------------------------------------------------------------+
bool UpdateIndicatorData() {
    // Copy indicator data
    if(CopyBuffer(handle_WPR, 0, 0, 200, wpr_buffer) <= 0) return false;
    if(CopyBuffer(handle_Acam_Fast, 0, 0, 200, acam_fast_buffer) <= 0) return false;
    if(CopyBuffer(handle_Acam_Slow, 0, 0, 200, acam_slow_buffer) <= 0) return false;
    if(CopyBuffer(handle_ATR, 0, 0, 50, atr_buffer) <= 0) return false;
    if(CopyBuffer(handle_Coppock_Long_RoC, 0, 0, 200, coppock_long_roc_buffer) <= 0) return false;
    if(CopyBuffer(handle_Coppock_Short_RoC, 0, 0, 200, coppock_short_roc_buffer) <= 0) return false;
    
    return true;
}

//+------------------------------------------------------------------+
//| Calculate WPR Moving Average                                    |
//+------------------------------------------------------------------+
void CalculateWPR_MA() {
    ArrayResize(wpr_ma_buffer, ArraySize(wpr_buffer));
    
    for(int i = 0; i < ArraySize(wpr_buffer) - WPR_MA_Period; i++) {
        double sum = 0;
        for(int j = 0; j < WPR_MA_Period; j++) {
            sum += wpr_buffer[i + j];
        }
        wpr_ma_buffer[i] = sum / WPR_MA_Period;
    }
}

//+------------------------------------------------------------------+
//| Calculate Coppock Curve                                        |
//+------------------------------------------------------------------+
void CalculateCoppockCurve() {
    ArrayResize(coppock_buffer, ArraySize(coppock_long_roc_buffer));
    
    // Convert Momentum to RoC percentage
    double long_roc[];
    double short_roc[];
    ArrayResize(long_roc, ArraySize(coppock_long_roc_buffer));
    ArrayResize(short_roc, ArraySize(coppock_short_roc_buffer));
    
    // Calculate RoC from Momentum
    for(int i = 0; i < ArraySize(coppock_long_roc_buffer); i++) {
        long_roc[i] = (coppock_long_roc_buffer[i] - 100.0);
        short_roc[i] = (coppock_short_roc_buffer[i] - 100.0);
    }
    
    // Calculate Coppock Curve (WMA of sum of RoCs)
    for(int i = 0; i < ArraySize(coppock_buffer) - Coppock_WMA_Length; i++) {
        double sum = 0;
        double weight_sum = 0;
        
        for(int j = 0; j < Coppock_WMA_Length; j++) {
            double weight = Coppock_WMA_Length - j;
            sum += (long_roc[i + j] + short_roc[i + j]) * weight;
            weight_sum += weight;
        }
        
        coppock_buffer[i] = weight_sum > 0 ? sum / weight_sum : 0;
    }
}

//+------------------------------------------------------------------+
//| Calculate Stiffness Index                                       |
//+------------------------------------------------------------------+
void CalculateStiffnessIndex() {
    ArrayResize(stiffness_data, 200);
    ArrayResize(stiffness_buffer, 200);
    ArrayResize(stiffness_ma_buffer, 200);
    
    MqlRates rates[];
    if(CopyRates(_Symbol, Trading_Timeframe, 0, 200, rates) < 200) return;
    
    // Calculate MA and StDev for Stiffness
    for(int i = Stiffness_Period1; i < ArraySize(rates); i++) {
        // Calculate MA
        double ma_sum = 0;
        for(int j = 0; j < Stiffness_Period1; j++) {
            ma_sum += rates[i - j].close;
        }
        double ma1 = ma_sum / Stiffness_Period1;
        
        // Calculate StDev
        double stdev_sum = 0;
        for(int j = 0; j < Stiffness_Period1; j++) {
            stdev_sum += MathPow(rates[i - j].close - ma1, 2);
        }
        double stdev = MathSqrt(stdev_sum / (Stiffness_Period1 - 1));
        
        // Calculate Temp value
        double temp = ma1 - 0.2 * stdev;
        
        // Set data point
        int data_index = ArraySize(rates) - 1 - i;
        stiffness_data[data_index] = rates[i].close > temp ? 1 : 0;
    }
    
    // Calculate Stiffness Index
    for(int i = 0; i < ArraySize(stiffness_data) - Stiffness_Period3; i++) {
        double sum = 0;
        for(int j = 0; j < Stiffness_Period3; j++) {
            sum += stiffness_data[i + j];
        }
        stiffness_buffer[i] = sum * Stiffness_Period1 / Stiffness_Period3;
    }
    
    // Calculate Stiffness MA (Signal line)
    for(int i = 0; i < ArraySize(stiffness_buffer) - Stiffness_Period2; i++) {
        double sum = 0;
        for(int j = 0; j < Stiffness_Period2; j++) {
            sum += stiffness_buffer[i + j];
        }
        stiffness_ma_buffer[i] = sum / Stiffness_Period2;
    }
}

//+------------------------------------------------------------------+
//| Get Trend Direction from Acam                                  |
//+------------------------------------------------------------------+
int GetTrendDirection() {
    if(ArraySize(acam_fast_buffer) < 2 || ArraySize(acam_slow_buffer) < 2) return 0;
    
    double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double fast_ma = acam_fast_buffer[0];
    double slow_ma = acam_slow_buffer[0];
    
    // Trend Acam logic: Fast MA above Slow MA = uptrend
    if(fast_ma > slow_ma && current_price > fast_ma) {
        return 1; // Uptrend
    } else if(fast_ma < slow_ma && current_price < fast_ma) {
        return -1; // Downtrend
    }
    
    return 0; // No clear trend
}

//+------------------------------------------------------------------+
//| Check WPR Confirmation                                          |
//+------------------------------------------------------------------+
bool CheckWPRConfirmation(int trend_direction) {
    if(ArraySize(wpr_buffer) < 2 || ArraySize(wpr_ma_buffer) < 2) return false;
    
    double wpr_current = wpr_buffer[0];
    double wpr_ma_current = wpr_ma_buffer[0];
    
    if(trend_direction > 0) {
        // For long: WPR above MA
        return wpr_current > wpr_ma_current;
    } else if(trend_direction < 0) {
        // For short: WPR below MA
        return wpr_current < wpr_ma_current;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Check Coppock Curve Confirmation                               |
//+------------------------------------------------------------------+
bool CheckCoppockConfirmation() {
    if(ArraySize(coppock_buffer) < 2) return false;
    
    double coppock_current = coppock_buffer[0];
    
    // Coppock should be above zero and green (positive)
    return coppock_current > 0;
}

//+------------------------------------------------------------------+
//| Check Stiffness Index Filter                                   |
//+------------------------------------------------------------------+
bool CheckStiffnessFilter() {
    if(ArraySize(stiffness_buffer) < 2) return false;
    
    double stiffness_current = stiffness_buffer[0];
    
    // Stiffness should be above threshold
    return stiffness_current > Stiffness_Threshold;
}

//+------------------------------------------------------------------+
//| Check trading signals                                           |
//+------------------------------------------------------------------+
void CheckTradingSignals() {
    if(!EnableTrading) return;
    
    // Check if we already have a position
    if(PositionsTotal() >= MaxPositions) return;
    
    // Get trend direction
    int trend_direction = GetTrendDirection();
    if(trend_direction == 0) return;
    
    // Check all confirmations
    if(!CheckWPRConfirmation(trend_direction)) return;
    if(!CheckCoppockConfirmation()) return;
    if(!CheckStiffnessFilter()) return;
    
    // All conditions met - execute trade
    if(trend_direction > 0) {
        ExecuteTrade(ORDER_TYPE_BUY, "Williams_Stiffness_Long");
    } else {
        ExecuteTrade(ORDER_TYPE_SELL, "Williams_Stiffness_Short");
    }
}

//+------------------------------------------------------------------+
//| Execute trade                                                   |
//+------------------------------------------------------------------+
void ExecuteTrade(ENUM_ORDER_TYPE order_type, string comment) {
    double lot_size = CalculateLotSize();
    if(lot_size <= 0) return;
    
    double price = (order_type == ORDER_TYPE_BUY) ? 
                   SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 
                   SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    // Calculate Stop Loss using ATR
    double atr = ArraySize(atr_buffer) > 0 ? atr_buffer[0] : 0.0001;
    double stop_loss, take_profit;
    
    if(order_type == ORDER_TYPE_BUY) {
        stop_loss = price - (atr * ATR_Multiplier);
        take_profit = price + (atr * ATR_Multiplier * TakeProfitRatio);
    } else {
        stop_loss = price + (atr * ATR_Multiplier);
        take_profit = price - (atr * ATR_Multiplier * TakeProfitRatio);
    }
    
    // Execute trade
    if(trade.PositionOpen(_Symbol, order_type, lot_size, price, stop_loss, take_profit, comment)) {
        Print("Trade executed: ", _Symbol, " ", EnumToString(order_type), " ", lot_size, " lots");
        Print("Entry: ", price, " SL: ", stop_loss, " TP: ", take_profit);
    } else {
        Print("Failed to execute trade. Error: ", GetLastError());
    }
}

//+------------------------------------------------------------------+
//| Calculate lot size based on risk                               |
//+------------------------------------------------------------------+
double CalculateLotSize() {
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double risk_amount = balance * (RiskPercent / 100.0);
    
    double atr = ArraySize(atr_buffer) > 0 ? atr_buffer[0] : 0.0001;
    double stop_distance = atr * ATR_Multiplier;
    
    double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    
    double money_per_lot = stop_distance / tick_size * tick_value;
    double lot_size = money_per_lot > 0 ? risk_amount / money_per_lot : BaseLotSize;
    
    // Normalize lot size
    double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double step_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    lot_size = MathMax(lot_size, min_lot);
    lot_size = MathMin(lot_size, max_lot);
    lot_size = NormalizeDouble(lot_size / step_lot, 0) * step_lot;
    
    return lot_size;
}

//+------------------------------------------------------------------+
//| Manage existing positions                                       |
//+------------------------------------------------------------------+
void ManagePositions() {
    for(int i = 0; i < PositionsTotal(); i++) {
        if(positionInfo.SelectByIndex(i) && positionInfo.Symbol() == _Symbol) {
            // Check for exit signals based on trend change
            int current_trend = GetTrendDirection();
            
            // Close position if trend reverses
            if((positionInfo.PositionType() == POSITION_TYPE_BUY && current_trend < 0) ||
               (positionInfo.PositionType() == POSITION_TYPE_SELL && current_trend > 0)) {
                trade.PositionClose(positionInfo.Ticket());
                Print("Position closed due to trend reversal");
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Get current indicator values for display                       |
//+------------------------------------------------------------------+
string GetIndicatorStatus() {
    int trend = GetTrendDirection();
    bool wpr_ok = CheckWPRConfirmation(trend);
    bool coppock_ok = CheckCoppockConfirmation();
    bool stiffness_ok = CheckStiffnessFilter();
    
    string status = "Trend: " + (trend > 0 ? "UP" : trend < 0 ? "DOWN" : "NEUTRAL");
    status += " | WPR: " + (wpr_ok ? "OK" : "NO");
    status += " | Coppock: " + (coppock_ok ? "OK" : "NO");
    status += " | Stiffness: " + (stiffness_ok ? "OK" : "NO");
    
    if(ArraySize(stiffness_buffer) > 0) {
        status += " (" + DoubleToString(stiffness_buffer[0], 2) + ")";
    }
    
    return status;
}

//+------------------------------------------------------------------+
//| OnTimer function for status updates                            |
//+------------------------------------------------------------------+
void OnTimer() {
    Comment(GetIndicatorStatus());
}

//+------------------------------------------------------------------+
//| Expert start function                                           |
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
                const int &spread[]) {
    // This EA works on tick, not on calculate
    return rates_total;
}