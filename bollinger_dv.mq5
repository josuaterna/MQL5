//+------------------------------------------------------------------+//+------------------------------------------------------------------+
//|                                   Bollinger Bands Trading Bot MT5 |
//|                                        Copyright 2025, TradingBot |
//|                                              https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, TradingBot"
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\PositionInfo.mqh>

//--- Input parameters
input group "=== SÍMBOLOS DE TRADING ==="
input string Symbols = "EURUSD,GBPUSD,BTCUSD,XAUUSD"; // Símbolos separados por coma
input bool UseM5 = true;                 // Usar timeframe M5
input bool UseM15 = true;                // Usar timeframe M15
input bool UseM30 = true;                // Usar timeframe M30
input bool UseH1 = true;                 // Usar timeframe H1
input bool EnableTrading = true;         // Activar/Desactivar Trading
input int MagicNumber = 54321;           // Número mágico

input group "=== GESTIÓN DE DINERO ==="
input double LotSize = 0.01;             // Tamaño de lote
input bool UseMoneyManagement = true;    // Usar gestión de dinero
input double RiskPercent = 2.0;          // Porcentaje de riesgo
input double MaxLotSize = 1.0;           // Lote máximo
input double MaxLotAmount = 0.0;         // Cantidad máxima (0 = deshabilitado)

input group "=== CONFIGURACIÓN MARTINGALA ==="
input bool EnableMartingale = false;     // Activar Martingala
input double MartingaleMultiplier = 1.5; // Multiplicador Martingala
input int MaxMartingaleLevels = 3;       // Niveles máximos Martingala
input double MaxDrawdownPercent = 10.0;  // Drawdown máximo (%)
input double VaRLimit = 5.0;             // Límite VaR (%)

input group "=== BOLLINGER BANDS PRINCIPAL ==="
input int BB_Period = 20;                // Período Bollinger Bands
input double BB_Deviation = 2.0;         // Desviación estándar
input ENUM_MA_METHOD BB_Method = MODE_SMA; // Método MA para Bollinger
input ENUM_APPLIED_PRICE BB_Price = PRICE_CLOSE; // Precio aplicado
input double BB_OverboughtLevel = 0.8;   // Nivel sobrecompra (0.8 = 80% hacia banda superior)
input double BB_OversoldLevel = 0.2;     // Nivel sobreventa (0.2 = 20% hacia banda inferior)
input bool BB_UseSqueezeDetection = true; // Detectar compresión de bandas
input double BB_SqueezeThreshold = 0.5;  // Umbral para compresión (% del ATR)

input group "=== INDICADORES COMPLEMENTARIOS ==="
input int MA_Period_200 = 200;           // Período MA 200
input int MA_Period_20 = 20;             // Período MA 20
input int MA_Period_8 = 8;               // Período MA 8
input ENUM_MA_METHOD MA_Method = MODE_SMA; // Método MA
input ENUM_APPLIED_PRICE MA_Price = PRICE_CLOSE; // Precio aplicado MA

input group "=== RSI ==="
input int RSI_Period = 14;               // Período RSI
input ENUM_APPLIED_PRICE RSI_Price = PRICE_CLOSE; // Precio aplicado RSI
input int RSI_Lookback = 4;              // Lookback para pivotes RSI
input double RSI_Difference = 3.0;       // Diferencia para breakout RSI
input double RSI_OverboughtLevel = 70.0; // Nivel sobrecompra RSI
input double RSI_OversoldLevel = 30.0;   // Nivel sobreventa RSI

input group "=== SUPPLY/DEMAND ==="
input double SD_Threshold = 10.0;        // Threshold Supply/Demand (%)
input int SD_Resolution = 50;            // Resolución Supply/Demand
input int SD_Bars = 500;                 // Barras para cálculo S/D

input group "=== CONFIGURACIÓN DE TRADING ==="
input int MaxPositions = 5;              // Máximo posiciones por símbolo
input bool OneTradeOnly = false;         // Solo una operación por barra
input bool DoNotOpenOrdersIfThereIsClosedOrderByCurrentBar = true; // No abrir si hay orden cerrada en barra actual
input bool DoNotOpenOrdersIfThereIsClosedOrderByTrendBar = false; // No abrir por trend bar

input group "=== CONFIGURACIÓN DE STOPS ==="
input int StopLoss = 50;                 // Stop Loss (puntos)
input int TakeProfit = 100;              // Take Profit (puntos)
input bool UseTrailingStop = true;       // Usar trailing stop
input int TrailingStopPoints = 50;       // Trailing stop (puntos)
input double TakeProfitMultiplier = 2.0; // Multiplicador Take Profit
input double StopLossMultiplier = 1.0;   // Multiplicador Stop Loss
input bool UseBBTrailingStop = true;     // Usar bandas para trailing stop

input group "=== CONFIGURACIÓN DE TIEMPO ==="
input bool EnableTimeFilter = false;     // Activar filtro de tiempo
input int TradingStartHour = 0;          // Hora inicio trading
input int TradingStartMinute = 0;        // Minuto inicio trading
input int TradingStopHour = 23;          // Hora fin trading
input int TradingStopMinute = 59;        // Minuto fin trading
input bool CloseEverythingOutOfHours = false; // Cerrar todo fuera de horas

input group "=== DÍAS DE TRADING ==="
input bool Monday = true;                // Lunes
input bool Tuesday = true;               // Martes
input bool Wednesday = true;             // Miércoles
input bool Thursday = true;              // Jueves
input bool Friday = true;                // Viernes
input bool Saturday = false;             // Sábado
input bool Sunday = false;               // Domingo

input group "=== DIRECCIONES DE TRADING ==="
input bool AllowBuy = true;              // Permitir compras
input bool AllowSell = true;             // Permitir ventas
input bool AllowBuyAtSameTime = true;    // Permitir compras simultáneas
input bool AllowSellAtSameTime = true;   // Permitir ventas simultáneas

input group "=== CONFIGURACIÓN DE GRID ==="
input bool EnableGrid = false;           // Activar Grid
input int GridOrdersCompleteSpread = 50; // Spread completo órdenes Grid
input bool GridOrdersComplySpreadConditions = true; // Cumplir condiciones spread
input bool GridOrdersComplyIndicatorConditions = false; // Cumplir condiciones indicador
input bool GridOrdersComplyHoursConditions = false; // Cumplir condiciones horarias
input bool GridOrdersComplyDaysConditions = false; // Cumplir condiciones días

input group "=== ESTRATEGIA BOLLINGER BANDS ==="
input bool BB_TradeBounces = true;       // Operar rebotes en bandas
input bool BB_TradeBreakouts = true;     // Operar rupturas de bandas
input bool BB_RequireVolumeConfirmation = false; // Requerir confirmación volumen
input double BB_MinimumBandWidth = 0.001; // Ancho mínimo de bandas (% del precio)
input bool BB_UseMidLineCross = true;    // Usar cruce de línea media
input int BB_MinBarsFromBand = 2;        // Barras mínimas desde banda para nueva señal

input group "=== CONFIGURACIÓN AVANZADA ==="
input bool EnableSVMSignals = false;     // Usar señales SVM
input string SVMFile = "svm_signals_bb.csv"; // Archivo señales SVM
input bool ShowMA = true;                // Mostrar Moving Averages
input bool ShowRSI = true;               // Mostrar RSI
input bool ShowSupplyDemand = true;      // Mostrar zonas Supply/Demand
input bool ShowBollingerBands = true;    // Mostrar Bollinger Bands

//--- Variables globales
CTrade trade;
CSymbolInfo symbolInfo;
CPositionInfo positionInfo;

string tradingSymbols[];
bool symbolEnabled[];
ENUM_TIMEFRAMES activeTimeframes[];
int symbolCount;
int timeframeCount;

double accountEquity;
double initialBalance;
double currentDrawdown;

//--- Indicadores handles
struct IndicatorHandles {
    int ma200, ma20, ma8;
    int rsi;
    int bbands;
    double ma200_buffer[], ma20_buffer[], ma8_buffer[];
    double rsi_buffer[];
    double bb_upper[], bb_lower[], bb_middle[];
};

IndicatorHandles handles[];

//--- Estructura para Bollinger Bands
struct BBData {
    double upper;
    double lower;
    double middle;
    double bandWidth;
    double pricePosition;
    bool isSqueeze;
    bool wasAboveUpper;
    bool wasBelowLower;
    datetime lastSignalTime;
    int signalType;
    datetime lastUpdate;
};

BBData bbData[];

//--- Estructura para Supply/Demand
struct SupplyDemandZone {
    double topPrice;
    double bottomPrice;
    datetime startTime;
    datetime endTime;
    bool isSupply;
    double volume;
    bool isActive;
};

SupplyDemandZone sdZones[][100];

//--- Estructura para RSI Breakouts
struct RSIBreakout {
    double breakoutLevel;
    datetime breakoutTime;
    bool isBullish;
    bool isActive;
};

RSIBreakout rsiBreakouts[][50];

//--- Estructura para Martingala
struct MartingaleData {
    int level;
    double lastLot;
    bool lastWasLoss;
    datetime lastTradeTime;
};

MartingaleData martingale[];

//--- Estructura para señales SVM
struct SVMSignal {
    int direction;
    double confidence;
    double newBBPeriod;
    double newBBDeviation;
    double newOverboughtLevel;
    double newOversoldLevel;
    datetime timestamp;
};

SVMSignal svmSignals[];

//--- Variables de control
bool tradingDaysEnabled[7];
datetime lastBarTime = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    Print("=== INICIANDO BOLLINGER BANDS TRADING BOT ===");
    
    trade.SetExpertMagicNumber(MagicNumber);
    
    ParseSymbols();
    SetupTimeframes();
    SetupTradingDays();
    
    ArrayResize(handles, symbolCount);
    ArrayResize(bbData, symbolCount);
    ArrayResize(sdZones, symbolCount);
    ArrayResize(rsiBreakouts, symbolCount);
    ArrayResize(martingale, symbolCount);
    ArrayResize(svmSignals, symbolCount);
    
    for(int i = 0; i < symbolCount; i++) {
        InitializeIndicators(i);
        InitializeBB(i);
        InitializeMartingale(i);
        InitializeSVM(i);
        
        if(handles[i].ma200 == INVALID_HANDLE || handles[i].ma20 == INVALID_HANDLE || 
           handles[i].ma8 == INVALID_HANDLE || handles[i].rsi == INVALID_HANDLE ||
           handles[i].bbands == INVALID_HANDLE) {
            Print("Error inicializando indicadores para ", tradingSymbols[i]);
            return(INIT_FAILED);
        }
    }
    
    initialBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    
    EventSetTimer(300);
    
    Print("Bot Bollinger Bands inicializado para ", symbolCount, " símbolos");
    Print("Estrategia: Bollinger Bands + Multi-indicadores + SVM");
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                               |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    Print("=== CERRANDO BOLLINGER BANDS TRADING BOT ===");
    
    for(int i = 0; i < symbolCount; i++) {
        if(handles[i].ma200 != INVALID_HANDLE) IndicatorRelease(handles[i].ma200);
        if(handles[i].ma20 != INVALID_HANDLE) IndicatorRelease(handles[i].ma20);
        if(handles[i].ma8 != INVALID_HANDLE) IndicatorRelease(handles[i].ma8);
        if(handles[i].rsi != INVALID_HANDLE) IndicatorRelease(handles[i].rsi);
        if(handles[i].bbands != INVALID_HANDLE) IndicatorRelease(handles[i].bbands);
    }
    
    EventKillTimer();
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
    static datetime lastTick = 0;
    if(TimeCurrent() == lastTick) return;
    lastTick = TimeCurrent();
    
    UpdateAccountInfo();
    
    if(!CheckRiskLimits()) return;
    
    if(EnableSVMSignals) {
        ReadSVMSignals();
    }
    
    for(int i = 0; i < symbolCount; i++) {
        if(symbolEnabled[i]) {
            ProcessSymbol(i);
        }
    }
}

//+------------------------------------------------------------------+
//| Parsear símbolos                                               |
//+------------------------------------------------------------------+
void ParseSymbols() {
    string symbolStr = Symbols;
    symbolCount = 0;
    
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
    
    ArrayResize(tradingSymbols, symbolCount);
    ArrayResize(symbolEnabled, symbolCount);
    
    pos = 0;
    for(int i = 0; i < symbolCount; i++) {
        int nextComma = StringFind(symbolStr, ",", pos);
        if(nextComma == -1) {
            tradingSymbols[i] = StringSubstr(symbolStr, pos);
        } else {
            tradingSymbols[i] = StringSubstr(symbolStr, pos, nextComma - pos);
        }
        pos = nextComma + 1;
        
        StringTrimLeft(tradingSymbols[i]);
        StringTrimRight(tradingSymbols[i]);
        symbolEnabled[i] = true;
    }
}

//+------------------------------------------------------------------+
//| Configurar timeframes                                          |
//+------------------------------------------------------------------+
void SetupTimeframes() {
    timeframeCount = 0;
    
    if(UseM5) timeframeCount++;
    if(UseM15) timeframeCount++;
    if(UseM30) timeframeCount++;
    if(UseH1) timeframeCount++;
    
    ArrayResize(activeTimeframes, timeframeCount);
    int index = 0;
    
    if(UseM5) { activeTimeframes[index] = PERIOD_M5; index++; }
    if(UseM15) { activeTimeframes[index] = PERIOD_M15; index++; }
    if(UseM30) { activeTimeframes[index] = PERIOD_M30; index++; }
    if(UseH1) { activeTimeframes[index] = PERIOD_H1; index++; }
}

//+------------------------------------------------------------------+
//| Configurar días de trading                                     |
//+------------------------------------------------------------------+
void SetupTradingDays() {
    tradingDaysEnabled[0] = Sunday;
    tradingDaysEnabled[1] = Monday;
    tradingDaysEnabled[2] = Tuesday;
    tradingDaysEnabled[3] = Wednesday;
    tradingDaysEnabled[4] = Thursday;
    tradingDaysEnabled[5] = Friday;
    tradingDaysEnabled[6] = Saturday;
}

//+------------------------------------------------------------------+
//| Inicializar indicadores                                        |
//+------------------------------------------------------------------+
void InitializeIndicators(int symbolIndex) {
    string symbol = tradingSymbols[symbolIndex];
    ENUM_TIMEFRAMES timeframe = timeframeCount > 0 ? activeTimeframes[0] : PERIOD_CURRENT;
    
    handles[symbolIndex].ma200 = iMA(symbol, timeframe, MA_Period_200, 0, MA_Method, MA_Price);
    handles[symbolIndex].ma20 = iMA(symbol, timeframe, MA_Period_20, 0, MA_Method, MA_Price);
    handles[symbolIndex].ma8 = iMA(symbol, timeframe, MA_Period_8, 0, MA_Method, MA_Price);
    handles[symbolIndex].rsi = iRSI(symbol, timeframe, RSI_Period, RSI_Price);
    handles[symbolIndex].bbands = iBands(symbol, timeframe, BB_Period, 0, BB_Deviation, BB_Price);
    
    ArrayResize(handles[symbolIndex].ma200_buffer, 200);
    ArrayResize(handles[symbolIndex].ma20_buffer, 200);
    ArrayResize(handles[symbolIndex].ma8_buffer, 200);
    ArrayResize(handles[symbolIndex].rsi_buffer, 200);
    ArrayResize(handles[symbolIndex].bb_upper, 200);
    ArrayResize(handles[symbolIndex].bb_lower, 200);
    ArrayResize(handles[symbolIndex].bb_middle, 200);
    
    ArrayInitialize(handles[symbolIndex].ma200_buffer, 0);
    ArrayInitialize(handles[symbolIndex].ma20_buffer, 0);
    ArrayInitialize(handles[symbolIndex].ma8_buffer, 0);
    ArrayInitialize(handles[symbolIndex].rsi_buffer, 0);
    ArrayInitialize(handles[symbolIndex].bb_upper, 0);
    ArrayInitialize(handles[symbolIndex].bb_lower, 0);
    ArrayInitialize(handles[symbolIndex].bb_middle, 0);
}

//+------------------------------------------------------------------+
//| Inicializar Bollinger Bands                                   |
//+------------------------------------------------------------------+
void InitializeBB(int index) {
    bbData[index].upper = 0;
    bbData[index].lower = 0;
    bbData[index].middle = 0;
    bbData[index].bandWidth = 0;
    bbData[index].pricePosition = 0.5;
    bbData[index].isSqueeze = false;
    bbData[index].wasAboveUpper = false;
    bbData[index].wasBelowLower = false;
    bbData[index].lastSignalTime = 0;
    bbData[index].signalType = 0;
    bbData[index].lastUpdate = 0;
}

//+------------------------------------------------------------------+
//| Inicializar Martingala                                        |
//+------------------------------------------------------------------+
void InitializeMartingale(int index) {
    martingale[index].level = 0;
    martingale[index].lastLot = LotSize;
    martingale[index].lastWasLoss = false;
    martingale[index].lastTradeTime = 0;
}

//+------------------------------------------------------------------+
//| Inicializar SVM                                               |
//+------------------------------------------------------------------+
void InitializeSVM(int index) {
    svmSignals[index].direction = 0;
    svmSignals[index].confidence = 0;
    svmSignals[index].newBBPeriod = BB_Period;
    svmSignals[index].newBBDeviation = BB_Deviation;
    svmSignals[index].newOverboughtLevel = BB_OverboughtLevel;
    svmSignals[index].newOversoldLevel = BB_OversoldLevel;
    svmSignals[index].timestamp = 0;
}

//+------------------------------------------------------------------+
//| Verificar horario de trading                                  |
//+------------------------------------------------------------------+
bool IsTradingTimeAllowed() {
    if(!EnableTimeFilter) return true;
    
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    
    if(!tradingDaysEnabled[dt.day_of_week]) return false;
    
    int currentMinutes = dt.hour * 60 + dt.min;
    int startMinutes = TradingStartHour * 60 + TradingStartMinute;
    int stopMinutes = TradingStopHour * 60 + TradingStopMinute;
    
    if(startMinutes <= stopMinutes) {
        return (currentMinutes >= startMinutes && currentMinutes <= stopMinutes);
    } else {
        return (currentMinutes >= startMinutes || currentMinutes <= stopMinutes);
    }
}

//+------------------------------------------------------------------+
//| Actualizar información de cuenta                              |
//+------------------------------------------------------------------+
void UpdateAccountInfo() {
    accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    if(initialBalance > 0) {
        currentDrawdown = (initialBalance - accountEquity) / initialBalance * 100.0;
    }
}

//+------------------------------------------------------------------+
//| Verificar límites de riesgo                                   |
//+------------------------------------------------------------------+
bool CheckRiskLimits() {
    if(currentDrawdown > MaxDrawdownPercent) {
        Print("ALERTA: Drawdown máximo excedido: ", currentDrawdown, "%");
        return false;
    }
    
    double totalRisk = CalculateVaR();
    if(totalRisk > VaRLimit) {
        Print("ALERTA: Límite VaR excedido: ", totalRisk, "%");
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Calcular VaR                                                  |
//+------------------------------------------------------------------+
double CalculateVaR() {
    double totalRisk = 0;
    
    for(int i = 0; i < PositionsTotal(); i++) {
        if(positionInfo.SelectByIndex(i) && positionInfo.Magic() == MagicNumber) {
            double risk = MathAbs(positionInfo.PriceOpen() - positionInfo.StopLoss()) * 
                         positionInfo.Volume() * 
                         SymbolInfoDouble(positionInfo.Symbol(), SYMBOL_TRADE_TICK_VALUE);
            totalRisk += risk;
        }
    }
    
    return accountEquity > 0 ? (totalRisk / accountEquity) * 100.0 : 0.0;
}

//+------------------------------------------------------------------+
//| Leer señales SVM                                              |
//+------------------------------------------------------------------+
void ReadSVMSignals() {
    int fileHandle = FileOpen(SVMFile, FILE_READ | FILE_CSV);
    if(fileHandle == INVALID_HANDLE) return;
    
    while(!FileIsEnding(fileHandle)) {
        string symbol = FileReadString(fileHandle);
        int direction = (int)FileReadNumber(fileHandle);
        double confidence = FileReadNumber(fileHandle);
        double newBBPeriod = FileReadNumber(fileHandle);
        double newBBDeviation = FileReadNumber(fileHandle);
        double newOverboughtLevel = FileReadNumber(fileHandle);
        double newOversoldLevel = FileReadNumber(fileHandle);
        datetime timestamp = (datetime)FileReadNumber(fileHandle);
        
        int index = GetSymbolIndex(symbol);
        if(index >= 0 && timestamp > svmSignals[index].timestamp) {
            svmSignals[index].direction = direction;
            svmSignals[index].confidence = confidence;
            svmSignals[index].newBBPeriod = newBBPeriod;
            svmSignals[index].newBBDeviation = newBBDeviation;
            svmSignals[index].newOverboughtLevel = newOverboughtLevel;
            svmSignals[index].newOversoldLevel = newOversoldLevel;
            svmSignals[index].timestamp = timestamp;
        }
    }
    
    FileClose(fileHandle);
}

//+------------------------------------------------------------------+
//| Obtener índice del símbolo                                    |
//+------------------------------------------------------------------+
int GetSymbolIndex(string symbol) {
    for(int i = 0; i < symbolCount; i++) {
        if(tradingSymbols[i] == symbol) return i;
    }
    return -1;
}

//+------------------------------------------------------------------+
//| Procesar símbolo                                              |
//+------------------------------------------------------------------+
void ProcessSymbol(int index) {
    string symbol = tradingSymbols[index];
    
    UpdateIndicatorData(index);
    CalculateBollingerBands(index);
    CalculateSupplyDemandZones(index);
    DetectRSIBreakouts(index);
    
    if(EnableTrading) {
        CheckBollingerBandsTradingSignals(index);
    }
    
    ManagePositions(index);
    
    if(ShowBollingerBands || ShowMA || ShowRSI || ShowSupplyDemand) {
        UpdateVisualization(index);
    }
}

//+------------------------------------------------------------------+
//| Actualizar datos de indicadores                               |
//+------------------------------------------------------------------+
void UpdateIndicatorData(int symbolIndex) {
    if(handles[symbolIndex].ma200 == INVALID_HANDLE || 
       handles[symbolIndex].ma20 == INVALID_HANDLE ||
       handles[symbolIndex].ma8 == INVALID_HANDLE ||
       handles[symbolIndex].rsi == INVALID_HANDLE ||
       handles[symbolIndex].bbands == INVALID_HANDLE) {
        return;
    }
    
    if(CopyBuffer(handles[symbolIndex].ma200, 0, 0, 200, handles[symbolIndex].ma200_buffer) <= 0) return;
    if(CopyBuffer(handles[symbolIndex].ma20, 0, 0, 200, handles[symbolIndex].ma20_buffer) <= 0) return;
    if(CopyBuffer(handles[symbolIndex].ma8, 0, 0, 200, handles[symbolIndex].ma8_buffer) <= 0) return;
    if(CopyBuffer(handles[symbolIndex].rsi, 0, 0, 200, handles[symbolIndex].rsi_buffer) <= 0) return;
    if(CopyBuffer(handles[symbolIndex].bbands, UPPER_BAND, 0, 200, handles[symbolIndex].bb_upper) <= 0) return;
    if(CopyBuffer(handles[symbolIndex].bbands, LOWER_BAND, 0, 200, handles[symbolIndex].bb_lower) <= 0) return;
    if(CopyBuffer(handles[symbolIndex].bbands, BASE_LINE, 0, 200, handles[symbolIndex].bb_middle) <= 0) return;
}

//+------------------------------------------------------------------+
//| Calcular Bollinger Bands                                      |
//+------------------------------------------------------------------+
void CalculateBollingerBands(int index) {
    if(ArraySize(handles[index].bb_upper) < 3) return;
    
    string symbol = tradingSymbols[index];
    double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
    
    double currentBBPeriod = BB_Period;
    double currentBBDeviation = BB_Deviation;
    double currentOverboughtLevel = BB_OverboughtLevel;
    double currentOversoldLevel = BB_OversoldLevel;
    
    if(EnableSVMSignals && svmSignals[index].confidence > 0.6) {
        currentBBPeriod = svmSignals[index].newBBPeriod;
        currentBBDeviation = svmSignals[index].newBBDeviation;
        currentOverboughtLevel = svmSignals[index].newOverboughtLevel;
        currentOversoldLevel = svmSignals[index].newOversoldLevel;
    }
    
    bbData[index].upper = handles[index].bb_upper[0];
    bbData[index].lower = handles[index].bb_lower[0];
    bbData[index].middle = handles[index].bb_middle[0];
    
    bbData[index].bandWidth = (bbData[index].upper - bbData[index].lower) / bbData[index].middle;
    
    if(bbData[index].upper != bbData[index].lower) {
        bbData[index].pricePosition = (currentPrice - bbData[index].lower) / (bbData[index].upper - bbData[index].lower);
    } else {
        bbData[index].pricePosition = 0.5;
    }
    
    if(BB_UseSqueezeDetection) {
        double atr = CalculateATR(symbol, 14);
        bbData[index].isSqueeze = (bbData[index].bandWidth < (atr / currentPrice) * BB_SqueezeThreshold);
    }
    
    bbData[index].wasAboveUpper = (currentPrice > bbData[index].upper);
    bbData[index].wasBelowLower = (currentPrice < bbData[index].lower);
    
    bbData[index].lastUpdate = TimeCurrent();
}

//+------------------------------------------------------------------+
//| Verificar señales de trading Bollinger Bands                 |
//+------------------------------------------------------------------+
void CheckBollingerBandsTradingSignals(int index) {
    if(!EnableTrading || !IsTradingTimeAllowed()) return;
    
    string symbol = tradingSymbols[index];
    double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
    
    if(OneTradeOnly) {
        datetime currentBarTime = iTime(symbol, PERIOD_CURRENT, 0);
        if(currentBarTime == lastBarTime) return;
        lastBarTime = currentBarTime;
    }
    
    if(DoNotOpenOrdersIfThereIsClosedOrderByCurrentBar) {
        if(HasClosedOrderInCurrentBar(symbol)) return;
    }
    
    if(!AllowBuy && !AllowSell) return;
    
    if(EnableSVMSignals && !ValidateSVMSignal(index)) return;
    
    int currentPositions = CountPositions(symbol);
    if(currentPositions >= MaxPositions) return;
    
    if(TimeCurrent() - bbData[index].lastSignalTime < BB_MinBarsFromBand * PeriodSeconds(PERIOD_CURRENT)) return;
    
    if(bbData[index].bandWidth < BB_MinimumBandWidth) return;
    
    bool buySignal = false;
    bool sellSignal = false;
    string signalReason = "";

// ESTRATEGIA 1: REBOTES EN BANDAS
    if(BB_TradeBounces) {
        if(bbData[index].pricePosition <= BB_OversoldLevel && !bbData[index].isSqueeze) {
            if(ValidateIndicatorConfirmation(index, true)) {
                buySignal = true;
                signalReason = "BB_Bounce_Lower";
            }
        }
        
        if(bbData[index].pricePosition >= BB_OverboughtLevel && !bbData[index].isSqueeze) {
            if(ValidateIndicatorConfirmation(index, false)) {
                sellSignal = true;
                signalReason = "BB_Bounce_Upper";
            }
        }
    }
    
    // ESTRATEGIA 2: RUPTURAS DE BANDAS
    if(BB_TradeBreakouts && !buySignal && !sellSignal) {
        if(currentPrice > bbData[index].upper && !bbData[index].wasAboveUpper) {
            if(!BB_RequireVolumeConfirmation || HasVolumeConfirmation(symbol)) {
                if(ValidateIndicatorConfirmation(index, true)) {
                    buySignal = true;
                    signalReason = "BB_Breakout_Upper";
                }
            }
        }
        
        if(currentPrice < bbData[index].lower && !bbData[index].wasBelowLower) {
            if(!BB_RequireVolumeConfirmation || HasVolumeConfirmation(symbol)) {
                if(ValidateIndicatorConfirmation(index, false)) {
                    sellSignal = true;
                    signalReason = "BB_Breakout_Lower";
                }
            }
        }
    }
    
    // ESTRATEGIA 3: CRUCE DE LÍNEA MEDIA
    if(BB_UseMidLineCross && !buySignal && !sellSignal) {
        static double prevPrice = 0;
        static double prevMiddle = 0;
        
        if(prevPrice > 0 && prevMiddle > 0) {
            if(prevPrice <= prevMiddle && currentPrice > bbData[index].middle) {
                if(ValidateIndicatorConfirmation(index, true)) {
                    buySignal = true;
                    signalReason = "BB_Cross_Above_Middle";
                }
            }
            
            if(prevPrice >= prevMiddle && currentPrice < bbData[index].middle) {
                if(ValidateIndicatorConfirmation(index, false)) {
                    sellSignal = true;
                    signalReason = "BB_Cross_Below_Middle";
                }
            }
        }
        
        prevPrice = currentPrice;
        prevMiddle = bbData[index].middle;
    }
    
    if(buySignal && !AllowBuyAtSameTime && HasBuyPositions(symbol)) buySignal = false;
    if(sellSignal && !AllowSellAtSameTime && HasSellPositions(symbol)) sellSignal = false;
    
    if(buySignal && !AllowBuy) buySignal = false;
    if(sellSignal && !AllowSell) sellSignal = false;
    
    if(buySignal) {
        if(!AllowBuyAtSameTime || !AllowSellAtSameTime) {
            CloseOppositePositions(index);
        }
        OpenPosition(index, ORDER_TYPE_BUY, signalReason);
        bbData[index].lastSignalTime = TimeCurrent();
        bbData[index].signalType = 1;
    } else if(sellSignal) {
        if(!AllowBuyAtSameTime || !AllowSellAtSameTime) {
            CloseOppositePositions(index);
        }
        OpenPosition(index, ORDER_TYPE_SELL, signalReason);
        bbData[index].lastSignalTime = TimeCurrent();
        bbData[index].signalType = -1;
    }
}

//+------------------------------------------------------------------+
//| Validar confirmación de indicadores                           |
//+------------------------------------------------------------------+
bool ValidateIndicatorConfirmation(int index, bool isBullish) {
    if(ArraySize(handles[index].ma200_buffer) < 3) return true;
    
    double ma200 = handles[index].ma200_buffer[0];
    double ma20 = handles[index].ma20_buffer[0];
    double ma8 = handles[index].ma8_buffer[0];
    double rsi = handles[index].rsi_buffer[0];
    
    string symbol = tradingSymbols[index];
    double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
    
    bool bullishTrend = (ma8 > ma20 && ma20 > ma200 && currentPrice > ma200);
    bool bearishTrend = (ma8 < ma20 && ma20 < ma200 && currentPrice < ma200);
    
    bool rsiOversold = (rsi < RSI_OversoldLevel);
    bool rsiOverbought = (rsi > RSI_OverboughtLevel);
    bool rsiNeutral = (rsi >= RSI_OversoldLevel && rsi <= RSI_OverboughtLevel);
    
    bool inSupplyZone = IsInSupplyZone(index, currentPrice);
    bool inDemandZone = IsInDemandZone(index, currentPrice);
    
    if(isBullish) {
        bool trendOk = bullishTrend || !bearishTrend;
        bool rsiOk = rsiOversold || rsiNeutral;
        bool zoneOk = inDemandZone || !inSupplyZone;
        
        return (trendOk && rsiOk && zoneOk);
    } else {
        bool trendOk = bearishTrend || !bullishTrend;
        bool rsiOk = rsiOverbought || rsiNeutral;
        bool zoneOk = inSupplyZone || !inDemandZone;
        
        return (trendOk && rsiOk && zoneOk);
    }
}

//+------------------------------------------------------------------+
//| Verificar confirmación de volumen                             |
//+------------------------------------------------------------------+
bool HasVolumeConfirmation(string symbol) {
    long currentVolume[];
    if(CopyTickVolume(symbol, PERIOD_CURRENT, 0, 3, currentVolume) < 3) return true;
    
    double avgVolume = (currentVolume[1] + currentVolume[2]) / 2.0;
    return (currentVolume[0] > avgVolume * 1.2);
}

//+------------------------------------------------------------------+
//| Validar señal SVM                                             |
//+------------------------------------------------------------------+
bool ValidateSVMSignal(int index) {
    if(svmSignals[index].confidence < 0.6) return false;
    
    if(bbData[index].signalType == 1 && svmSignals[index].direction != 1) return false;
    if(bbData[index].signalType == -1 && svmSignals[index].direction != -1) return false;
    
    return true;
}

//+------------------------------------------------------------------+
//| Verificar órdenes cerradas en barra actual                    |
//+------------------------------------------------------------------+
bool HasClosedOrderInCurrentBar(string symbol) {
    datetime currentBarTime = iTime(symbol, PERIOD_CURRENT, 0);
    
    if(!HistorySelect(currentBarTime, TimeCurrent())) return false;
    
    for(int i = 0; i < HistoryDealsTotal(); i++) {
        ulong ticket = HistoryDealGetTicket(i);
        if(ticket > 0) {
            string dealSymbol = HistoryDealGetString(ticket, DEAL_SYMBOL);
            long dealMagic = HistoryDealGetInteger(ticket, DEAL_MAGIC);
            
            if(dealSymbol == symbol && dealMagic == MagicNumber) {
                return true;
            }
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Verificar posiciones de compra                                |
//+------------------------------------------------------------------+
bool HasBuyPositions(string symbol) {
    for(int i = 0; i < PositionsTotal(); i++) {
        if(positionInfo.SelectByIndex(i) && 
           positionInfo.Symbol() == symbol && 
           positionInfo.Magic() == MagicNumber &&
           positionInfo.PositionType() == POSITION_TYPE_BUY) {
            return true;
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Verificar posiciones de venta                                 |
//+------------------------------------------------------------------+
bool HasSellPositions(string symbol) {
    for(int i = 0; i < PositionsTotal(); i++) {
        if(positionInfo.SelectByIndex(i) && 
           positionInfo.Symbol() == symbol && 
           positionInfo.Magic() == MagicNumber &&
           positionInfo.PositionType() == POSITION_TYPE_SELL) {
            return true;
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Verificar zona Supply                                         |
//+------------------------------------------------------------------+
bool IsInSupplyZone(int symbolIndex, double price) {
    for(int i = 0; i < 100; i++) {
        if(sdZones[symbolIndex][i].isActive && sdZones[symbolIndex][i].isSupply) {
            if(price >= sdZones[symbolIndex][i].bottomPrice && 
               price <= sdZones[symbolIndex][i].topPrice) {
                return true;
            }
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Verificar zona Demand                                         |
//+------------------------------------------------------------------+
bool IsInDemandZone(int symbolIndex, double price) {
    for(int i = 0; i < 100; i++) {
        if(sdZones[symbolIndex][i].isActive && !sdZones[symbolIndex][i].isSupply) {
            if(price >= sdZones[symbolIndex][i].bottomPrice && 
               price <= sdZones[symbolIndex][i].topPrice) {
                return true;
            }
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Cerrar posiciones contrarias                                  |
//+------------------------------------------------------------------+
void CloseOppositePositions(int index) {
    string symbol = tradingSymbols[index];
    
    for(int i = PositionsTotal() - 1; i >= 0; i--) {
        if(positionInfo.SelectByIndex(i) && 
           positionInfo.Symbol() == symbol && 
           positionInfo.Magic() == MagicNumber) {
            
            bool shouldClose = false;
            
            if(bbData[index].signalType == 1 && positionInfo.PositionType() == POSITION_TYPE_SELL) {
                shouldClose = true;
            }
            if(bbData[index].signalType == -1 && positionInfo.PositionType() == POSITION_TYPE_BUY) {
                shouldClose = true;
            }
            
            if(shouldClose) {
                double profit = positionInfo.Profit();
                trade.PositionClose(positionInfo.Ticket());
                
                if(EnableMartingale) {
                    martingale[index].lastWasLoss = (profit < 0);
                    if(profit < 0) {
                        martingale[index].level = MathMin(martingale[index].level + 1, MaxMartingaleLevels);
                    } else {
                        martingale[index].level = 0;
                    }
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Abrir posición                                                |
//+------------------------------------------------------------------+
void OpenPosition(int index, ENUM_ORDER_TYPE orderType, string signalReason) {
    string symbol = tradingSymbols[index];
    
    double lotSize = CalculateLotSize(index);
    if(lotSize <= 0) return;
    
    double price = (orderType == ORDER_TYPE_BUY) ? 
                   SymbolInfoDouble(symbol, SYMBOL_ASK) : 
                   SymbolInfoDouble(symbol, SYMBOL_BID);
    
    double stopLoss = 0, takeProfit = 0;
    
    if(orderType == ORDER_TYPE_BUY) {
        if(UseBBTrailingStop) {
            stopLoss = bbData[index].lower;
        } else if(StopLoss > 0) {
            double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
            stopLoss = price - (StopLoss * point);
        }
        
        if(TakeProfit > 0) {
            double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
            takeProfit = price + (TakeProfit * point);
            
            if(UseBBTrailingStop) {
                double bbTarget = bbData[index].upper;
                takeProfit = MathMax(takeProfit, bbTarget);
            }
        }
    } else {
        if(UseBBTrailingStop) {
            stopLoss = bbData[index].upper;
        } else if(StopLoss > 0) {
            double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
            stopLoss = price + (StopLoss * point);
        }
        
        if(TakeProfit > 0) {
            double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
            takeProfit = price - (TakeProfit * point);
            
            if(UseBBTrailingStop) {
                double bbTarget = bbData[index].lower;
                takeProfit = MathMin(takeProfit, bbTarget);
            }
        }
    }
    
    string comment = StringFormat("BB_%s_M%d_%s", 
                                 orderType == ORDER_TYPE_BUY ? "LONG" : "SHORT",
                                 martingale[index].level,
                                 signalReason);
    
    if(EnableSVMSignals && svmSignals[index].confidence > 0) {
        comment += StringFormat("_SVM%.0f", svmSignals[index].confidence * 100);
    }
    
    if(trade.PositionOpen(symbol, orderType, lotSize, price, stopLoss, takeProfit, comment)) {
        Print("POSICIÓN BB ABIERTA: ", symbol, " ", EnumToString(orderType), 
              " Lote:", lotSize, " SL:", stopLoss, " TP:", takeProfit, " Razón:", signalReason);
        
        martingale[index].lastTradeTime = TimeCurrent();
        martingale[index].lastLot = lotSize;
        
        if(EnableGrid) {
            ManageGridOrders(index, orderType, price);
        }
    } else {
        Print("ERROR abriendo posición BB: ", symbol, " Error:", GetLastError());
    }
}

//+------------------------------------------------------------------+
//| Calcular tamaño de lote                                       |
//+------------------------------------------------------------------+
double CalculateLotSize(int index) {
    double baseLot = LotSize;
    
    if(UseMoneyManagement) {
        string symbol = tradingSymbols[index];
        double balance = AccountInfoDouble(ACCOUNT_BALANCE);
        double riskAmount = balance * (RiskPercent / 100.0);
        
        double bandWidth = bbData[index].upper - bbData[index].lower;
        if(bandWidth > 0) {
            double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
            double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
            double pointValue = tickValue * (SymbolInfoDouble(symbol, SYMBOL_POINT) / tickSize);
            
            if(pointValue > 0) {
                double stopPoints = bandWidth / SymbolInfoDouble(symbol, SYMBOL_POINT);
                baseLot = riskAmount / (stopPoints * pointValue);
            }
        }
    }
    
    if(EnableMartingale && martingale[index].level > 0) {
        baseLot = martingale[index].lastLot * MathPow(MartingaleMultiplier, martingale[index].level);
    }
    
    if(MaxLotAmount > 0) {
        baseLot = MathMin(baseLot, MaxLotAmount);
    }
    baseLot = MathMin(baseLot, MaxLotSize);
    
    string symbol = tradingSymbols[index];
    double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    double stepLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
    
    baseLot = MathMax(baseLot, minLot);
    baseLot = MathMin(baseLot, maxLot);
    
    if(stepLot > 0) {
        baseLot = NormalizeDouble(baseLot / stepLot, 0) * stepLot;
    }
    
    return baseLot;
}

//+------------------------------------------------------------------+
//| Contar posiciones                                             |
//+------------------------------------------------------------------+
int CountPositions(string symbol) {
    int count = 0;
    for(int i = 0; i < PositionsTotal(); i++) {
        if(positionInfo.SelectByIndex(i) && 
           positionInfo.Symbol() == symbol && 
           positionInfo.Magic() == MagicNumber) {
            count++;
        }
    }
    return count;
}

//+------------------------------------------------------------------+
//| Gestionar posiciones                                          |
//+------------------------------------------------------------------+
void ManagePositions(int index) {
    string symbol = tradingSymbols[index];
    
    if(CloseEverythingOutOfHours && !IsTradingTimeAllowed()) {
        CloseAllPositions(symbol);
        return;
    }
    
    for(int i = 0; i < PositionsTotal(); i++) {
        if(positionInfo.SelectByIndex(i) && 
           positionInfo.Symbol() == symbol && 
           positionInfo.Magic() == MagicNumber) {
            
            if(UseTrailingStop) {
                UpdateBollingerBandsTrailingStop(index);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Trailing stop con Bollinger Bands                            |
//+------------------------------------------------------------------+
void UpdateBollingerBandsTrailingStop(int index) {
    string symbol = tradingSymbols[index];
    
    for(int i = 0; i < PositionsTotal(); i++) {
        if(positionInfo.SelectByIndex(i) && 
           positionInfo.Symbol() == symbol && 
           positionInfo.Magic() == MagicNumber) {
            
            double newSL = 0;
            bool shouldUpdate = false;
            
            if(positionInfo.PositionType() == POSITION_TYPE_BUY) {
                if(UseBBTrailingStop) {
                    newSL = bbData[index].lower;
                } else {
                    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
                    double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
                    newSL = currentPrice - (TrailingStopPoints * point);
                }
                
                if(newSL > positionInfo.StopLoss() && 
                   newSL < positionInfo.PriceCurrent()) {
                    shouldUpdate = true;
                }
            } else {
                if(UseBBTrailingStop) {
                    newSL = bbData[index].upper;
                } else {
                    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
                    double currentPrice = SymbolInfoDouble(symbol, SYMBOL_ASK);
                    newSL = currentPrice + (TrailingStopPoints * point);
                }
                
                if((newSL < positionInfo.StopLoss() || positionInfo.StopLoss() == 0) && 
                   newSL > positionInfo.PriceCurrent()) {
                    shouldUpdate = true;
                }
            }
            
            if(shouldUpdate) {
                if(trade.PositionModify(positionInfo.Ticket(), newSL, positionInfo.TakeProfit())) {
                    Print("BB Trailing stop actualizado: ", symbol, " nuevo SL: ", newSL);
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Cerrar todas las posiciones                                   |
//+------------------------------------------------------------------+
void CloseAllPositions(string symbol) {
    for(int i = PositionsTotal() - 1; i >= 0; i--) {
        if(positionInfo.SelectByIndex(i) && 
           positionInfo.Symbol() == symbol && 
           positionInfo.Magic() == MagicNumber) {
            trade.PositionClose(positionInfo.Ticket());
        }
    }
}

//+------------------------------------------------------------------+
//| Gestionar órdenes Grid                                        |
//+------------------------------------------------------------------+
void ManageGridOrders(int index, ENUM_ORDER_TYPE baseOrderType, double basePrice) {
    string symbol = tradingSymbols[index];
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    
    double gridSpread = (bbData[index].upper - bbData[index].lower) / 3;
    
    bool canPlaceGrid = true;
    
    if(GridOrdersComplySpreadConditions) {
        double spread = SymbolInfoInteger(symbol, SYMBOL_SPREAD) * point;
        if(spread > gridSpread / 2) canPlaceGrid = false;
    }
    
    if(GridOrdersComplyIndicatorConditions) {
        canPlaceGrid = ValidateIndicatorConfirmation(index, baseOrderType == ORDER_TYPE_BUY);
    }
    
    if(GridOrdersComplyHoursConditions) {
        canPlaceGrid = IsTradingTimeAllowed();
    }
    
    if(GridOrdersComplyDaysConditions) {
        MqlDateTime dt;
        TimeToStruct(TimeCurrent(), dt);
        canPlaceGrid = tradingDaysEnabled[dt.day_of_week];
    }
    
    if(!canPlaceGrid) return;
    
    double gridPrice1, gridPrice2;
    
    if(baseOrderType == ORDER_TYPE_BUY) {
        gridPrice1 = bbData[index].middle;
        gridPrice2 = bbData[index].lower;
    } else {
        gridPrice1 = bbData[index].middle;
        gridPrice2 = bbData[index].upper;
    }
    
    double lotSize = CalculateLotSize(index) * 0.5;
    
    ENUM_ORDER_TYPE gridOrderType = (baseOrderType == ORDER_TYPE_BUY) ? 
                                    ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_SELL_LIMIT;
    
    trade.OrderOpen(symbol, gridOrderType, lotSize, 0, gridPrice1, 0, 0, 
                   ORDER_TIME_GTC, 0, "BB_Grid_Middle");
    trade.OrderOpen(symbol, gridOrderType, lotSize, 0, gridPrice2, 0, 0, 
                   ORDER_TIME_GTC, 0, "BB_Grid_Band");
}

//+------------------------------------------------------------------+
//| Calcular Supply/Demand zones                                  |
//+------------------------------------------------------------------+
void CalculateSupplyDemandZones(int symbolIndex) {
    string symbol = tradingSymbols[symbolIndex];
    ENUM_TIMEFRAMES timeframe = timeframeCount > 0 ? activeTimeframes[0] : PERIOD_CURRENT;
    
    MqlRates rates[];
    int barsToAnalyze = MathMin(SD_Bars, 200);
    int copied = CopyRates(symbol, timeframe, 0, barsToAnalyze, rates);
    if(copied < 50) return;
    
    double maxPrice = rates[0].high;
    double minPrice = rates[0].low;
    long totalVolume = 0;
    
    for(int i = 0; i < copied; i++) {
        maxPrice = MathMax(maxPrice, rates[i].high);
        minPrice = MathMin(minPrice, rates[i].low);
        totalVolume += rates[i].tick_volume;
    }
    
    if(totalVolume <= 0 || maxPrice <= minPrice) return;
    
    double range = (maxPrice - minPrice) / MathMin(SD_Resolution, 20);
    if(range <= 0) return;
    
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
//| Encontrar slot vacío para zona                                |
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
//| Detectar RSI breakouts                                        |
//+------------------------------------------------------------------+
void DetectRSIBreakouts(int symbolIndex) {
    if(ArraySize(handles[symbolIndex].rsi_buffer) < RSI_Lookback * 2) return;
    
    double currentRSI = handles[symbolIndex].rsi_buffer[0];
    
    for(int i = RSI_Lookback; i < ArraySize(handles[symbolIndex].rsi_buffer) - RSI_Lookback; i++) {
        bool isPivotHigh = true;
        bool isPivotLow = true;
        
        double centerRSI = handles[symbolIndex].rsi_buffer[i];
        
        for(int j = i - RSI_Lookback; j <= i + RSI_Lookback; j++) {
            if(j != i && handles[symbolIndex].rsi_buffer[j] >= centerRSI) {
                isPivotHigh = false;
                break;
            }
        }
        
        for(int j = i - RSI_Lookback; j <= i + RSI_Lookback; j++) {
            if(j != i && handles[symbolIndex].rsi_buffer[j] <= centerRSI) {
                isPivotLow = false;
                break;
            }
        }
        
        if(isPivotHigh && currentRSI > (centerRSI + RSI_Difference)) {
            RecordRSIBreakout(symbolIndex, centerRSI, false);
        } else if(isPivotLow && currentRSI < (centerRSI - RSI_Difference)) {
            RecordRSIBreakout(symbolIndex, centerRSI, true);
        }
    }
}

//+------------------------------------------------------------------+
//| Registrar RSI breakout                                        |
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
//| Calcular ATR                                                  |
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
    return 0.0001;
}

//+------------------------------------------------------------------+
//| Actualizar visualización                                      |
//+------------------------------------------------------------------+
void UpdateVisualization(int symbolIndex) {
    string symbol = tradingSymbols[symbolIndex];
    string prefix = "BBBot_" + symbol + "_";
    
    CleanOldObjects(prefix);
    
    if(ShowBollingerBands) DrawBollingerBands(symbolIndex, prefix);
    if(ShowMA) DrawMovingAverages(symbolIndex, prefix);
    if(ShowSupplyDemand) DrawSupplyDemandZones(symbolIndex, prefix);
    if(ShowRSI) DrawRSIIndicator(symbolIndex, prefix);
}

//+------------------------------------------------------------------+
//| Limpiar objetos antiguos                                      |
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
//| Dibujar Bollinger Bands                                       |
//+------------------------------------------------------------------+
void DrawBollingerBands(int symbolIndex, string prefix) {
    if(bbData[symbolIndex].upper <= 0) return;
    
    datetime timeNow = TimeCurrent();
    
    string objNameUpper = prefix + "BB_Upper_" + IntegerToString(timeNow);
    ObjectCreate(0, objNameUpper, OBJ_HLINE, 0, 0, bbData[symbolIndex].upper);
    ObjectSetInteger(0, objNameUpper, OBJPROP_COLOR, clrBlue);
    ObjectSetInteger(0, objNameUpper, OBJPROP_WIDTH, 2);
    ObjectSetInteger(0, objNameUpper, OBJPROP_STYLE, STYLE_SOLID);
    
    string objNameMiddle = prefix + "BB_Middle_" + IntegerToString(timeNow);
    ObjectCreate(0, objNameMiddle, OBJ_HLINE, 0, 0, bbData[symbolIndex].middle);
    ObjectSetInteger(0, objNameMiddle, OBJPROP_COLOR, clrYellow);
    ObjectSetInteger(0, objNameMiddle, OBJPROP_WIDTH, 1);
    ObjectSetInteger(0, objNameMiddle, OBJPROP_STYLE, STYLE_DOT);
    
    string objNameLower = prefix + "BB_Lower_" + IntegerToString(timeNow);
    ObjectCreate(0, objNameLower, OBJ_HLINE, 0, 0, bbData[symbolIndex].lower);
    ObjectSetInteger(0, objNameLower, OBJPROP_COLOR, clrRed);
    ObjectSetInteger(0, objNameLower, OBJPROP_WIDTH, 2);
    ObjectSetInteger(0, objNameLower, OBJPROP_STYLE, STYLE_SOLID);
    
    string objInfo = prefix + "BB_Info";
    ObjectCreate(0, objInfo, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, objInfo, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, objInfo, OBJPROP_XDISTANCE, 10);
    ObjectSetInteger(0, objInfo, OBJPROP_YDISTANCE, 30 + (symbolIndex * 60));
    
    string infoText = StringFormat("%s BB: %.1f%% | Width: %.4f | %s", 
                                  tradingSymbols[symbolIndex],
                                  bbData[symbolIndex].pricePosition * 100,
                                  bbData[symbolIndex].bandWidth,
                                  bbData[symbolIndex].isSqueeze ? "SQUEEZE" : "NORMAL");
    
    ObjectSetString(0, objInfo, OBJPROP_TEXT, infoText);
    ObjectSetInteger(0, objInfo, OBJPROP_FONTSIZE, 9);
    ObjectSetInteger(0, objInfo, OBJPROP_COLOR, clrWhite);
}

//+------------------------------------------------------------------+
//| Dibujar Moving Averages                                       |
//+------------------------------------------------------------------+
void DrawMovingAverages(int symbolIndex, string prefix) {
    if(ArraySize(handles[symbolIndex].ma200_buffer) < 2) return;
    
    datetime timeNow = TimeCurrent();
    
    if(handles[symbolIndex].ma200_buffer[0] > 0) {
        string objName = prefix + "MA200_" + IntegerToString(timeNow);
        ObjectCreate(0, objName, OBJ_HLINE, 0, 0, handles[symbolIndex].ma200_buffer[0]);
        ObjectSetInteger(0, objName, OBJPROP_COLOR, clrBlue);
        ObjectSetInteger(0, objName, OBJPROP_WIDTH, 3);
        ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
    }
    
    if(handles[symbolIndex].ma20_buffer[0] > 0) {
        string objName = prefix + "MA20_" + IntegerToString(timeNow);
        ObjectCreate(0, objName, OBJ_HLINE, 0, 0, handles[symbolIndex].ma20_buffer[0]);
        ObjectSetInteger(0, objName, OBJPROP_COLOR, clrOrange);
        ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);
    }
    
    if(handles[symbolIndex].ma8_buffer[0] > 0) {
        string objName = prefix + "MA8_" + IntegerToString(timeNow);
        ObjectCreate(0, objName, OBJ_HLINE, 0, 0, handles[symbolIndex].ma8_buffer[0]);
        ObjectSetInteger(0, objName, OBJPROP_COLOR, clrLime);
        ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
    }
}

//+------------------------------------------------------------------+
//| Dibujar zonas Supply/Demand                                   |
//+------------------------------------------------------------------+
void DrawSupplyDemandZones(int symbolIndex, string prefix) {
    for(int i = 0; i < 100; i++) {
        if(sdZones[symbolIndex][i].isActive) {
            string objName = prefix + "SD_Zone_" + IntegerToString(i);
            
            datetime timeNow = TimeCurrent();
            datetime timeEnd = timeNow + 3600;
            
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
//| Dibujar indicador RSI                                         |
//+------------------------------------------------------------------+
void DrawRSIIndicator(int symbolIndex, string prefix) {
    if(ArraySize(handles[symbolIndex].rsi_buffer) > 0) {
        string objName = prefix + "RSI_Value";
        double currentRSI = handles[symbolIndex].rsi_buffer[0];
        
        ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, 10);
        ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, 90 + (symbolIndex * 60));
        ObjectSetString(0, objName, OBJPROP_TEXT, 
                       tradingSymbols[symbolIndex] + " RSI: " + DoubleToString(currentRSI, 2));
        ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 9);
        
        if(currentRSI > RSI_OverboughtLevel) {
            ObjectSetInteger(0, objName, OBJPROP_COLOR, clrRed);
        } else if(currentRSI < RSI_OversoldLevel) {
            ObjectSetInteger(0, objName, OBJPROP_COLOR, clrLime);
        } else {
            ObjectSetInteger(0, objName, OBJPROP_COLOR, clrWhite);
        }
    }
}

//+------------------------------------------------------------------+
//| Timer function                                                 |
//+------------------------------------------------------------------+
void OnTimer() {
    ExportDataForSVM();
    CleanExpiredData();
    ShowStatistics();
}

//+------------------------------------------------------------------+
//| Exportar datos para SVM                                       |
//+------------------------------------------------------------------+
void ExportDataForSVM() {
    static datetime lastExport = 0;
    if(TimeCurrent() - lastExport < 1800) return;
    lastExport = TimeCurrent();
    
    string filename = "trading_results_bb_" + TimeToString(TimeCurrent(), TIME_DATE) + ".csv";
    int fileHandle = FileOpen(filename, FILE_WRITE | FILE_CSV);
    
    if(fileHandle != INVALID_HANDLE) {
        FileWrite(fileHandle, "Symbol", "Timestamp", "BB_Upper", "BB_Lower", "BB_Middle", 
                 "BB_Width", "Price_Position", "Is_Squeeze", "Price", "Profit", 
                 "Positions", "MartingaleLevel", "RSI", "MA200", "MA20", "MA8");
        
        for(int i = 0; i < symbolCount; i++) {
            if(!symbolEnabled[i]) continue;
            
            string symbol = tradingSymbols[i];
            double price = SymbolInfoDouble(symbol, SYMBOL_BID);
            double profit = 0;
            int positions = 0;
            
            for(int j = 0; j < PositionsTotal(); j++) {
                if(positionInfo.SelectByIndex(j) && 
                   positionInfo.Symbol() == symbol && 
                   positionInfo.Magic() == MagicNumber) {
                    positions++;
                    profit += positionInfo.Profit();
                }
            }
            
            double rsi = ArraySize(handles[i].rsi_buffer) > 0 ? handles[i].rsi_buffer[0] : 0;
            double ma200 = ArraySize(handles[i].ma200_buffer) > 0 ? handles[i].ma200_buffer[0] : 0;
            double ma20 = ArraySize(handles[i].ma20_buffer) > 0 ? handles[i].ma20_buffer[0] : 0;
            double ma8 = ArraySize(handles[i].ma8_buffer) > 0 ? handles[i].ma8_buffer[0] : 0;
            
            FileWrite(fileHandle, symbol, TimeCurrent(), bbData[i].upper, bbData[i].lower, 
                     bbData[i].middle, bbData[i].bandWidth, bbData[i].pricePosition,
                     bbData[i].isSqueeze ? 1 : 0, price, profit, positions, 
                     martingale[i].level, rsi, ma200, ma20, ma8);
        }
        
        FileClose(fileHandle);
    }
}

//+------------------------------------------------------------------+
//| Limpiar datos expirados                                       |
//+------------------------------------------------------------------+
void CleanExpiredData() {
    datetime currentTime = TimeCurrent();
    
    for(int s = 0; s < symbolCount; s++) {
        for(int i = 0; i < 100; i++) {
            if(sdZones[s][i].isActive) {
                if(currentTime - sdZones[s][i].startTime > 86400) {
                    sdZones[s][i].isActive = false;
                }
            }
        }
        
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
//| Mostrar estadísticas                                          |
//+------------------------------------------------------------------+
void ShowStatistics() {
    static datetime lastShow = 0;
    if(TimeCurrent() - lastShow < 900) return;
    lastShow = TimeCurrent();
    
    double totalProfit = 0;
    int totalPositions = 0;
    
    for(int i = 0; i < PositionsTotal(); i++) {
        if(positionInfo.SelectByIndex(i) && positionInfo.Magic() == MagicNumber) {
            totalProfit += positionInfo.Profit();
            totalPositions++;
        }
    }
    
    double drawdown = initialBalance > 0 ? (initialBalance - accountEquity) / initialBalance * 100.0 : 0;
    
    Print("=== ESTADÍSTICAS BOLLINGER BANDS BOT ===");
    Print("Posiciones activas: ", totalPositions);
    Print("P&L total: ", DoubleToString(totalProfit, 2));
    Print("Equity: ", DoubleToString(accountEquity, 2));
    Print("Drawdown: ", DoubleToString(drawdown, 2), "%");
    Print("VaR: ", DoubleToString(CalculateVaR(), 2), "%");
    
    for(int i = 0; i < symbolCount; i++) {
        if(symbolEnabled[i]) {
            Print(tradingSymbols[i], " BB: Upper=", DoubleToString(bbData[i].upper, 5),
                  " Lower=", DoubleToString(bbData[i].lower, 5),
                  " Width=", DoubleToString(bbData[i].bandWidth, 4),
                  " Position=", DoubleToString(bbData[i].pricePosition * 100, 1), "%",
                  bbData[i].isSqueeze ? " [SQUEEZE]" : "");
        }
    }
}

