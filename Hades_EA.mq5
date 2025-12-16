//+------------------------------------------------------------------+
//|                                                     Hades_EA.mq5 |
//|                          Hadès - Trend Following EA for FTMO    |
//|                     Inspired by top MQL5 profitable strategies   |
//+------------------------------------------------------------------+
#property copyright "Hadès Trading System"
#property link      "https://github.com/tradingluca31-boop/Had-s"
#property version   "1.00"
#property description "Hadès EA - Professional Trend Following System"
#property description "Designed for FTMO Challenge - 7 Major Pairs"
#property description "Strategy: EMA Trend + ATR Breakout + Price Action"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>
#include <Trade\SymbolInfo.mqh>

//+------------------------------------------------------------------+
//| Input Parameters - Risk Management FTMO                          |
//+------------------------------------------------------------------+
input group "=== RISK MANAGEMENT FTMO ==="
input double   InpRiskPercent        = 1.0;        // Risk % per trade
input double   InpMaxDailyDrawdown   = 4.5;        // Max Daily Drawdown % (FTMO: 5%)
input double   InpMaxTotalDrawdown   = 9.0;        // Max Total Drawdown % (FTMO: 10%)
input int      InpMaxTradesPerDay    = 2;          // Max trades per day
input int      InpMaxOpenTrades      = 1;          // Max simultaneous trades

input group "=== STRATEGY PARAMETERS ==="
input double   InpRiskReward         = 3.0;        // Risk/Reward Ratio (1:X)
input int      InpEmaFast            = 21;         // Fast EMA Period
input int      InpEmaMedium          = 50;         // Medium EMA Period
input int      InpEmaSlow            = 200;        // Slow EMA Period
input int      InpRsiPeriod          = 14;         // RSI Period
input int      InpRsiOverbought      = 70;         // RSI Overbought Level
input int      InpRsiOversold        = 30;         // RSI Oversold Level
input int      InpAtrPeriod          = 14;         // ATR Period
input double   InpAtrMultiplier      = 1.5;        // ATR Multiplier for SL

input group "=== TRAILING STOP ==="
input bool     InpUseTrailingStop    = true;       // Use Trailing Stop
input double   InpTrailingAtrMult    = 1.0;        // Trailing ATR Multiplier
input int      InpTrailingStartPips  = 30;         // Start Trailing after X pips profit

input group "=== SESSION FILTER ==="
input bool     InpUseSessions        = true;       // Use Session Filter
input int      InpLondonStart        = 8;          // London Session Start (Server Time)
input int      InpLondonEnd          = 17;         // London Session End (Server Time)
input int      InpNewYorkStart       = 13;         // New York Session Start (Server Time)
input int      InpNewYorkEnd         = 22;         // New York Session End (Server Time)

input group "=== BREAKOUT SETTINGS ==="
input int      InpBreakoutPeriod     = 20;         // Breakout Period (High/Low)
input int      InpBreakoutShift      = 1;          // Breakout Shift

input group "=== GENERAL SETTINGS ==="
input ulong    InpMagicNumber        = 2024123;    // Magic Number
input string   InpTradeComment       = "Hades_EA"; // Trade Comment
input ENUM_TIMEFRAMES InpTimeframe   = PERIOD_H1;  // Trading Timeframe

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
CTrade         trade;
CPositionInfo  posInfo;
CAccountInfo   accInfo;
CSymbolInfo    symInfo;

// Indicator handles
int handleEmaFast;
int handleEmaMedium;
int handleEmaSlow;
int handleRsi;
int handleAtr;

// Buffers
double emaFastBuffer[];
double emaMediumBuffer[];
double emaSlowBuffer[];
double rsiBuffer[];
double atrBuffer[];

// Tracking variables
double initialBalance;
double dailyStartBalance;
datetime lastTradeDay;
int tradesToday;
double highestEquity;

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialize trade object
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(30);
   trade.SetTypeFilling(ORDER_FILLING_IOC);

   // Initialize symbol info
   if(!symInfo.Name(Symbol()))
   {
      Print("Failed to initialize symbol info");
      return INIT_FAILED;
   }

   // Create indicator handles
   handleEmaFast = iMA(Symbol(), InpTimeframe, InpEmaFast, 0, MODE_EMA, PRICE_CLOSE);
   handleEmaMedium = iMA(Symbol(), InpTimeframe, InpEmaMedium, 0, MODE_EMA, PRICE_CLOSE);
   handleEmaSlow = iMA(Symbol(), InpTimeframe, InpEmaSlow, 0, MODE_EMA, PRICE_CLOSE);
   handleRsi = iRSI(Symbol(), InpTimeframe, InpRsiPeriod, PRICE_CLOSE);
   handleAtr = iATR(Symbol(), InpTimeframe, InpAtrPeriod);

   // Check handles
   if(handleEmaFast == INVALID_HANDLE || handleEmaMedium == INVALID_HANDLE ||
      handleEmaSlow == INVALID_HANDLE || handleRsi == INVALID_HANDLE ||
      handleAtr == INVALID_HANDLE)
   {
      Print("Failed to create indicator handles");
      return INIT_FAILED;
   }

   // Set buffer arrays as series
   ArraySetAsSeries(emaFastBuffer, true);
   ArraySetAsSeries(emaMediumBuffer, true);
   ArraySetAsSeries(emaSlowBuffer, true);
   ArraySetAsSeries(rsiBuffer, true);
   ArraySetAsSeries(atrBuffer, true);

   // Initialize tracking variables
   initialBalance = accInfo.Balance();
   dailyStartBalance = initialBalance;
   lastTradeDay = 0;
   tradesToday = 0;
   highestEquity = initialBalance;

   Print("=== Hadès EA Initialized ===");
   Print("Initial Balance: ", initialBalance);
   Print("Risk per trade: ", InpRiskPercent, "%");
   Print("Max Daily DD: ", InpMaxDailyDrawdown, "%");
   Print("Symbol: ", Symbol());

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Release indicator handles
   if(handleEmaFast != INVALID_HANDLE) IndicatorRelease(handleEmaFast);
   if(handleEmaMedium != INVALID_HANDLE) IndicatorRelease(handleEmaMedium);
   if(handleEmaSlow != INVALID_HANDLE) IndicatorRelease(handleEmaSlow);
   if(handleRsi != INVALID_HANDLE) IndicatorRelease(handleRsi);
   if(handleAtr != INVALID_HANDLE) IndicatorRelease(handleAtr);

   Print("=== Hadès EA Deinitialized ===");
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   // Update symbol info
   symInfo.Refresh();
   symInfo.RefreshRates();

   // Check for new day - reset daily counters
   CheckNewDay();

   // Update highest equity for drawdown tracking
   double currentEquity = accInfo.Equity();
   if(currentEquity > highestEquity)
      highestEquity = currentEquity;

   // FTMO Safety Checks
   if(!CheckFTMOLimits())
   {
      ManageTrailingStop(); // Still manage open positions
      return;
   }

   // Manage existing positions (trailing stop)
   ManageTrailingStop();

   // Check if we can open new trades
   if(!CanOpenNewTrade())
      return;

   // Check session filter
   if(InpUseSessions && !IsValidSession())
      return;

   // Only check for new signals on new bar
   if(!IsNewBar())
      return;

   // Get indicator values
   if(!GetIndicatorValues())
      return;

   // Check for trade signals
   int signal = GetTradeSignal();

   if(signal != 0)
   {
      ExecuteTrade(signal);
   }
}

//+------------------------------------------------------------------+
//| Check for new day and reset counters                              |
//+------------------------------------------------------------------+
void CheckNewDay()
{
   datetime currentDay = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));

   if(currentDay != lastTradeDay)
   {
      lastTradeDay = currentDay;
      tradesToday = 0;
      dailyStartBalance = accInfo.Balance();
      Print("New trading day - Counters reset. Daily Start Balance: ", dailyStartBalance);
   }
}

//+------------------------------------------------------------------+
//| Check FTMO drawdown limits                                        |
//+------------------------------------------------------------------+
bool CheckFTMOLimits()
{
   double currentEquity = accInfo.Equity();
   double currentBalance = accInfo.Balance();

   // Check Daily Drawdown
   double dailyDD = ((dailyStartBalance - currentEquity) / dailyStartBalance) * 100;
   if(dailyDD >= InpMaxDailyDrawdown)
   {
      Print("FTMO ALERT: Daily Drawdown limit reached! DD: ", dailyDD, "%");
      CloseAllPositions("Daily DD Limit");
      return false;
   }

   // Check Total Drawdown from highest equity
   double totalDD = ((highestEquity - currentEquity) / initialBalance) * 100;
   if(totalDD >= InpMaxTotalDrawdown)
   {
      Print("FTMO ALERT: Total Drawdown limit reached! DD: ", totalDD, "%");
      CloseAllPositions("Total DD Limit");
      return false;
   }

   // Warning at 80% of limits
   if(dailyDD >= InpMaxDailyDrawdown * 0.8)
      Print("WARNING: Approaching Daily DD limit - ", dailyDD, "%");

   if(totalDD >= InpMaxTotalDrawdown * 0.8)
      Print("WARNING: Approaching Total DD limit - ", totalDD, "%");

   return true;
}

//+------------------------------------------------------------------+
//| Check if we can open new trade                                    |
//+------------------------------------------------------------------+
bool CanOpenNewTrade()
{
   // Check max trades per day
   if(tradesToday >= InpMaxTradesPerDay)
   {
      return false;
   }

   // Check max open trades
   int openTrades = CountOpenTrades();
   if(openTrades >= InpMaxOpenTrades)
   {
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Count open trades for this EA                                     |
//+------------------------------------------------------------------+
int CountOpenTrades()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(posInfo.SelectByIndex(i))
      {
         if(posInfo.Magic() == InpMagicNumber && posInfo.Symbol() == Symbol())
            count++;
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Check if within valid trading sessions                            |
//+------------------------------------------------------------------+
bool IsValidSession()
{
   MqlDateTime dt;
   TimeCurrent(dt);
   int hour = dt.hour;

   // London Session
   bool inLondon = (hour >= InpLondonStart && hour < InpLondonEnd);

   // New York Session
   bool inNewYork = (hour >= InpNewYorkStart && hour < InpNewYorkEnd);

   return (inLondon || inNewYork);
}

//+------------------------------------------------------------------+
//| Check for new bar                                                 |
//+------------------------------------------------------------------+
bool IsNewBar()
{
   static datetime lastBarTime = 0;
   datetime currentBarTime = iTime(Symbol(), InpTimeframe, 0);

   if(currentBarTime != lastBarTime)
   {
      lastBarTime = currentBarTime;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Get indicator values                                              |
//+------------------------------------------------------------------+
bool GetIndicatorValues()
{
   // Copy indicator buffers
   if(CopyBuffer(handleEmaFast, 0, 0, 3, emaFastBuffer) < 3) return false;
   if(CopyBuffer(handleEmaMedium, 0, 0, 3, emaMediumBuffer) < 3) return false;
   if(CopyBuffer(handleEmaSlow, 0, 0, 3, emaSlowBuffer) < 3) return false;
   if(CopyBuffer(handleRsi, 0, 0, 3, rsiBuffer) < 3) return false;
   if(CopyBuffer(handleAtr, 0, 0, 3, atrBuffer) < 3) return false;

   return true;
}

//+------------------------------------------------------------------+
//| Get trade signal                                                  |
//+------------------------------------------------------------------+
int GetTradeSignal()
{
   // Get current price data
   double close1 = iClose(Symbol(), InpTimeframe, 1);
   double close2 = iClose(Symbol(), InpTimeframe, 2);

   // Get breakout levels
   double highestHigh = GetHighestHigh(InpBreakoutPeriod, InpBreakoutShift);
   double lowestLow = GetLowestLow(InpBreakoutPeriod, InpBreakoutShift);

   // EMA Trend Alignment (Triple EMA Filter)
   bool bullishTrend = (emaFastBuffer[1] > emaMediumBuffer[1]) &&
                       (emaMediumBuffer[1] > emaSlowBuffer[1]);
   bool bearishTrend = (emaFastBuffer[1] < emaMediumBuffer[1]) &&
                       (emaMediumBuffer[1] < emaSlowBuffer[1]);

   // RSI Filter
   bool rsiNotOverbought = rsiBuffer[1] < InpRsiOverbought;
   bool rsiNotOversold = rsiBuffer[1] > InpRsiOversold;
   bool rsiTrendingUp = rsiBuffer[1] > 50;
   bool rsiTrendingDown = rsiBuffer[1] < 50;

   // Breakout Detection
   bool bullishBreakout = (close1 > highestHigh) && (close2 <= highestHigh);
   bool bearishBreakout = (close1 < lowestLow) && (close2 >= lowestLow);

   // Price Action - Price above/below EMAs
   bool priceAboveEmas = close1 > emaFastBuffer[1];
   bool priceBelowEmas = close1 < emaFastBuffer[1];

   // BUY Signal: Bullish trend + Breakout + RSI confirmation
   if(bullishTrend && bullishBreakout && rsiNotOverbought && rsiTrendingUp && priceAboveEmas)
   {
      Print("BUY Signal detected - Trend: Bullish, Breakout: Up, RSI: ", rsiBuffer[1]);
      return 1;
   }

   // SELL Signal: Bearish trend + Breakout + RSI confirmation
   if(bearishTrend && bearishBreakout && rsiNotOversold && rsiTrendingDown && priceBelowEmas)
   {
      Print("SELL Signal detected - Trend: Bearish, Breakout: Down, RSI: ", rsiBuffer[1]);
      return -1;
   }

   return 0;
}

//+------------------------------------------------------------------+
//| Get highest high for breakout                                     |
//+------------------------------------------------------------------+
double GetHighestHigh(int period, int shift)
{
   double highest = 0;
   for(int i = shift; i < period + shift; i++)
   {
      double high = iHigh(Symbol(), InpTimeframe, i);
      if(high > highest || highest == 0)
         highest = high;
   }
   return highest;
}

//+------------------------------------------------------------------+
//| Get lowest low for breakout                                       |
//+------------------------------------------------------------------+
double GetLowestLow(int period, int shift)
{
   double lowest = 0;
   for(int i = shift; i < period + shift; i++)
   {
      double low = iLow(Symbol(), InpTimeframe, i);
      if(low < lowest || lowest == 0)
         lowest = low;
   }
   return lowest;
}

//+------------------------------------------------------------------+
//| Execute trade                                                     |
//+------------------------------------------------------------------+
void ExecuteTrade(int signal)
{
   double atr = atrBuffer[1];
   double point = symInfo.Point();
   int digits = symInfo.Digits();
   double bid = symInfo.Bid();
   double ask = symInfo.Ask();

   // Calculate Stop Loss in price
   double slDistance = atr * InpAtrMultiplier;

   // Calculate Take Profit based on RR ratio
   double tpDistance = slDistance * InpRiskReward;

   double entryPrice, sl, tp;
   ENUM_ORDER_TYPE orderType;

   if(signal == 1) // BUY
   {
      orderType = ORDER_TYPE_BUY;
      entryPrice = ask;
      sl = NormalizeDouble(entryPrice - slDistance, digits);
      tp = NormalizeDouble(entryPrice + tpDistance, digits);
   }
   else // SELL
   {
      orderType = ORDER_TYPE_SELL;
      entryPrice = bid;
      sl = NormalizeDouble(entryPrice + slDistance, digits);
      tp = NormalizeDouble(entryPrice - tpDistance, digits);
   }

   // Calculate lot size based on risk
   double lotSize = CalculateLotSize(slDistance);

   if(lotSize <= 0)
   {
      Print("Invalid lot size calculated: ", lotSize);
      return;
   }

   // Validate SL/TP distances
   double minStopLevel = symInfo.StopsLevel() * point;
   if(slDistance < minStopLevel || tpDistance < minStopLevel)
   {
      Print("SL/TP too close to entry. Min stop level: ", minStopLevel);
      return;
   }

   // Execute order
   if(trade.PositionOpen(Symbol(), orderType, lotSize, entryPrice, sl, tp, InpTradeComment))
   {
      tradesToday++;
      Print("Trade opened successfully - Type: ", EnumToString(orderType),
            " Lots: ", lotSize, " Entry: ", entryPrice, " SL: ", sl, " TP: ", tp);
   }
   else
   {
      Print("Trade failed - Error: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| Calculate lot size based on risk percentage                       |
//+------------------------------------------------------------------+
double CalculateLotSize(double slDistance)
{
   double accountBalance = accInfo.Balance();
   double riskAmount = accountBalance * (InpRiskPercent / 100.0);

   // Get tick value
   double tickValue = symInfo.TickValue();
   double tickSize = symInfo.TickSize();

   if(tickSize == 0) return 0;

   // Calculate pip value
   double slPips = slDistance / tickSize;

   // Calculate lot size
   double lotSize = riskAmount / (slPips * tickValue);

   // Normalize lot size
   double minLot = symInfo.LotsMin();
   double maxLot = symInfo.LotsMax();
   double lotStep = symInfo.LotsStep();

   lotSize = MathFloor(lotSize / lotStep) * lotStep;
   lotSize = MathMax(minLot, lotSize);
   lotSize = MathMin(maxLot, lotSize);

   // Additional safety - never risk more than account can handle
   double maxLotByMargin = accInfo.FreeMargin() / symInfo.MarginInitial();
   if(maxLotByMargin > 0)
      lotSize = MathMin(lotSize, maxLotByMargin * 0.5);

   return NormalizeDouble(lotSize, 2);
}

//+------------------------------------------------------------------+
//| Manage trailing stop                                              |
//+------------------------------------------------------------------+
void ManageTrailingStop()
{
   if(!InpUseTrailingStop)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i))
         continue;

      if(posInfo.Magic() != InpMagicNumber || posInfo.Symbol() != Symbol())
         continue;

      double atr = atrBuffer[1];
      double trailingDistance = atr * InpTrailingAtrMult;
      double point = symInfo.Point();
      int digits = symInfo.Digits();

      double currentPrice = posInfo.PositionType() == POSITION_TYPE_BUY ?
                           symInfo.Bid() : symInfo.Ask();
      double openPrice = posInfo.PriceOpen();
      double currentSL = posInfo.StopLoss();
      double currentTP = posInfo.TakeProfit();

      // Calculate profit in pips
      double profitPips;
      if(posInfo.PositionType() == POSITION_TYPE_BUY)
         profitPips = (currentPrice - openPrice) / point;
      else
         profitPips = (openPrice - currentPrice) / point;

      // Only start trailing after minimum profit
      if(profitPips < InpTrailingStartPips)
         continue;

      double newSL;

      if(posInfo.PositionType() == POSITION_TYPE_BUY)
      {
         newSL = NormalizeDouble(currentPrice - trailingDistance, digits);
         if(newSL > currentSL && newSL < currentPrice)
         {
            if(trade.PositionModify(posInfo.Ticket(), newSL, currentTP))
               Print("Trailing Stop updated (BUY) - New SL: ", newSL);
         }
      }
      else // SELL
      {
         newSL = NormalizeDouble(currentPrice + trailingDistance, digits);
         if((newSL < currentSL || currentSL == 0) && newSL > currentPrice)
         {
            if(trade.PositionModify(posInfo.Ticket(), newSL, currentTP))
               Print("Trailing Stop updated (SELL) - New SL: ", newSL);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Close all positions                                               |
//+------------------------------------------------------------------+
void CloseAllPositions(string reason)
{
   Print("Closing all positions - Reason: ", reason);

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i))
         continue;

      if(posInfo.Magic() != InpMagicNumber || posInfo.Symbol() != Symbol())
         continue;

      trade.PositionClose(posInfo.Ticket());
   }
}

//+------------------------------------------------------------------+
//| OnTradeTransaction - Track trade results                          |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
{
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
   {
      if(trans.deal_type == DEAL_TYPE_BUY || trans.deal_type == DEAL_TYPE_SELL)
      {
         // Trade executed
      }
   }
}
//+------------------------------------------------------------------+
