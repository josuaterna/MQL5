//+------------------------------------------------------------------+
//|                                    Advanced Scalping Bot MT5.mq5 |
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
input group "=== Trading Settings ==="
input string Symbols = "EURUSD,GBPUSD,BTCUSD,XAUUSD"; // Trading symbols
input bool UseM5 = true; // Use 5-minute timeframe
input bool UseM15 = true; // Use 15-minute timeframe
input bool UseM30 = true; // Use 30-minute timeframe
input bool UseH1 = true; // Use 1-hour timeframe
input bool EnableTrading = true; // Enable/Disable Trading
input double BaseLotSize = 0.01; // Base lot size
input double RiskPercent = 2.0; // Risk per trade (%)
input int MaxPositions = 5; // Maximum positions per symbol

input group "=== Martingale Settings ==="
input bool EnableMartingale = true; // Enable Martingale
input double MartingaleMultiplier = 1.5; // Martingale multiplier
input int MaxMartingaleLevels = 3; // Maximum martingale levels
input double MaxDrawdownPercent = 10.0; // Maximum drawdown (%)
input double VaRLimit = 5.0; // Value at Risk limit (%)

input group "=== Moving Averages ==="
input int MA_Period_200 = 200; // MA Period 200
input int MA_Period_20 = 20; // MA Period 20
input int MA_Period_8 = 8; // MA Period 8
input ENUM_MA_METHOD MA_Method = MODE_SMA; // MA Method
input ENUM_APPLIED_PRICE MA_Price = PRICE_CLOSE; // MA Applied Price

input group "=== RSI Settings ==="
input int RSI_Period = 14; // RSI Period
input ENUM_APPLIED_PRICE RSI_Price = PRICE_CLOSE; // RSI Applied Price
input int RSI_Lookback = 4; // RSI Lookback for pivots
input double RSI_Difference = 3.0; // RSI Breakout difference

input group "=== Supply/Demand Settings ==="
input double SD_Threshold = 10.0; // Supply/Demand Threshold (%)
input int SD_Resolution = 50; // Supply/Demand Resolution
input int SD_Bars = 500; // Bars for S/D calculation

input group "=== Triple Barrier Settings ==="
input double TakeProfitMultiplier = 2.0; // Take Profit multiplier
input double StopLossMultiplier = 1.0; // Stop Loss multiplier
input int TrailingStopPoints = 50; // Trailing stop (points)

input group "=== Visualization ==="
input bool ShowMA = true; // Show Moving Averages
input bool ShowRSI = true; // Show RSI
input bool ShowSupplyDemand = true; // Show Supply/Demand zones
input bool ShowBreakouts = true; // Show Breakout signals

input group "=== External Signals ==="
input bool EnableExternalSignals = false; // Enable external signals
input string SignalFile = "trading_signals.csv"; // Signal file path

//--- Global variables
CTrade trade;
CSymbolInfo symbolInfo;
CPositionInfo positionInfo;

string tradingSymbols[];
ENUM_TIMEFRAMES activeTimeframes[];
int symbolCount;
int timeframeCount;
double accountEquity;
double initialBalance;
double currentDrawdown;

//--- Indicator handles
struct IndicatorHandles {
    int ma200, ma20, ma8;
    int rsi;
    double ma200_buffer[], ma20_buffer[], ma8_buffer[];
    double rsi_buffer[];
};

IndicatorHandles handles[];

//--- Supply/Demand structures
struct SupplyDemandZone {
    double topPrice;
    double bottomPrice;
    datetime startTime;
    datetime endTime;
    bool isSupply;
    double volume;
    bool isActive;
};

SupplyDemandZone sdZones[][100]; // Max 100 zones per symbol

//--- RSI Breakout structures
struct RSIBreakout {
    double breakoutLevel;
    datetime breakoutTime;
    bool isBullish;
    bool isActive;
};

RSIBreakout rsiBreakouts[][50]; // Max 50 breakouts per symbol

//--- Position tracking
struct PositionData {
    double entryPrice;
    double lotSize;
    int martingaleLevel;
    datetime entryTime;
    string signal;
};

PositionData positionData[][10]; // Max 10 positions per symbol

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    Print("Initializing Advanced Scalping Bot...");
    
    // Parse trading symbols
    ParseSymbols();
    
    // Setup active timeframes
    SetupTimeframes();
    
    // Initialize arrays
    ArrayResize(handles, symbolCount);
    ArrayResize(sdZones, symbolCount);
    ArrayResize(rsiBreakouts, symbolCount);
    ArrayResize(positionData, symbolCount);
    
    // Initialize indicators for each symbol
    for(int i = 0; i < symbolCount; i++) {
        InitializeIndicators(i);
        if(handles[i].ma200 == INVALID_HANDLE || handles[i].ma20 == INVALID_HANDLE || 
           handles[i].ma8 == INVALID_HANDLE || handles[i].rsi == INVALID_HANDLE) {
            Print("Failed to initialize indicators for ", tradingSymbols[i]);
            return(INIT_FAILED);
        }
    }
    
    // Set initial balance
    initialBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    
    // Set timer for periodic tasks
    EventSetTimer(300);
    
    Print("Bot initialized successfully for ", symbolCount, " symbols and ", timeframeCount, " timeframes");
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                               |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    Print("Deinitializing Advanced Scalping Bot...");
    
    // Release indicator handles
    for(int i = 0; i < symbolCount; i++) {
        if(handles[i].ma200 != INVALID_HANDLE) IndicatorRelease(handles[i].ma200);
        if(handles[i].ma20 != INVALID_HANDLE) IndicatorRelease(handles[i].ma20);
        if(handles[i].ma8 != INVALID_HANDLE) IndicatorRelease(handles[i].ma8);
        if(handles[i].rsi != INVALID_HANDLE) IndicatorRelease(handles[i].rsi);
    }
    
    EventKillTimer();
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
    // Simple tick validation for backtesting
    static datetime lastTime = 0;
    datetime currentTime = TimeCurrent();
    if(currentTime == lastTime) return; // Skip duplicate ticks
    lastTime = currentTime;
    
    // Update account information
    UpdateAccountInfo();
    
    // Check risk management
    if(!CheckRiskManagement()) {
        return;
    }
    
    // Process external signals if enabled (skip in backtesting)
    if(EnableExternalSignals && !MQLInfoInteger(MQL_TESTER)) {
        ProcessExternalSignals();
    }
    
    // Process only first symbol for backtesting performance
    int symbolsToProcess = MQLInfoInteger(MQL_TESTER) ? 1 : symbolCount;
    for(int i = 0; i < symbolsToProcess; i++) {
        ProcessSymbol(i);
    }
}

//+------------------------------------------------------------------+
//| Setup active timeframes based on input settings               |
//+------------------------------------------------------------------+
void SetupTimeframes() {
    timeframeCount = 0;
    
    // Count active timeframes
    if(UseM5) timeframeCount++;
    if(UseM15) timeframeCount++;
    if(UseM30) timeframeCount++;
    if(UseH1) timeframeCount++;
    
    // Setup timeframe array
    ArrayResize(activeTimeframes, timeframeCount);
    int index = 0;
    
    if(UseM5) {
        activeTimeframes[index] = PERIOD_M5;
        index++;
    }
    if(UseM15) {
        activeTimeframes[index] = PERIOD_M15;
        index++;
    }
    if(UseM30) {
        activeTimeframes[index] = PERIOD_M30;
        index++;
    }
    if(UseH1) {
        activeTimeframes[index] = PERIOD_H1;
        index++;
    }
}

//+------------------------------------------------------------------+
//| Parse trading symbols from input string                         |
//+------------------------------------------------------------------+
void ParseSymbols() {
    string symbolStr = Symbols;
    symbolCount = 0;
    
    // Count symbols
    int pos = 0;
    while(pos < StringLen(symbolStr)) {
        int nextComma = StringFind(symbolStr, ",", pos);
        if(nextComma == -1) {
            symbolCount++;
            break;
        }
        symbolCount++;
        pos = nextComma + 1;
    }
    
    // Extract symbols
    ArrayResize(tradingSymbols, symbolCount);
    pos = 0;
    for(int i = 0; i < symbolCount; i++) {
        int nextComma = StringFind(symbolStr, ",", pos);
        if(nextComma == -1) {
            tradingSymbols[i] = StringSubstr(symbolStr, pos);
        } else {
            tradingSymbols[i] = StringSubstr(symbolStr, pos, nextComma - pos);
        }
        pos = nextComma + 1;
        
        // Clean symbol name
        StringTrimLeft(tradingSymbols[i]);
        StringTrimRight(tradingSymbols[i]);
    }
}

//+------------------------------------------------------------------+
//| Initialize indicators for a symbol                              |
//+------------------------------------------------------------------+
void InitializeIndicators(int symbolIndex) {
    string symbol = tradingSymbols[symbolIndex];
    ENUM_TIMEFRAMES timeframe = PERIOD_M5; // Use M5 as default for backtesting
    
    // Use the first active timeframe as primary
    if(timeframeCount > 0) {
        timeframe = activeTimeframes[0];
    }
    
    // Initialize moving averages
    handles[symbolIndex].ma200 = iMA(symbol, timeframe, MA_Period_200, 0, MA_Method, MA_Price);
    handles[symbolIndex].ma20 = iMA(symbol, timeframe, MA_Period_20, 0, MA_Method, MA_Price);
    handles[symbolIndex].ma8 = iMA(symbol, timeframe, MA_Period_8, 0, MA_Method, MA_Price);
    
    // Initialize RSI
    handles[symbolIndex].rsi = iRSI(symbol, timeframe, RSI_Period, RSI_Price);
    
    // Resize buffers to smaller size for backtesting
    ArrayResize(handles[symbolIndex].ma200_buffer, 250);
    ArrayResize(handles[symbolIndex].ma20_buffer, 250);
    ArrayResize(handles[symbolIndex].ma8_buffer, 250);
    ArrayResize(handles[symbolIndex].rsi_buffer, 250);
    
    // Initialize arrays
    ArrayInitialize(handles[symbolIndex].ma200_buffer, 0);
    ArrayInitialize(handles[symbolIndex].ma20_buffer, 0);
    ArrayInitialize(handles[symbolIndex].ma8_buffer, 0);
    ArrayInitialize(handles[symbolIndex].rsi_buffer, 0);
}

//+------------------------------------------------------------------+
//| Update account information                                       |
//+------------------------------------------------------------------+
void UpdateAccountInfo() {
    accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    if(initialBalance > 0) {
        currentDrawdown = (initialBalance - accountEquity) / initialBalance * 100.0;
    }
}

//+------------------------------------------------------------------+
//| Check risk management rules                                      |
//+------------------------------------------------------------------+
bool CheckRiskManagement() {
    // Check maximum drawdown
    if(currentDrawdown > MaxDrawdownPercent) {
        Print("Maximum drawdown exceeded: ", currentDrawdown, "%");
        return false;
    }
    
    // Check VaR limit
    double currentVaR = CalculateVaR();
    if(currentVaR > VaRLimit) {
        Print("VaR limit exceeded: ", currentVaR, "%");
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Calculate Value at Risk                                          |
//+------------------------------------------------------------------+
double CalculateVaR() {
    double totalRisk = 0.0;
    
    for(int i = 0; i < symbolCount; i++) {
        string symbol = tradingSymbols[i];
        for(int j = 0; j < PositionsTotal(); j++) {
            if(positionInfo.SelectByIndex(j) && positionInfo.Symbol() == symbol) {
                double positionRisk = MathAbs(positionInfo.PriceOpen() - positionInfo.StopLoss()) * 
                                    positionInfo.Volume() * SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
                totalRisk += positionRisk;
            }
        }
    }
    
    return accountEquity > 0 ? (totalRisk / accountEquity) * 100.0 : 0.0;
}

//+------------------------------------------------------------------+
//| Process external signals from file                              |
//+------------------------------------------------------------------+
void ProcessExternalSignals() {
    int fileHandle = FileOpen(SignalFile, FILE_READ | FILE_CSV);
    if(fileHandle == INVALID_HANDLE) return;
    
    while(!FileIsEnding(fileHandle)) {
        string symbol = FileReadString(fileHandle);
        string action = FileReadString(fileHandle);
        double confidence = FileReadDouble(fileHandle);
        
        if(confidence > 0.7) { // Process signals with high confidence
            ProcessExternalSignal(symbol, action, confidence);
        }
    }
    
    FileClose(fileHandle);
}

//+------------------------------------------------------------------+
//| Process individual external signal                              |
//+------------------------------------------------------------------+
void ProcessExternalSignal(string symbol, string action, double confidence) {
    // Find symbol index
    int symbolIndex = -1;
    for(int i = 0; i < symbolCount; i++) {
        if(tradingSymbols[i] == symbol) {
            symbolIndex = i;
            break;
        }
    }
    
    if(symbolIndex == -1) return;
    
    // Execute signal based on action
    if(action == "BUY" && confidence > 0.8) {
        ExecuteTrade(symbolIndex, ORDER_TYPE_BUY, "External_Signal");
    } else if(action == "SELL" && confidence > 0.8) {
        ExecuteTrade(symbolIndex, ORDER_TYPE_SELL, "External_Signal");
    }
}

//+------------------------------------------------------------------+
//| Process symbol analysis and trading                             |
//+------------------------------------------------------------------+
void ProcessSymbol(int symbolIndex) {
    string symbol = tradingSymbols[symbolIndex];
    
    // Update indicator data
    UpdateIndicatorData(symbolIndex);
    
    // Calculate Supply/Demand zones
    CalculateSupplyDemandZones(symbolIndex);
    
    // Detect RSI breakouts
    DetectRSIBreakouts(symbolIndex);
    
    // Analyze trend with moving averages
    int trendDirection = AnalyzeTrend(symbolIndex);
    
    // Check for trading opportunities
    CheckTradingOpportunities(symbolIndex, trendDirection);
    
    // Manage existing positions
    ManagePositions(symbolIndex);
    
    // Update visualization if enabled
    if(ShowMA || ShowRSI || ShowSupplyDemand || ShowBreakouts) {
        UpdateVisualization(symbolIndex);
    }
}

//+------------------------------------------------------------------+
//| Update indicator data                                           |
//+------------------------------------------------------------------+
void UpdateIndicatorData(int symbolIndex) {
    // Ensure we have valid handles
    if(handles[symbolIndex].ma200 == INVALID_HANDLE || 
       handles[symbolIndex].ma20 == INVALID_HANDLE ||
       handles[symbolIndex].ma8 == INVALID_HANDLE ||
       handles[symbolIndex].rsi == INVALID_HANDLE) {
        return;
    }
    
    // Copy MA data with error checking
    if(CopyBuffer(handles[symbolIndex].ma200, 0, 0, 250, handles[symbolIndex].ma200_buffer) <= 0) return;
    if(CopyBuffer(handles[symbolIndex].ma20, 0, 0, 250, handles[symbolIndex].ma20_buffer) <= 0) return;
    if(CopyBuffer(handles[symbolIndex].ma8, 0, 0, 250, handles[symbolIndex].ma8_buffer) <= 0) return;
    
    // Copy RSI data with error checking
    if(CopyBuffer(handles[symbolIndex].rsi, 0, 0, 250, handles[symbolIndex].rsi_buffer) <= 0) return;
}

//+------------------------------------------------------------------+
//| Calculate Supply and Demand zones                              |
//+------------------------------------------------------------------+
void CalculateSupplyDemandZones(int symbolIndex) {
    string symbol = tradingSymbols[symbolIndex];
    ENUM_TIMEFRAMES timeframe = PERIOD_M5;
    if(timeframeCount > 0) timeframe = activeTimeframes[0];
    
    MqlRates rates[];
    int barsToAnalyze = MathMin(SD_Bars, 200); // Limit for backtesting performance
    int copied = CopyRates(symbol, timeframe, 0, barsToAnalyze, rates);
    if(copied < 50) return; // Need minimum bars
    
    // Find local highs and lows with volume analysis
    double maxPrice = rates[0].high;
    double minPrice = rates[0].low;
    long totalVolume = 0;
    
    for(int i = 0; i < copied; i++) {
        maxPrice = MathMax(maxPrice, rates[i].high);
        minPrice = MathMin(minPrice, rates[i].low);
        totalVolume += rates[i].tick_volume;
    }
    
    if(totalVolume <= 0 || maxPrice <= minPrice) return; // Avoid division by zero
    
    double range = (maxPrice - minPrice) / MathMin(SD_Resolution, 20); // Limit resolution
    if(range <= 0) return;
    
    // Calculate supply zones (upper levels) - simplified for backtesting
    for(int level = 0; level < MathMin(SD_Resolution, 10); level++) {
        double levelPrice = maxPrice - (level * range);
        long levelVolume = 0;
        
        for(int i = 0; i < copied; i++) {
            if(rates[i].high >= levelPrice && rates[i].high < (levelPrice + range)) {
                levelVolume += rates[i].tick_volume;
            }
        }
        
        double volumePercent = (double)levelVolume / totalVolume * 100.0;
        
        if(volumePercent > SD_Threshold) {
            // Create supply zone
            int zoneIndex = FindEmptyZoneSlot(symbolIndex);
            if(zoneIndex >= 0) {
                sdZones[symbolIndex][zoneIndex].topPrice = levelPrice + range;
                sdZones[symbolIndex][zoneIndex].bottomPrice = levelPrice;
                sdZones[symbolIndex][zoneIndex].isSupply = true;
                sdZones[symbolIndex][zoneIndex].volume = levelVolume;
                sdZones[symbolIndex][zoneIndex].isActive = true;
                sdZones[symbolIndex][zoneIndex].startTime = rates[0].time;
            }
        }
    }
    
    // Calculate demand zones (lower levels) - simplified for backtesting
    for(int level = 0; level < MathMin(SD_Resolution, 10); level++) {
        double levelPrice = minPrice + (level * range);
        long levelVolume = 0;
        
        for(int i = 0; i < copied; i++) {
            if(rates[i].low <= levelPrice && rates[i].low > (levelPrice - range)) {
                levelVolume += rates[i].tick_volume;
            }
        }
        
        double volumePercent = (double)levelVolume / totalVolume * 100.0;
        
        if(volumePercent > SD_Threshold) {
            // Create demand zone
            int zoneIndex = FindEmptyZoneSlot(symbolIndex);
            if(zoneIndex >= 0) {
                sdZones[symbolIndex][zoneIndex].topPrice = levelPrice;
                sdZones[symbolIndex][zoneIndex].bottomPrice = levelPrice - range;
                sdZones[symbolIndex][zoneIndex].isSupply = false;
                sdZones[symbolIndex][zoneIndex].volume = levelVolume;
                sdZones[symbolIndex][zoneIndex].isActive = true;
                sdZones[symbolIndex][zoneIndex].startTime = rates[0].time;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Find empty zone slot                                            |
//+------------------------------------------------------------------+
int FindEmptyZoneSlot(int symbolIndex) {
    for(int i = 0; i < 100; i++) {
        if(!sdZones[symbolIndex][i].isActive) {
            return i;
        }
    }
    return -1;
}

//+------------------------------------------------------------------+
//| Detect RSI breakouts                                           |
//+------------------------------------------------------------------+
void DetectRSIBreakouts(int symbolIndex) {
    if(ArraySize(handles[symbolIndex].rsi_buffer) < RSI_Lookback * 2) return;
    
    string symbol = tradingSymbols[symbolIndex];
    double currentRSI = handles[symbolIndex].rsi_buffer[0];
    
    // Find pivot highs and lows in RSI
    for(int i = RSI_Lookback; i < ArraySize(handles[symbolIndex].rsi_buffer) - RSI_Lookback; i++) {
        bool isPivotHigh = true;
        bool isPivotLow = true;
        
        double centerRSI = handles[symbolIndex].rsi_buffer[i];
        
        // Check for pivot high
        for(int j = i - RSI_Lookback; j <= i + RSI_Lookback; j++) {
            if(j != i && handles[symbolIndex].rsi_buffer[j] >= centerRSI) {
                isPivotHigh = false;
                break;
            }
        }
        
        // Check for pivot low
        for(int j = i - RSI_Lookback; j <= i + RSI_Lookback; j++) {
            if(j != i && handles[symbolIndex].rsi_buffer[j] <= centerRSI) {
                isPivotLow = false;
                break;
            }
        }
        
        // Draw trendlines and detect breakouts
        if(isPivotHigh || isPivotLow) {
            DetectRSITrendlineBreakout(symbolIndex, i, centerRSI, isPivotHigh);
        }
    }
}

//+------------------------------------------------------------------+
//| Detect RSI trendline breakout                                  |
//+------------------------------------------------------------------+
void DetectRSITrendlineBreakout(int symbolIndex, int pivotIndex, double pivotValue, bool isHigh) {
    double currentRSI = handles[symbolIndex].rsi_buffer[0];
    
    // Simple breakout detection
    if(isHigh && currentRSI > (pivotValue + RSI_Difference)) {
        // Bearish breakout (RSI breaking above resistance)
        RecordRSIBreakout(symbolIndex, pivotValue, false);
    } else if(!isHigh && currentRSI < (pivotValue - RSI_Difference)) {
        // Bullish breakout (RSI breaking below support)
        RecordRSIBreakout(symbolIndex, pivotValue, true);
    }
}

//+------------------------------------------------------------------+
//| Record RSI breakout                                             |
//+------------------------------------------------------------------+
void RecordRSIBreakout(int symbolIndex, double breakoutLevel, bool isBullish) {
    for(int i = 0; i < 50; i++) {
        if(!rsiBreakouts[symbolIndex][i].isActive) {
            rsiBreakouts[symbolIndex][i].breakoutLevel = breakoutLevel;
            rsiBreakouts[symbolIndex][i].breakoutTime = TimeCurrent();
            rsiBreakouts[symbolIndex][i].isBullish = isBullish;
            rsiBreakouts[symbolIndex][i].isActive = true;
            break;
        }
    }
}

//+------------------------------------------------------------------+
//| Analyze trend using moving averages                            |
//+------------------------------------------------------------------+
int AnalyzeTrend(int symbolIndex) {
    if(ArraySize(handles[symbolIndex].ma200_buffer) < 3) return 0;
    
    double ma200 = handles[symbolIndex].ma200_buffer[0];
    double ma20 = handles[symbolIndex].ma20_buffer[0];
    double ma8 = handles[symbolIndex].ma8_buffer[0];
    
    string symbol = tradingSymbols[symbolIndex];
    double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
    
    // Determine trend based on MA alignment
    if(ma8 > ma20 && ma20 > ma200 && currentPrice > ma8) {
        return 1; // Strong uptrend
    } else if(ma8 < ma20 && ma20 < ma200 && currentPrice < ma8) {
        return -1; // Strong downtrend
    } else if(currentPrice > ma200) {
        return 2; // Weak uptrend
    } else if(currentPrice < ma200) {
        return -2; // Weak downtrend
    }
    
    return 0; // Sideways
}

//+------------------------------------------------------------------+
//| Check trading opportunities                                     |
//+------------------------------------------------------------------+
void CheckTradingOpportunities(int symbolIndex, int trendDirection) {
    if(!EnableTrading) return;
    
    string symbol = tradingSymbols[symbolIndex];
    double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
    
    // Check if price is in Supply/Demand zone
    bool inSupplyZone = false;
    bool inDemandZone = false;
    
    for(int i = 0; i < 100; i++) {
        if(sdZones[symbolIndex][i].isActive) {
            if(currentPrice >= sdZones[symbolIndex][i].bottomPrice && 
               currentPrice <= sdZones[symbolIndex][i].topPrice) {
                if(sdZones[symbolIndex][i].isSupply) {
                    inSupplyZone = true;
                } else {
                    inDemandZone = true;
                }
            }
        }
    }
    
    // Check for recent RSI breakouts
    bool recentBullishBreakout = false;
    bool recentBearishBreakout = false;
    
    for(int i = 0; i < 50; i++) {
        if(rsiBreakouts[symbolIndex][i].isActive) {
            datetime breakoutAge = TimeCurrent() - rsiBreakouts[symbolIndex][i].breakoutTime;
            if(breakoutAge < 300) { // Recent breakout (5 minutes)
                if(rsiBreakouts[symbolIndex][i].isBullish) {
                    recentBullishBreakout = true;
                } else {
                    recentBearishBreakout = true;
                }
            }
        }
    }
    
    // Trading logic
    if(trendDirection > 0 && inDemandZone && recentBullishBreakout) {
        ExecuteTrade(symbolIndex, ORDER_TYPE_BUY, "Trend_Demand_RSI");
    } else if(trendDirection < 0 && inSupplyZone && recentBearishBreakout) {
        ExecuteTrade(symbolIndex, ORDER_TYPE_SELL, "Trend_Supply_RSI");
    }
}

//+------------------------------------------------------------------+
//| Execute trade with risk management                              |
//+------------------------------------------------------------------+
void ExecuteTrade(int symbolIndex, ENUM_ORDER_TYPE orderType, string signal) {
    string symbol = tradingSymbols[symbolIndex];
    
    // Check maximum positions
    int currentPositions = CountPositions(symbol);
    if(currentPositions >= MaxPositions) return;
    
    // Calculate lot size
    double lotSize = CalculateLotSize(symbolIndex, currentPositions);
    if(lotSize <= 0) return;
    
    // Get current prices
    double price = (orderType == ORDER_TYPE_BUY) ? 
                   SymbolInfoDouble(symbol, SYMBOL_ASK) : 
                   SymbolInfoDouble(symbol, SYMBOL_BID);
    
    // Calculate stop loss and take profit
    double atr = CalculateATR(symbol, 14);
    double stopLoss, takeProfit;
    
    if(orderType == ORDER_TYPE_BUY) {
        stopLoss = price - (atr * StopLossMultiplier);
        takeProfit = price + (atr * TakeProfitMultiplier);
    } else {
        stopLoss = price + (atr * StopLossMultiplier);
        takeProfit = price - (atr * TakeProfitMultiplier);
    }
    
    // Execute trade
    if(trade.PositionOpen(symbol, orderType, lotSize, price, stopLoss, takeProfit, signal)) {
        Print("Trade executed: ", symbol, " ", EnumToString(orderType), " ", lotSize, " lots");
        
        // Record position data
        RecordPositionData(symbolIndex, price, lotSize, currentPositions, signal);
    }
}

//+------------------------------------------------------------------+
//| Calculate lot size with martingale                             |
//+------------------------------------------------------------------+
double CalculateLotSize(int symbolIndex, int currentLevel) {
    double baseLot = BaseLotSize;
    
    if(EnableMartingale && currentLevel > 0 && currentLevel <= MaxMartingaleLevels) {
        baseLot = BaseLotSize * MathPow(MartingaleMultiplier, currentLevel);
    }
    
    // Risk-based position sizing
    double riskAmount = accountEquity * (RiskPercent / 100.0);
    string symbol = tradingSymbols[symbolIndex];
    double atr = CalculateATR(symbol, 14);
    double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
    double maxLotByRisk = riskAmount / (atr * tickValue);
    
    return MathMin(baseLot, maxLotByRisk);
}

//+------------------------------------------------------------------+
//| Calculate ATR                                                   |
//+------------------------------------------------------------------+
double CalculateATR(string symbol, int period) {
    ENUM_TIMEFRAMES timeframe = timeframeCount > 0 ? activeTimeframes[0] : PERIOD_CURRENT;
    int atrHandle = iATR(symbol, timeframe, period);
    if(atrHandle == INVALID_HANDLE) return 0.0001;
    
    double atrBuffer[];
    ArrayResize(atrBuffer, 1);
    
    if(CopyBuffer(atrHandle, 0, 0, 1, atrBuffer) > 0) {
        IndicatorRelease(atrHandle);
        return atrBuffer[0];
    }
    
    IndicatorRelease(atrHandle);
    return 0.0001; // Default small value
}

//+------------------------------------------------------------------+
//| Count positions for symbol                                      |
//+------------------------------------------------------------------+
int CountPositions(string symbol) {
    int count = 0;
    for(int i = 0; i < PositionsTotal(); i++) {
        if(positionInfo.SelectByIndex(i) && positionInfo.Symbol() == symbol) {
            count++;
        }
    }
    return count;
}

//+------------------------------------------------------------------+
//| Record position data                                            |
//+------------------------------------------------------------------+
void RecordPositionData(int symbolIndex, double entryPrice, double lotSize, int level, string signal) {
    for(int i = 0; i < 10; i++) {
        if(positionData[symbolIndex][i].lotSize == 0) {
            positionData[symbolIndex][i].entryPrice = entryPrice;
            positionData[symbolIndex][i].lotSize = lotSize;
            positionData[symbolIndex][i].martingaleLevel = level;
            positionData[symbolIndex][i].entryTime = TimeCurrent();
            positionData[symbolIndex][i].signal = signal;
            break;
        }
    }
}

//+------------------------------------------------------------------+
//| Manage existing positions                                       |
//+------------------------------------------------------------------+
void ManagePositions(int symbolIndex) {
    string symbol = tradingSymbols[symbolIndex];
    
    for(int i = 0; i < PositionsTotal(); i++) {
        if(positionInfo.SelectByIndex(i) && positionInfo.Symbol() == symbol) {
            // Implement trailing stop
            if(TrailingStopPoints > 0) {
                ApplyTrailingStop(symbol, TrailingStopPoints);
            }
            
            // Check for position management based on time
            datetime positionAge = TimeCurrent() - positionInfo.Time();
            if(positionAge > 3600) { // Close positions older than 1 hour
                trade.PositionClose(positionInfo.Ticket());
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Apply trailing stop                                             |
//+------------------------------------------------------------------+
void ApplyTrailingStop(string symbol, int trailingPoints) {
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    double trailingStop = trailingPoints * point;
    
    for(int i = 0; i < PositionsTotal(); i++) {
        if(positionInfo.SelectByIndex(i) && positionInfo.Symbol() == symbol) {
            double currentPrice = (positionInfo.PositionType() == POSITION_TYPE_BUY) ?
                                 SymbolInfoDouble(symbol, SYMBOL_BID) :
                                 SymbolInfoDouble(symbol, SYMBOL_ASK);
            
            double newStopLoss = 0;
            
            if(positionInfo.PositionType() == POSITION_TYPE_BUY) {
                newStopLoss = currentPrice - trailingStop;
                if(newStopLoss > positionInfo.StopLoss()) {
                    trade.PositionModify(positionInfo.Ticket(), newStopLoss, positionInfo.TakeProfit());
                }
            } else {
                newStopLoss = currentPrice + trailingStop;
                if(newStopLoss < positionInfo.StopLoss() || positionInfo.StopLoss() == 0) {
                    trade.PositionModify(positionInfo.Ticket(), newStopLoss, positionInfo.TakeProfit());
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Update visualization                                             |
//+------------------------------------------------------------------+
void UpdateVisualization(int symbolIndex) {
    string symbol = tradingSymbols[symbolIndex];
    string prefix = "ScalpBot_" + symbol + "_";
    
    // Clean old objects
    CleanOldObjects(prefix);
    
    if(ShowMA) {
        DrawMovingAverages(symbolIndex, prefix);
    }
    
    if(ShowSupplyDemand) {
        DrawSupplyDemandZones(symbolIndex, prefix);
    }
    
    if(ShowBreakouts) {
        DrawRSIBreakouts(symbolIndex, prefix);
    }
    
    if(ShowRSI) {
        DrawRSIIndicator(symbolIndex, prefix);
    }
}

//+------------------------------------------------------------------+
//| Clean old visualization objects                                 |
//+------------------------------------------------------------------+
void CleanOldObjects(string prefix) {
    int totalObjects = ObjectsTotal(0);
    for(int i = totalObjects - 1; i >= 0; i--) {
        string objName = ObjectName(0, i);
        if(StringFind(objName, prefix) == 0) {
            ObjectDelete(0, objName);
        }
    }
}

//+------------------------------------------------------------------+
//| Draw moving averages on chart                                  |
//+------------------------------------------------------------------+
void DrawMovingAverages(int symbolIndex, string prefix) {
    if(ArraySize(handles[symbolIndex].ma200_buffer) < 2) return;
    
    // Draw MA lines
    if(handles[symbolIndex].ma200_buffer[0] > 0) {
        string objName = prefix + "MA200_" + IntegerToString(TimeCurrent());
        ObjectCreate(0, objName, OBJ_HLINE, 0, 0, handles[symbolIndex].ma200_buffer[0]);
        ObjectSetInteger(0, objName, OBJPROP_COLOR, clrBlue);
        ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);
        ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
    }
    
    if(handles[symbolIndex].ma20_buffer[0] > 0) {
        string objName = prefix + "MA20_" + IntegerToString(TimeCurrent());
        ObjectCreate(0, objName, OBJ_HLINE, 0, 0, handles[symbolIndex].ma20_buffer[0]);
        ObjectSetInteger(0, objName, OBJPROP_COLOR, clrRed);
        ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
    }
    
    if(handles[symbolIndex].ma8_buffer[0] > 0) {
        string objName = prefix + "MA8_" + IntegerToString(TimeCurrent());
        ObjectCreate(0, objName, OBJ_HLINE, 0, 0, handles[symbolIndex].ma8_buffer[0]);
        ObjectSetInteger(0, objName, OBJPROP_COLOR, clrYellow);
        ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
    }
}

//+------------------------------------------------------------------+
//| Draw Supply and Demand zones                                   |
//+------------------------------------------------------------------+
void DrawSupplyDemandZones(int symbolIndex, string prefix) {
    for(int i = 0; i < 100; i++) {
        if(sdZones[symbolIndex][i].isActive) {
            string objName = prefix + "SD_Zone_" + IntegerToString(i);
            
            datetime timeNow = TimeCurrent();
            datetime timeEnd = timeNow + 3600; // 1 hour ahead
            
            ObjectCreate(0, objName, OBJ_RECTANGLE, 0, 
                        sdZones[symbolIndex][i].startTime, sdZones[symbolIndex][i].topPrice,
                        timeEnd, sdZones[symbolIndex][i].bottomPrice);
            
            if(sdZones[symbolIndex][i].isSupply) {
                ObjectSetInteger(0, objName, OBJPROP_COLOR, clrRed);
                ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, clrRed);
            } else {
                ObjectSetInteger(0, objName, OBJPROP_COLOR, clrGreen);
                ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, clrGreen);
            }
            
            ObjectSetInteger(0, objName, OBJPROP_FILL, true);
            ObjectSetInteger(0, objName, OBJPROP_BACK, true);
            ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
        }
    }
}

//+------------------------------------------------------------------+
//| Draw RSI breakout signals                                      |
//+------------------------------------------------------------------+
void DrawRSIBreakouts(int symbolIndex, string prefix) {
    string symbol = tradingSymbols[symbolIndex];
    double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
    
    for(int i = 0; i < 50; i++) {
        if(rsiBreakouts[symbolIndex][i].isActive) {
            datetime breakoutAge = TimeCurrent() - rsiBreakouts[symbolIndex][i].breakoutTime;
            if(breakoutAge < 1800) { // Show breakouts from last 30 minutes
                string objName = prefix + "RSI_Breakout_" + IntegerToString(i);
                
                ObjectCreate(0, objName, OBJ_ARROW, 0, 
                           rsiBreakouts[symbolIndex][i].breakoutTime, currentPrice);
                
                if(rsiBreakouts[symbolIndex][i].isBullish) {
                    ObjectSetInteger(0, objName, OBJPROP_ARROWCODE, 233); // Up arrow
                    ObjectSetInteger(0, objName, OBJPROP_COLOR, clrLime);
                } else {
                    ObjectSetInteger(0, objName, OBJPROP_ARROWCODE, 234); // Down arrow
                    ObjectSetInteger(0, objName, OBJPROP_COLOR, clrRed);
                }
                
                ObjectSetInteger(0, objName, OBJPROP_WIDTH, 3);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Draw RSI indicator values as text                              |
//+------------------------------------------------------------------+
void DrawRSIIndicator(int symbolIndex, string prefix) {
    if(ArraySize(handles[symbolIndex].rsi_buffer) > 0) {
        string objName = prefix + "RSI_Value";
        double currentRSI = handles[symbolIndex].rsi_buffer[0];
        
        ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, 10);
        ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, 50 + (symbolIndex * 20));
        ObjectSetString(0, objName, OBJPROP_TEXT, 
                       tradingSymbols[symbolIndex] + " RSI: " + DoubleToString(currentRSI, 2));
        ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 9);
        
        // Color based on RSI levels
        if(currentRSI > 70) {
            ObjectSetInteger(0, objName, OBJPROP_COLOR, clrRed);
        } else if(currentRSI < 30) {
            ObjectSetInteger(0, objName, OBJPROP_COLOR, clrLime);
        } else {
            ObjectSetInteger(0, objName, OBJPROP_COLOR, clrWhite);
        }
    }
}

//+------------------------------------------------------------------+
//| Timer function for periodic tasks                              |
//+------------------------------------------------------------------+
void OnTimer() {
    // Clean expired zones and breakouts
    CleanExpiredData();
    
    // Update performance metrics
    UpdatePerformanceMetrics();
    
    // Check for external signal updates (only in live trading)
    if(EnableExternalSignals && !MQLInfoInteger(MQL_TESTER)) {
        ProcessExternalSignals();
    }
}

//+------------------------------------------------------------------+
//| Clean expired data                                             |
//+------------------------------------------------------------------+
void CleanExpiredData() {
    datetime currentTime = TimeCurrent();
    
    for(int s = 0; s < symbolCount; s++) {
        // Clean old supply/demand zones (older than 24 hours)
        for(int i = 0; i < 100; i++) {
            if(sdZones[s][i].isActive) {
                if(currentTime - sdZones[s][i].startTime > 86400) {
                    sdZones[s][i].isActive = false;
                }
            }
        }
        
        // Clean old RSI breakouts (older than 1 hour)
        for(int i = 0; i < 50; i++) {
            if(rsiBreakouts[s][i].isActive) {
                if(currentTime - rsiBreakouts[s][i].breakoutTime > 3600) {
                    rsiBreakouts[s][i].isActive = false;
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Update performance metrics                                      |
//+------------------------------------------------------------------+
void UpdatePerformanceMetrics() {
    double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    double totalProfit = 0;
    int totalTrades = 0;
    int winningTrades = 0;
    
    // Calculate performance statistics
    if(HistorySelect(0, TimeCurrent())) {
        for(int i = 0; i < HistoryDealsTotal(); i++) {
            ulong ticket = HistoryDealGetTicket(i);
            if(ticket > 0) {
                double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
                if(profit != 0) {
                    totalProfit += profit;
                    totalTrades++;
                    if(profit > 0) winningTrades++;
                }
            }
        }
    }
    
    // Log performance every hour
    static datetime lastReport = 0;
    if(TimeCurrent() - lastReport > 3600) {
        double winRate = totalTrades > 0 ? (double)winningTrades / totalTrades * 100 : 0;
        Print("Performance Report - Equity: ", currentEquity, 
              ", Total Profit: ", totalProfit,
              ", Win Rate: ", winRate, "%",
              ", Drawdown: ", currentDrawdown, "%");
        lastReport = TimeCurrent();
    }
}

//+------------------------------------------------------------------+
//| Chart event handler                                            |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam) {
    if(id == CHARTEVENT_OBJECT_CLICK) {
        // Handle user interactions with visualization objects
        if(StringFind(sparam, "ScalpBot_") == 0) {
            Print("Clicked on visualization object: ", sparam);
        }
    }
}

//+------------------------------------------------------------------+
//| Trade event handler                                            |
//+------------------------------------------------------------------+
void OnTrade() {
    // Handle trade events for position tracking
    static int lastPositionCount = 0;
    int currentPositionCount = PositionsTotal();
    
    if(currentPositionCount != lastPositionCount) {
        Print("Position count changed: ", lastPositionCount, " -> ", currentPositionCount);
        
        // Update position tracking arrays
        for(int s = 0; s < symbolCount; s++) {
            UpdatePositionTracking(s);
        }
        
        lastPositionCount = currentPositionCount;
    }
}

//+------------------------------------------------------------------+
//| Update position tracking for symbol                            |
//+------------------------------------------------------------------+
void UpdatePositionTracking(int symbolIndex) {
    string symbol = tradingSymbols[symbolIndex];
    
    // Reset position data array
    for(int i = 0; i < 10; i++) {
        positionData[symbolIndex][i].lotSize = 0;
    }
    
    // Rebuild from current positions
    int posIndex = 0;
    for(int i = 0; i < PositionsTotal(); i++) {
        if(positionInfo.SelectByIndex(i) && positionInfo.Symbol() == symbol) {
            if(posIndex < 10) {
                positionData[symbolIndex][posIndex].entryPrice = positionInfo.PriceOpen();
                positionData[symbolIndex][posIndex].lotSize = positionInfo.Volume();
                positionData[symbolIndex][posIndex].entryTime = positionInfo.Time();
                positionData[symbolIndex][posIndex].signal = positionInfo.Comment();
                posIndex++;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Get trading statistics                                          |
//+------------------------------------------------------------------+
string GetTradingStatistics() {
    double totalProfit = 0;
    int totalTrades = 0;
    int winningTrades = 0;
    double maxProfit = 0;
    double maxLoss = 0;
    
    if(HistorySelect(0, TimeCurrent())) {
        for(int i = 0; i < HistoryDealsTotal(); i++) {
            ulong ticket = HistoryDealGetTicket(i);
            if(ticket > 0) {
                double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
                if(profit != 0) {
                    totalProfit += profit;
                    totalTrades++;
                    if(profit > 0) {
                        winningTrades++;
                        maxProfit = MathMax(maxProfit, profit);
                    } else {
                        maxLoss = MathMin(maxLoss, profit);
                    }
                }
            }
        }
    }
    
    double winRate = totalTrades > 0 ? (double)winningTrades / totalTrades * 100 : 0;
    double avgProfit = totalTrades > 0 ? totalProfit / totalTrades : 0;
    
    return StringFormat("Stats: Trades=%d, WinRate=%.1f%%, Profit=%.2f, AvgProfit=%.2f, MaxProfit=%.2f, MaxLoss=%.2f",
                       totalTrades, winRate, totalProfit, avgProfit, maxProfit, maxLoss);
}

//+------------------------------------------------------------------+
//| Export trading data for ML analysis                            |
//+------------------------------------------------------------------+
void ExportTradingData() {
    string filename = "trading_data_" + TimeToString(TimeCurrent(), TIME_DATE) + ".csv";
    int fileHandle = FileOpen(filename, FILE_WRITE | FILE_CSV);
    
    if(fileHandle != INVALID_HANDLE) {
        // Write header
        FileWrite(fileHandle, "Symbol", "EntryTime", "ExitTime", "Type", "EntryPrice", 
                 "ExitPrice", "Volume", "Profit", "Signal", "MA200", "MA20", "MA8", 
                 "RSI", "InSupplyZone", "InDemandZone", "TrendDirection");
        
        // Write trade data
        if(HistorySelect(0, TimeCurrent())) {
            for(int i = 0; i < HistoryDealsTotal(); i++) {
                ulong ticket = HistoryDealGetTicket(i);
                if(ticket > 0) {
                    string symbol = HistoryDealGetString(ticket, DEAL_SYMBOL);
                    datetime entryTime = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
                    double entryPrice = HistoryDealGetDouble(ticket, DEAL_PRICE);
                    double volume = HistoryDealGetDouble(ticket, DEAL_VOLUME);
                    double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
                    string comment = HistoryDealGetString(ticket, DEAL_COMMENT);
                    
                    // Find symbol index
                    int symbolIndex = -1;
                    for(int j = 0; j < symbolCount; j++) {
                        if(tradingSymbols[j] == symbol) {
                            symbolIndex = j;
                            break;
                        }
                    }
                    
                    if(symbolIndex >= 0) {
                        // Get indicator values at entry time (simplified)
                        double ma200 = ArraySize(handles[symbolIndex].ma200_buffer) > 0 ? handles[symbolIndex].ma200_buffer[0] : 0;
                        double ma20 = ArraySize(handles[symbolIndex].ma20_buffer) > 0 ? handles[symbolIndex].ma20_buffer[0] : 0;
                        double ma8 = ArraySize(handles[symbolIndex].ma8_buffer) > 0 ? handles[symbolIndex].ma8_buffer[0] : 0;
                        double rsi = ArraySize(handles[symbolIndex].rsi_buffer) > 0 ? handles[symbolIndex].rsi_buffer[0] : 0;
                        
                        FileWrite(fileHandle, symbol, entryTime, entryTime, "DEAL", 
                                 entryPrice, entryPrice, volume, profit, comment,
                                 ma200, ma20, ma8, rsi, false, false, 0);
                    }
                }
            }
        }
        
        FileClose(fileHandle);
        Print("Trading data exported to: ", filename);
    }
}