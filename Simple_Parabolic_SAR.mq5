//+------------------------------------------------------------------+
//|                                    Simple SAR Trading Bot MT5.mq5 |
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
input group "=== SÍMBOLOS ==="
input bool TradeEURUSD = true;           // Operar EURUSD
input bool TradeGBPUSD = true;           // Operar GBPUSD
input bool TradeBTCUSD = false;          // Operar BTCUSD
input bool TradeXAUUSD = true;           // Operar XAUUSD

input group "=== PARABOLIC SAR ==="
input double SAR_Start = 0.02;           // Factor inicial
input double SAR_Increment = 0.02;       // Incremento del factor
input double SAR_Maximum = 0.2;          // Factor máximo

input group "=== GESTIÓN DE RIESGO ==="
input double BaseLotSize = 0.01;         // Tamaño base de lote
input double RiskPercent = 2.0;          // Riesgo por operación (%)
input bool EnableMartingale = true;      // Activar Martingala
input double MartingaleMultiplier = 1.5; // Multiplicador Martingala
input int MaxMartingaleLevels = 3;       // Niveles máximos Martingala
input double MaxDrawdownPercent = 10.0;  // Drawdown máximo (%)
input double VaRLimit = 5.0;             // Límite VaR (%)

input group "=== CONFIGURACIÓN ==="
input bool EnableTrading = true;         // Activar trading
input bool EnableSVMSignals = false;     // Usar señales SVM
input string SVMFile = "svm_signals.csv"; // Archivo señales SVM
input int MagicNumber = 12345;           // Número mágico

//--- Variables globales
CTrade trade;
CSymbolInfo symbolInfo;
CPositionInfo positionInfo;

string symbols[] = {"EURUSD", "GBPUSD", "BTCUSD", "XAUUSD"};
bool symbolEnabled[4];
int totalSymbols = 4;

double initialBalance;
double currentEquity;

//--- Estructura para Parabolic SAR
struct SARData {
    bool uptrend;
    double EP;          // Extreme Point
    double SAR;         // Stop and Reverse
    double AF;          // Acceleration Factor
    double nextSAR;
    bool signalGenerated;
    datetime lastUpdate;
};

SARData sarData[4];

//--- Estructura para Martingala
struct MartingaleData {
    int level;
    double lastLot;
    bool lastWasLoss;
    datetime lastTradeTime;
};

MartingaleData martingale[4];

//--- Estructura para señales SVM
struct SVMSignal {
    int direction;      // 1=BUY, -1=SELL, 0=HOLD
    double confidence;
    double newStart;
    double newIncrement;
    double newMaximum;
    datetime timestamp;
};

SVMSignal svmSignals[4];

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    Print("=== INICIANDO SIMPLE SAR TRADING BOT ===");
    
    // Configurar símbolos activos
    symbolEnabled[0] = TradeEURUSD;
    symbolEnabled[1] = TradeGBPUSD;
    symbolEnabled[2] = TradeBTCUSD;
    symbolEnabled[3] = TradeXAUUSD;
    
    // Configurar número mágico
    trade.SetExpertMagicNumber(MagicNumber);
    
    // Inicializar datos
    initialBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    
    for(int i = 0; i < totalSymbols; i++) {
        if(!symbolEnabled[i]) continue;
        
        InitializeSAR(i);
        InitializeMartingale(i);
        InitializeSVM(i);
        
        Print("Símbolo configurado: ", symbols[i]);
    }
    
    // Timer cada 60 segundos
    EventSetTimer(60);
    
    Print("Bot inicializado correctamente");
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                               |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    Print("=== CERRANDO SIMPLE SAR TRADING BOT ===");
    EventKillTimer();
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
    // Evitar ticks duplicados
    static datetime lastTick = 0;
    if(TimeCurrent() == lastTick) return;
    lastTick = TimeCurrent();
    
    // Actualizar información de cuenta
    UpdateAccountInfo();
    
    // Verificar gestión de riesgo
    if(!CheckRiskLimits()) return;
    
    // Procesar señales SVM si están habilitadas
    if(EnableSVMSignals) {
        ReadSVMSignals();
    }
    
    // Procesar cada símbolo
    for(int i = 0; i < totalSymbols; i++) {
        if(symbolEnabled[i]) {
            ProcessSymbol(i);
        }
    }
}

//+------------------------------------------------------------------+
//| Inicializar datos SAR                                          |
//+------------------------------------------------------------------+
void InitializeSAR(int index) {
    sarData[index].uptrend = false;
    sarData[index].EP = 0;
    sarData[index].SAR = 0;
    sarData[index].AF = SAR_Start;
    sarData[index].nextSAR = 0;
    sarData[index].signalGenerated = false;
    sarData[index].lastUpdate = 0;
}

//+------------------------------------------------------------------+
//| Inicializar Martingala                                         |
//+------------------------------------------------------------------+
void InitializeMartingale(int index) {
    martingale[index].level = 0;
    martingale[index].lastLot = BaseLotSize;
    martingale[index].lastWasLoss = false;
    martingale[index].lastTradeTime = 0;
}

//+------------------------------------------------------------------+
//| Inicializar SVM                                                |
//+------------------------------------------------------------------+
void InitializeSVM(int index) {
    svmSignals[index].direction = 0;
    svmSignals[index].confidence = 0;
    svmSignals[index].newStart = SAR_Start;
    svmSignals[index].newIncrement = SAR_Increment;
    svmSignals[index].newMaximum = SAR_Maximum;
    svmSignals[index].timestamp = 0;
}

//+------------------------------------------------------------------+
//| Actualizar información de cuenta                               |
//+------------------------------------------------------------------+
void UpdateAccountInfo() {
    currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
}

//+------------------------------------------------------------------+
//| Verificar límites de riesgo                                   |
//+------------------------------------------------------------------+
bool CheckRiskLimits() {
    // Calcular drawdown
    double drawdown = 0;
    if(initialBalance > 0) {
        drawdown = (initialBalance - currentEquity) / initialBalance * 100.0;
    }
    
    if(drawdown > MaxDrawdownPercent) {
        Print("ALERTA: Drawdown máximo excedido: ", drawdown, "%");
        return false;
    }
    
    // Calcular VaR simplificado
    double totalRisk = CalculateVaR();
    if(totalRisk > VaRLimit) {
        Print("ALERTA: Límite VaR excedido: ", totalRisk, "%");
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Calcular VaR                                                   |
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
    
    return currentEquity > 0 ? (totalRisk / currentEquity) * 100.0 : 0.0;
}

//+------------------------------------------------------------------+
//| Leer señales SVM                                               |
//+------------------------------------------------------------------+
void ReadSVMSignals() {
    int fileHandle = FileOpen(SVMFile, FILE_READ | FILE_CSV);
    if(fileHandle == INVALID_HANDLE) return;
    
    while(!FileIsEnding(fileHandle)) {
        string symbol = FileReadString(fileHandle);
        int direction = (int)FileReadNumber(fileHandle);
        double confidence = FileReadNumber(fileHandle);
        double newStart = FileReadNumber(fileHandle);
        double newIncrement = FileReadNumber(fileHandle);
        double newMaximum = FileReadNumber(fileHandle);
        datetime timestamp = (datetime)FileReadNumber(fileHandle);
        
        int index = GetSymbolIndex(symbol);
        if(index >= 0 && timestamp > svmSignals[index].timestamp) {
            svmSignals[index].direction = direction;
            svmSignals[index].confidence = confidence;
            svmSignals[index].newStart = newStart;
            svmSignals[index].newIncrement = newIncrement;
            svmSignals[index].newMaximum = newMaximum;
            svmSignals[index].timestamp = timestamp;
        }
    }
    
    FileClose(fileHandle);
}

//+------------------------------------------------------------------+
//| Obtener índice del símbolo                                     |
//+------------------------------------------------------------------+
int GetSymbolIndex(string symbol) {
    for(int i = 0; i < totalSymbols; i++) {
        if(symbols[i] == symbol) return i;
    }
    return -1;
}

//+------------------------------------------------------------------+
//| Procesar símbolo                                               |
//+------------------------------------------------------------------+
void ProcessSymbol(int index) {
    string symbol = symbols[index];
    
    // Calcular Parabolic SAR
    CalculateParabolicSAR(index);
    
    // Verificar señales de trading
    if(EnableTrading) {
        CheckTradingSignals(index);
    }
    
    // Gestionar posiciones existentes
    ManagePositions(index);
}

//+------------------------------------------------------------------+
//| Calcular Parabolic SAR                                         |
//+------------------------------------------------------------------+
void CalculateParabolicSAR(int index) {
    string symbol = symbols[index];
    
    // Obtener datos de barras
    MqlRates rates[];
    if(CopyRates(symbol, PERIOD_CURRENT, 0, 3, rates) < 3) return;
    
    datetime currentTime = rates[2].time;
    if(currentTime == sarData[index].lastUpdate) return;
    
    double high = rates[2].high;
    double low = rates[2].low;
    double close = rates[2].close;
    double prevClose = rates[1].close;
    
    // Usar parámetros SVM si están disponibles
    double start = SAR_Start;
    double increment = SAR_Increment;
    double maximum = SAR_Maximum;
    
    if(EnableSVMSignals && svmSignals[index].confidence > 0.6) {
        start = svmSignals[index].newStart;
        increment = svmSignals[index].newIncrement;
        maximum = svmSignals[index].newMaximum;
    }
    
    // Primera inicialización
    if(sarData[index].lastUpdate == 0) {
        if(close > prevClose) {
            sarData[index].uptrend = true;
            sarData[index].EP = high;
            sarData[index].SAR = rates[1].low;
        } else {
            sarData[index].uptrend = false;
            sarData[index].EP = low;
            sarData[index].SAR = rates[1].high;
        }
        sarData[index].AF = start;
        sarData[index].lastUpdate = currentTime;
        return;
    }
    
    sarData[index].lastUpdate = currentTime;
    sarData[index].signalGenerated = false;
    
    // Verificar reversión
    if(sarData[index].uptrend && sarData[index].SAR > low) {
        // Cambio a bajista
        sarData[index].uptrend = false;
        sarData[index].SAR = sarData[index].EP;
        sarData[index].EP = low;
        sarData[index].AF = start;
        sarData[index].signalGenerated = true;
    } else if(!sarData[index].uptrend && sarData[index].SAR < high) {
        // Cambio a alcista
        sarData[index].uptrend = true;
        sarData[index].SAR = sarData[index].EP;
        sarData[index].EP = high;
        sarData[index].AF = start;
        sarData[index].signalGenerated = true;
    } else {
        // Actualizar EP y AF
        if(sarData[index].uptrend && high > sarData[index].EP) {
            sarData[index].EP = high;
            sarData[index].AF = MathMin(sarData[index].AF + increment, maximum);
        } else if(!sarData[index].uptrend && low < sarData[index].EP) {
            sarData[index].EP = low;
            sarData[index].AF = MathMin(sarData[index].AF + increment, maximum);
        }
    }
    
    // Calcular próximo SAR
    sarData[index].nextSAR = sarData[index].SAR + sarData[index].AF * (sarData[index].EP - sarData[index].SAR);
}

//+------------------------------------------------------------------+
//| Verificar señales de trading                                   |
//+------------------------------------------------------------------+
void CheckTradingSignals(int index) {
    if(!sarData[index].signalGenerated) return;
    
    string symbol = symbols[index];
    
    // Verificar señal SVM si está habilitada
    if(EnableSVMSignals && svmSignals[index].confidence > 0) {
        if(sarData[index].uptrend && svmSignals[index].direction != 1) return;
        if(!sarData[index].uptrend && svmSignals[index].direction != -1) return;
    }
    
    // Evitar trading muy frecuente
    if(TimeCurrent() - martingale[index].lastTradeTime < 300) return; // 5 minutos
    
    // Cerrar posiciones contrarias
    CloseOppositePositions(index);
    
    // Abrir nueva posición
    if(sarData[index].uptrend) {
        OpenPosition(index, ORDER_TYPE_BUY);
    } else {
        OpenPosition(index, ORDER_TYPE_SELL);
    }
}

//+------------------------------------------------------------------+
//| Cerrar posiciones contrarias                                   |
//+------------------------------------------------------------------+
void CloseOppositePositions(int index) {
    string symbol = symbols[index];
    
    for(int i = PositionsTotal() - 1; i >= 0; i--) {
        if(positionInfo.SelectByIndex(i) && 
           positionInfo.Symbol() == symbol && 
           positionInfo.Magic() == MagicNumber) {
            
            bool shouldClose = false;
            if(sarData[index].uptrend && positionInfo.PositionType() == POSITION_TYPE_SELL) {
                shouldClose = true;
            }
            if(!sarData[index].uptrend && positionInfo.PositionType() == POSITION_TYPE_BUY) {
                shouldClose = true;
            }
            
            if(shouldClose) {
                double profit = positionInfo.Profit();
                trade.PositionClose(positionInfo.Ticket());
                
                // Actualizar Martingala
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
//| Abrir posición                                                 |
//+------------------------------------------------------------------+
void OpenPosition(int index, ENUM_ORDER_TYPE orderType) {
    string symbol = symbols[index];
    
    // Calcular tamaño de lote
    double lotSize = CalculateLotSize(index);
    if(lotSize <= 0) return;
    
    // Obtener precios
    double price = (orderType == ORDER_TYPE_BUY) ? 
                   SymbolInfoDouble(symbol, SYMBOL_ASK) : 
                   SymbolInfoDouble(symbol, SYMBOL_BID);
    
    // Configurar SL usando SAR
    double stopLoss = sarData[index].SAR;
    double takeProfit = 0; // Sin TP fijo
    
    // Comentario
    string comment = "SAR_" + (sarData[index].uptrend ? "LONG" : "SHORT");
    
    // Ejecutar orden
    if(trade.PositionOpen(symbol, orderType, lotSize, price, stopLoss, takeProfit, comment)) {
        Print("POSICIÓN ABIERTA: ", symbol, " ", EnumToString(orderType), " ", lotSize);
        martingale[index].lastTradeTime = TimeCurrent();
        martingale[index].lastLot = lotSize;
    }
}

//+------------------------------------------------------------------+
//| Calcular tamaño de lote                                        |
//+------------------------------------------------------------------+
double CalculateLotSize(int index) {
    double baseLot = BaseLotSize;
    
    // Aplicar Martingala
    if(EnableMartingale && martingale[index].level > 0) {
        baseLot = martingale[index].lastLot * MathPow(MartingaleMultiplier, martingale[index].level);
    }
    
    // Verificar límites
    string symbol = symbols[index];
    double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    double stepLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
    
    baseLot = MathMax(baseLot, minLot);
    baseLot = MathMin(baseLot, maxLot);
    
    // Normalizar
    if(stepLot > 0) {
        baseLot = NormalizeDouble(baseLot / stepLot, 0) * stepLot;
    }
    
    return baseLot;
}

//+------------------------------------------------------------------+
//| Gestionar posiciones                                           |
//+------------------------------------------------------------------+
void ManagePositions(int index) {
    string symbol = symbols[index];
    
    for(int i = 0; i < PositionsTotal(); i++) {
        if(positionInfo.SelectByIndex(i) && 
           positionInfo.Symbol() == symbol && 
           positionInfo.Magic() == MagicNumber) {
            
            // Trailing stop con SAR
            UpdateTrailingStop(index);
        }
    }
}

//+------------------------------------------------------------------+
//| Actualizar trailing stop                                       |
//+------------------------------------------------------------------+
void UpdateTrailingStop(int index) {
    string symbol = symbols[index];
    double currentSAR = sarData[index].SAR;
    
    for(int i = 0; i < PositionsTotal(); i++) {
        if(positionInfo.SelectByIndex(i) && 
           positionInfo.Symbol() == symbol && 
           positionInfo.Magic() == MagicNumber) {
            
            double newSL = 0;
            bool shouldUpdate = false;
            
            if(positionInfo.PositionType() == POSITION_TYPE_BUY) {
                if(currentSAR > positionInfo.StopLoss() && currentSAR < positionInfo.PriceCurrent()) {
                    newSL = currentSAR;
                    shouldUpdate = true;
                }
            } else {
                if((currentSAR < positionInfo.StopLoss() || positionInfo.StopLoss() == 0) && 
                   currentSAR > positionInfo.PriceCurrent()) {
                    newSL = currentSAR;
                    shouldUpdate = true;
                }
            }
            
            if(shouldUpdate) {
                trade.PositionModify(positionInfo.Ticket(), newSL, positionInfo.TakeProfit());
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Timer function                                                  |
//+------------------------------------------------------------------+
void OnTimer() {
    // Exportar datos para SVM
    ExportDataForSVM();
    
    // Mostrar estadísticas
    ShowStatistics();
}

//+------------------------------------------------------------------+
//| Exportar datos para SVM                                        |
//+------------------------------------------------------------------+
void ExportDataForSVM() {
    static datetime lastExport = 0;
    if(TimeCurrent() - lastExport < 1800) return; // Cada 30 minutos
    lastExport = TimeCurrent();
    
    string filename = "trading_results_" + TimeToString(TimeCurrent(), TIME_DATE) + ".csv";
    int fileHandle = FileOpen(filename, FILE_WRITE | FILE_CSV);
    
    if(fileHandle != INVALID_HANDLE) {
        // Encabezados
        FileWrite(fileHandle, "Symbol", "Timestamp", "SAR", "EP", "AF", "Uptrend", 
                 "Price", "Profit", "Positions", "MartingaleLevel");
        
        // Datos por símbolo
        for(int i = 0; i < totalSymbols; i++) {
            if(!symbolEnabled[i]) continue;
            
            string symbol = symbols[i];
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
            
            FileWrite(fileHandle, symbol, TimeCurrent(), sarData[i].SAR, sarData[i].EP,
                     sarData[i].AF, sarData[i].uptrend ? 1 : 0, price, profit,
                     positions, martingale[i].level);
        }
        
        FileClose(fileHandle);
    }
}

//+------------------------------------------------------------------+
//| Mostrar estadísticas                                           |
//+------------------------------------------------------------------+
void ShowStatistics() {
    static datetime lastShow = 0;
    if(TimeCurrent() - lastShow < 900) return; // Cada 15 minutos
    lastShow = TimeCurrent();
    
    double totalProfit = 0;
    int totalPositions = 0;
    
    for(int i = 0; i < PositionsTotal(); i++) {
        if(positionInfo.SelectByIndex(i) && positionInfo.Magic() == MagicNumber) {
            totalProfit += positionInfo.Profit();
            totalPositions++;
        }
    }
    
    double drawdown = initialBalance > 0 ? (initialBalance - currentEquity) / initialBalance * 100.0 : 0;
    
    Print("=== ESTADÍSTICAS ===");
    Print("Posiciones activas: ", totalPositions);
    Print("P&L total: ", DoubleToString(totalProfit, 2));
    Print("Equity: ", DoubleToString(currentEquity, 2));
    Print("Drawdown: ", DoubleToString(drawdown, 2), "%");
    Print("VaR: ", DoubleToString(CalculateVaR(), 2), "%");
}

//+------------------------------------------------------------------+