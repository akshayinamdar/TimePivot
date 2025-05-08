//+------------------------------------------------------------------+
//|                                                    TimePivot.mq5 |
//|                                          Copyright 2025, TimePivot |
//|                           https://github.com/akshayinamdar/TimePivot |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, TimePivot"
#property link      "https://github.com/akshayinamdar/TimePivot"
#property version   "1.00"
#property strict

// Import necessary libraries
#include <Trade\Trade.mqh>
#include <Arrays\ArrayDouble.mqh>

// Input Parameters
// ===============================
// Risk Management
input double   InpRiskPercent = 1.0;             // Risk per trade (% of balance)
input int      InpMaxConcurrentTrades = 1;       // Maximum concurrent trades per symbol
input double   InpDailyLossLimit = 30.0;         // Daily loss limit (%)
input double   InpStepDownLevel1 = 15.0;         // First level to reduce position size (%)
input double   InpStepDownLevel2 = 24.0;         // Second level to limit to trend direction (%)

// Time-based Exit Parameters
input int      InpLossTimeLimit = 10;            // Time to cut losses (minutes)
input int      InpProfitRunTimeMultiplier = 6;   // Profit run time multiplier
input double   InpMinProfitPoints = 15.0;        // Minimum profit points to consider trade profitable
input double   InpCommissionPoints = 10.0;       // Commission in points per trade (1 pip = 10 points)
input double   InpRiskRewardRatio = 1.5;         // Risk to Reward ratio (reward:risk)

// Trading Hours Restrictions
input bool     InpUseTimeRestrictions = true;    // Use trading hour restrictions
input int      InpTradingStartHour = 6;          // Trading start hour (0-23)
input int      InpTradingEndHour = 20;           // Trading end hour (0-23) - Reduced to avoid last hour trades
input int      InpCloseAllHour = 22;             // Hour to close all trades to avoid swap (0-23)
input int      InpMinutesBeforeSessionEnd = 30;  // Minutes before session end to stop new trades

// Momentum & Volatility Parameters
input int      InpTickMomentumPeriod = 30;       // Ticks to analyze for momentum (increased)
input double   InpMomentumThreshold = 2.0;       // Momentum burst threshold multiplier (increased)
input double   InpDirectionalThreshold = 0.7;     // Directional strength threshold (0.0-1.0) (increased)
input double   InpVolatilityThreshold = 2.0;     // Volatility expansion threshold (std dev)
input double   InpLowVolFreqThreshold = 0.6;     // Low volatility frequency threshold (increased)

// Global Variables
// ===============================
CTrade        Trade;                              // Trading object
MqlTick       LastTick;                           // Latest tick data
MqlTick       TickBuffer[];                       // Buffer to store recent ticks
datetime      LastTickTime = 0;                   // Time of last tick
datetime      DayStartTime;                       // Start of trading day
double        InitialBalance;                     // Starting balance for the day
double        DailyPnL = 0.0;                     // Daily profit/loss
int           ConsecutiveLosses = 0;              // Track consecutive losses
int           ConsecutiveWins = 0;                // Track consecutive wins
bool          TradingAllowed = true;              // Trading allowed flag
bool          TrendDirectionOnly = false;         // Only trade with trend flag
double        ReducedRiskFactor = 1.0;            // Risk reduction factor (0.0-1.0)

// Tick analysis variables
double        AvgTickVelocity = 0.0;              // Average tick movement speed
double        TickRanges[];                       // Recent tick ranges for volatility
double        BaselineTickFrequency = 0.0;        // Baseline tick frequency
int           TicksPerSecond = 0;                 // Current ticks per second
int           TickCounter = 0;                    // Tick counter
int           LastSecond = 0;                     // Last second for tick frequency
double        POINT_VALUE;                        // Point value for the symbol

// Trade management
struct TradeData {
   ulong  ticket;                                 // Trade ticket
   double openPrice;                              // Open price
   datetime openTime;                             // Open time
   double stopLoss;                               // Current stop loss
   double takeProfit;                             // Current take profit
   bool isLong;                                   // Long or short position
   bool partialClosed;                            // Flag for partial close
};
TradeData OpenTrades[10];                         // Track open trades
int OpenTradeCount = 0;                           // Count of open trades

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialize Trade settings
   Trade.SetDeviationInPoints(10);                // Slippage
   Trade.SetMarginMode();
   Trade.LogLevel(1);                             // Only errors
     // Initialize tick buffer
   ArrayResize(TickBuffer, InpTickMomentumPeriod);
   // Cannot use ArrayFill with MqlTick structure
   ZeroMemory(TickBuffer); // Initialize to zero values instead
   
   // Initialize tick ranges for volatility calculation
   ArrayResize(TickRanges, 100);
   ArrayFill(TickRanges, 0, 100, 0.0);
   
   // Get point value for the symbol
   POINT_VALUE = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   // Store initial account balance
   ResetDailyTracking();
     // Initialize tick frequency counter
   LastSecond = (int)(TimeLocal() % 86400); // Convert to seconds within day to avoid overflow
   TickCounter = 0;
   
   // Subscribe to tick events
   bool ticksSubscribed = SymbolSelect(_Symbol, true);
   if(!ticksSubscribed) {
      Print("Failed to subscribe to tick events for ", _Symbol);
      return INIT_FAILED;
   }
   
   Print("TimePivot EA initialized successfully");
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Clean up
   ArrayFree(TickBuffer);
   ArrayFree(TickRanges);
   
   Print("TimePivot EA deinitialized, reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Get current tick
   if(!SymbolInfoTick(_Symbol, LastTick)) {
      Print("Error getting tick: ", GetLastError());
      return;
   }
   
   // Check for new day
   CheckNewTradingDay();
   
   // Update tick analysis
   UpdateTickAnalysis();
   
   // Update trade management
   ManageOpenTrades();
   
   // Check if trading is allowed based on daily loss limit
   CheckDailyLossLimits();
     // Trading logic
   if(TradingAllowed && OpenTradeCount < InpMaxConcurrentTrades && IsWithinTradingHours()) {
      // Check for entry signals
      CheckEntrySignals();
   }
}

//+------------------------------------------------------------------+
//| Reset daily tracking values                                      |
//+------------------------------------------------------------------+
void ResetDailyTracking()
{
   InitialBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   DailyPnL = 0.0;
   DayStartTime = TimeCurrent();
   TradingAllowed = true;
   TrendDirectionOnly = false;
   ReducedRiskFactor = 1.0;
   
   Print("Daily tracking reset: Initial balance = ", InitialBalance);
}

//+------------------------------------------------------------------+
//| Check for a new trading day                                      |
//+------------------------------------------------------------------+
void CheckNewTradingDay()
{
   // Get current time
   MqlDateTime currentTime;
   TimeToStruct(TimeCurrent(), currentTime);
   
   // Get day start time
   MqlDateTime startTime;
   TimeToStruct(DayStartTime, startTime);
   
   // If day has changed, reset daily tracking
   if(currentTime.day != startTime.day || currentTime.mon != startTime.mon || currentTime.year != startTime.year) {
      ResetDailyTracking();
   }
}

//+------------------------------------------------------------------+
//| Update tick analysis (momentum, volatility)                      |
//+------------------------------------------------------------------+
void UpdateTickAnalysis()
{
   // Shift ticks in the buffer and add new tick
   for(int i = InpTickMomentumPeriod - 1; i > 0; i--) {
      TickBuffer[i] = TickBuffer[i-1];
   }
   TickBuffer[0] = LastTick;
     // Update tick counter for frequency
   int currentSecond = (int)(TimeLocal() % 86400); // Convert to seconds within day to avoid overflow
   if(currentSecond != LastSecond) {
      // If second changed, update tick frequency
      if(BaselineTickFrequency == 0) {
         BaselineTickFrequency = (double)TickCounter;
      } else {
         BaselineTickFrequency = 0.9 * BaselineTickFrequency + 0.1 * (double)TickCounter; // Explicit cast to double
      }
      
      TicksPerSecond = TickCounter;
      TickCounter = 0;
      LastSecond = currentSecond;
   }
   TickCounter++;
   
   // Calculate tick velocity and directional strength
   if(LastTickTime > 0) {
      // Calculate movement
      double totalMovement = 0;
      int upTicks = 0;
      int downTicks = 0;
      
      for(int i = 1; i < InpTickMomentumPeriod; i++) {
         if(TickBuffer[i].time == 0) continue;  // Skip uninitialized ticks
         
         double diff = TickBuffer[i-1].bid - TickBuffer[i].bid;
         totalMovement += MathAbs(diff);
         
         if(diff > 0) upTicks++;
         else if(diff < 0) downTicks++;
      }
      
      // Calculate average movement
      double avgMovement = totalMovement / InpTickMomentumPeriod;
      
      // Update tick velocity EMA (20% weight to current, 80% to history)
      AvgTickVelocity = (AvgTickVelocity == 0) ? avgMovement : 0.8 * AvgTickVelocity + 0.2 * avgMovement;
      
      // Calculate volatility - store tick range in circular buffer
      static int rangeIndex = 0;
      double currentRange = LastTick.ask - LastTick.bid;
      TickRanges[rangeIndex] = currentRange;
      rangeIndex = (rangeIndex + 1) % 100;
   }
   
   // Update last tick time
   LastTickTime = TimeCurrent();
}

//+------------------------------------------------------------------+
//| Check entry signals                                              |
//+------------------------------------------------------------------+
void CheckEntrySignals()
{
   // Check for enough tick data
   if(LastTickTime == 0 || AvgTickVelocity == 0) return;
   
   // First check - if we've had a recent trade, don't trade again too soon
   static datetime lastTradeTime = 0;
   if(TimeCurrent() - lastTradeTime < 5 * 60) { // Minimum 5 minutes between trade entries
      return;
   }
   
   // Calculate directional strength
   int upTicks = 0;
   int downTicks = 0;
   double totalMovement = 0;
   
   for(int i = 1; i < InpTickMomentumPeriod; i++) {
      if(TickBuffer[i].time == 0) continue;  // Skip uninitialized ticks
      
      double diff = TickBuffer[i-1].bid - TickBuffer[i].bid;
      totalMovement += MathAbs(diff);
      
      if(diff > 0) upTicks++;
      else if(diff < 0) downTicks++;
   }
   
   double directionStrength = 0;
   if(upTicks + downTicks > 0) {
      directionStrength = (double)(upTicks - downTicks) / (upTicks + downTicks);
   }
   
   // Calculate current tick velocity
   double currentTickVelocity = totalMovement / InpTickMomentumPeriod;
   
   // Check volatility conditions
   bool volatilityOK = CheckVolatilityConditions();
   if(!volatilityOK) return;  // Exit if volatility is not suitable
   
   // Get current market trend for confirmation
   double trend = CalculateTrend();
   
   // Calculate strength of signal (0.0 to 1.0)
   double bullStrength = (directionStrength > 0) ? directionStrength : 0;
   double bearStrength = (directionStrength < 0) ? -directionStrength : 0;
   
   // Detect momentum bursts - more stringent requirements
   bool bullishMomentum = currentTickVelocity > AvgTickVelocity * InpMomentumThreshold && 
                          directionStrength > InpDirectionalThreshold &&
                          (trend > 0 || bullStrength > InpDirectionalThreshold + 0.15); // Stronger signal needed against trend
                          
   bool bearishMomentum = currentTickVelocity > AvgTickVelocity * InpMomentumThreshold && 
                          directionStrength < -InpDirectionalThreshold &&
                          (trend < 0 || bearStrength > InpDirectionalThreshold + 0.15); // Stronger signal needed against trend
   
   // Check if trend direction only is enforced
   if(TrendDirectionOnly) {
      // Only allow trades in trend direction
      if(trend > 0) bearishMomentum = false;
      else if(trend < 0) bullishMomentum = false;
   }
   
   // Execute trades based on signals
   if(bullishMomentum) {
      OpenTrade(true);  // Long
      lastTradeTime = TimeCurrent(); // Update last trade time
   }
   else if(bearishMomentum) {
      OpenTrade(false);  // Short
      lastTradeTime = TimeCurrent(); // Update last trade time
   }
}

//+------------------------------------------------------------------+
//| Check volatility conditions                                      |
//+------------------------------------------------------------------+
bool CheckVolatilityConditions()
{
   // Calculate average tick range
   double sumRanges = 0;
   for(int i = 0; i < 100; i++) {
      sumRanges += TickRanges[i];
   }
   double avgTickRange = sumRanges / 100;
   
   // Calculate standard deviation of ranges
   double sumSquaredDiff = 0;
   for(int i = 0; i < 100; i++) {
      sumSquaredDiff += MathPow(TickRanges[i] - avgTickRange, 2);
   }
   double rangeStdDev = MathSqrt(sumSquaredDiff / 100);
   
   // Current tick range
   double currentRange = LastTick.ask - LastTick.bid;
   
   // Detect high volatility (range expansion)
   bool highVolatility = (currentRange > avgTickRange + InpVolatilityThreshold * rangeStdDev);
   
   // Detect low volatility (frequency based)
   bool lowVolatility = (BaselineTickFrequency > 0 && (double)TicksPerSecond < BaselineTickFrequency * InpLowVolFreqThreshold);
   
   // Check average tick frequency
   bool tickFrequencyOK = (BaselineTickFrequency > 0 && TicksPerSecond > BaselineTickFrequency * 0.8);
   
   // Avoid: high volatility, extremely low volatility, and low tick frequency
   return !highVolatility && !lowVolatility && tickFrequencyOK;
}

//+------------------------------------------------------------------+
//| Calculate overall trend                                          |
//+------------------------------------------------------------------+
double CalculateTrend()
{
   // Simple trend calculation using price comparison
   double prices[1000];
   if(CopyClose(_Symbol, PERIOD_M1, 0, 1000, prices) <= 0) {
      return 0.0;  // No trend data
   }
   
   // Compare first half to second half
   double firstHalfAvg = 0, secondHalfAvg = 0;
   
   for(int i = 0; i < 500; i++) {
      firstHalfAvg += prices[i];
   }
   firstHalfAvg /= 500;
   
   for(int i = 500; i < 1000; i++) {
      secondHalfAvg += prices[i];
   }
   secondHalfAvg /= 500;
   
   return secondHalfAvg - firstHalfAvg;  // Positive = uptrend, Negative = downtrend
}

//+------------------------------------------------------------------+
//| Open new trade                                                   |
//+------------------------------------------------------------------+
void OpenTrade(bool isLong)
{
   // Check if we can trade
   if(!TradingAllowed || OpenTradeCount >= InpMaxConcurrentTrades) return;
   
   // Check if within trading hours and not too close to session end
   if(InpUseTimeRestrictions) {
      if(!IsWithinTradingHours()) {
         Print("Trade signal detected but outside trading hours (", InpTradingStartHour, ":00 - ", InpTradingEndHour, ":00)");
         return;
      }
      
      // Check if too close to the end of trading session
      MqlDateTime currentTime;
      TimeToStruct(TimeCurrent(), currentTime);
      if(currentTime.hour == InpTradingEndHour && currentTime.min >= (60 - InpMinutesBeforeSessionEnd)) {
         Print("Trade signal detected but too close to session end time");
         return;
      }
   }
   
   // Calculate position size based on risk
   double stopLossDistance = 50 * POINT_VALUE;  // Wider stop loss (increased from 20)
   double riskAmount = AccountInfoDouble(ACCOUNT_BALANCE) * (InpRiskPercent / 100.0) * ReducedRiskFactor;
   double positionSize = CalculatePositionSize(riskAmount, stopLossDistance);
   
   // Define entry price
   double entryPrice = isLong ? LastTick.ask : LastTick.bid;
   
   // Define initial stop loss and take profit levels
   double stopLoss = isLong ? entryPrice - stopLossDistance : entryPrice + stopLossDistance;
   
   // Calculate take profit based on risk-reward ratio
   double takeProfitDistance = stopLossDistance * InpRiskRewardRatio;
   double takeProfit = isLong ? entryPrice + takeProfitDistance : entryPrice - takeProfitDistance;
   
   // Place the order
   bool result = false;
   if(isLong) {
      result = Trade.Buy(positionSize, _Symbol, 0, stopLoss, takeProfit, "TimePivot Long");
   } else {
      result = Trade.Sell(positionSize, _Symbol, 0, stopLoss, takeProfit, "TimePivot Short");
   }
   
   // Handle the result
   if(result) {
      ulong ticket = Trade.ResultOrder();
      
      // Store trade data
      if(OpenTradeCount < 10) {
         OpenTrades[OpenTradeCount].ticket = ticket;
         OpenTrades[OpenTradeCount].openPrice = entryPrice;
         OpenTrades[OpenTradeCount].openTime = TimeCurrent();         OpenTrades[OpenTradeCount].stopLoss = stopLoss;
         OpenTrades[OpenTradeCount].takeProfit = takeProfit;
         OpenTrades[OpenTradeCount].isLong = isLong;
         OpenTrades[OpenTradeCount].partialClosed = false;
         
         OpenTradeCount++;
         
         Print("New ", (isLong ? "long" : "short"), " trade opened, ticket: ", ticket, 
               ", size: ", positionSize, ", price: ", entryPrice);
      }
   } else {
      // Handle error
      Print("Trade open error: ", Trade.ResultRetcode(), " - ", Trade.ResultRetcodeDescription());
      
      // Retry logic for certain errors
      int errorCode = Trade.ResultRetcode();
      if(errorCode == TRADE_RETCODE_REQUOTE || 
         errorCode == TRADE_RETCODE_PRICE_CHANGED || 
         errorCode == TRADE_RETCODE_TIMEOUT) {
         
         // Wait briefly and retry
         Sleep(200);
         OpenTrade(isLong);
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate position size based on risk                            |
//+------------------------------------------------------------------+
double CalculatePositionSize(double riskAmount, double stopLossDistance)
{
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   
   // Calculate position size based on risk amount and stop loss distance
   double riskPerPip = tickValue / tickSize;
   double positionSize = riskAmount / (stopLossDistance * riskPerPip);
   
   // Normalize to symbol lot steps
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   positionSize = MathFloor(positionSize / lotStep) * lotStep;
   
   // Ensure within min/max limits
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   
   positionSize = MathMax(minLot, MathMin(maxLot, positionSize));
   
   return positionSize;
}

//+------------------------------------------------------------------+
//| Manage existing trades                                           |
//+------------------------------------------------------------------+
void ManageOpenTrades()
{
   if(OpenTradeCount == 0) return;
   
   // Current time
   datetime currentTime = TimeCurrent();
   
   // Check if it's time to close all trades (to avoid swap)
   MqlDateTime timeStruct;
   TimeToStruct(TimeLocal(), timeStruct);
   if(timeStruct.hour == InpCloseAllHour && OpenTradeCount > 0) {
      Print("Closing all trades to avoid swap at ", InpCloseAllHour, ":00");
      for(int i = 0; i < OpenTradeCount; i++) {
         if(OpenTrades[i].ticket != 0) {
            Trade.PositionClose(OpenTrades[i].ticket);
         }
      }
      return; // Exit after attempting to close all positions
   }
   
   // Loop through open trades
   for(int i = 0; i < OpenTradeCount; i++) {
      // Skip invalid tickets
      if(OpenTrades[i].ticket == 0) continue;
      
      // Check if the position still exists
      bool positionExists = false;
      double currentProfit = 0;
      double currentPrice = 0;
      
      // Find position in open positions
      for(int j = 0; j < PositionsTotal(); j++) {
         if(PositionSelectByTicket(OpenTrades[i].ticket)) {
            positionExists = true;
            currentProfit = PositionGetDouble(POSITION_PROFIT);
            currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
            break;
         }
      }
      
      // If position is closed, update trade tracking
      if(!positionExists) {
         // Check history for the result
         HistorySelect(OpenTrades[i].openTime, TimeCurrent() + 60);
         
         for(int j = 0; j < HistoryDealsTotal(); j++) {
            ulong dealTicket = HistoryDealGetTicket(j);
            
            if(HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID) == OpenTrades[i].ticket) {
               double dealProfit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
               DailyPnL += dealProfit;
               
               // Update consecutive win/loss counts
               if(dealProfit > 0) {
                  ConsecutiveWins++;
                  ConsecutiveLosses = 0;
               } else {
                  ConsecutiveLosses++;
                  ConsecutiveWins = 0;
               }
               
               // Adjust position sizing based on wins/losses
               if(ConsecutiveWins >= 3) {
                  // Increase risk slightly after 3 consecutive wins
                  ReducedRiskFactor = MathMin(1.5, ReducedRiskFactor * 1.1);
               } else if(ConsecutiveLosses >= 2) {
                  // Reduce risk after 2 consecutive losses
                  ReducedRiskFactor = MathMax(0.5, ReducedRiskFactor * 0.5);
               }
               
               Print("Trade closed, profit: ", dealProfit, ", daily P&L: ", DailyPnL);
               break;
            }
         }
         
         // Remove from tracking array by shifting remaining trades
         for(int j = i; j < OpenTradeCount - 1; j++) {
            OpenTrades[j] = OpenTrades[j+1];
         }
         // Zero out the last element
         OpenTrades[OpenTradeCount - 1].ticket = 0;
         OpenTradeCount--;
         
         // Adjust loop counter
         i--;
         continue;
      }
        // Calculate trade duration in minutes
      double tradeMinutes = (double)(currentTime - OpenTrades[i].openTime) / 60.0;
        // Calculate profit in points
      double pointSize = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double positionVolume = PositionGetDouble(POSITION_VOLUME);
      double currentPricePoints = (currentPrice - OpenTrades[i].openPrice) / pointSize;
      if(!OpenTrades[i].isLong) currentPricePoints = -currentPricePoints;  // Invert for short positions
      
      // Adjust for commission
      double adjustedProfitPoints = currentPricePoints - InpCommissionPoints;
        // Time-based exit logic
      if(currentProfit < 0 && tradeMinutes >= InpLossTimeLimit) {
         // Cut losses short after time limit reached
         Print("Closing losing trade after time limit: ", OpenTrades[i].ticket);
         Trade.PositionClose(OpenTrades[i].ticket);
      }
      // Close extremely poor performing trades even if they haven't hit the time limit
      else if(currentProfit < -50 && adjustedProfitPoints < -60) {
         Print("Closing significantly losing trade early: ", OpenTrades[i].ticket);
         Trade.PositionClose(OpenTrades[i].ticket);
      }
      // Break-even logic for trades that are in small profit but below minimum profit threshold
      else if(currentProfit > 0 && currentPricePoints >= 5.0 && currentPricePoints < InpMinProfitPoints) {
         double breakEvenLevel;
         
         if(OpenTrades[i].isLong) {
            breakEvenLevel = OpenTrades[i].openPrice + 3 * POINT_VALUE; // Entry + 3 points
            if(OpenTrades[i].stopLoss < breakEvenLevel) {
                OpenTrades[i].stopLoss = breakEvenLevel;
                Trade.PositionModify(OpenTrades[i].ticket, breakEvenLevel, 0);
                Print("Position moved to break-even+: ", OpenTrades[i].ticket);
            }
         } else {
            breakEvenLevel = OpenTrades[i].openPrice - 3 * POINT_VALUE; // Entry - 3 points
            if(OpenTrades[i].stopLoss > breakEvenLevel) {
                OpenTrades[i].stopLoss = breakEvenLevel;
                Trade.PositionModify(OpenTrades[i].ticket, breakEvenLevel, 0);
                Print("Position moved to break-even+: ", OpenTrades[i].ticket);
            }
         }
      }
      else if(currentProfit > 0 && currentPricePoints >= InpMinProfitPoints) {
         // Account for commission in profit calculation
         if(adjustedProfitPoints <= 0) continue; // Skip if not profitable after commission
         
         // Partial close logic for good profits
         if(currentPricePoints >= 30 && !OpenTrades[i].partialClosed) {
            double posVolume = PositionGetDouble(POSITION_VOLUME);
            double partialVolume = posVolume * 0.5; // Close 50%
            
            if(Trade.PositionClosePartial(OpenTrades[i].ticket, partialVolume)) {
               Print("Partial close executed for ticket: ", OpenTrades[i].ticket);
               OpenTrades[i].partialClosed = true;
            }
         }
         
         // Calculate new stop loss level based on time and profit
         double profitRunTime = InpLossTimeLimit * InpProfitRunTimeMultiplier;
         double timeRatio = MathMin(1.0, tradeMinutes / profitRunTime);
           // More aggressive trailing factor (0.9 instead of 0.8)
         double trailingFactor = 0.9;
         
         // Additional time acceleration factor
         double timeAcceleration = 1.0 + timeRatio; // Ranges from 1.0 to 2.0
         
         // Add profit-based protection - the more profit we have, the tighter we trail
         double profitAcceleration = 1.0;
         if(adjustedProfitPoints > 40) profitAcceleration = 1.2;
         if(adjustedProfitPoints > 60) profitAcceleration = 1.5;
         
         // Calculate trailing stop distance
         double trailDistance;
         
         if(OpenTrades[i].isLong) {
            // For long positions
            double priceDiff = currentPrice - OpenTrades[i].openPrice;
            
            // Break-even + buffer once we're profitable enough
            if(adjustedProfitPoints >= 20 && OpenTrades[i].stopLoss < OpenTrades[i].openPrice) {
               trailDistance = OpenTrades[i].openPrice + 5 * POINT_VALUE; // Entry + 5 points buffer
            } else {               // More aggressive trail with time and profit acceleration
               trailDistance = OpenTrades[i].openPrice + priceDiff * timeRatio * trailingFactor * timeAcceleration * profitAcceleration;
            }
            
            // Update stop loss if it would move up
            if(trailDistance > OpenTrades[i].stopLoss) {
               OpenTrades[i].stopLoss = trailDistance;
               Trade.PositionModify(OpenTrades[i].ticket, trailDistance, 0);
            }
         } else {
            // For short positions
            double priceDiff = OpenTrades[i].openPrice - currentPrice;
            
            // Break-even + buffer once we're profitable enough
            if(adjustedProfitPoints >= 20 && (OpenTrades[i].stopLoss > OpenTrades[i].openPrice || OpenTrades[i].stopLoss == 0)) {
               trailDistance = OpenTrades[i].openPrice - 5 * POINT_VALUE; // Entry - 5 points buffer
            } else {               // More aggressive trail with time and profit acceleration
               trailDistance = OpenTrades[i].openPrice - priceDiff * timeRatio * trailingFactor * timeAcceleration * profitAcceleration;
            }
            
            // Update stop loss if it would move down
            if(trailDistance < OpenTrades[i].stopLoss || OpenTrades[i].stopLoss == 0) {
               OpenTrades[i].stopLoss = trailDistance;
               Trade.PositionModify(OpenTrades[i].ticket, trailDistance, 0);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check daily loss limits                                          |
//+------------------------------------------------------------------+
void CheckDailyLossLimits()
{
   // Calculate current daily P&L percentage
   double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double dailyPnLPercent = (DailyPnL / InitialBalance) * 100.0;
   
   // Apply stepped shutdown mechanism
   if(dailyPnLPercent <= -InpDailyLossLimit) {
      // Complete shutdown
      TradingAllowed = false;
      Print("Daily loss limit reached (", dailyPnLPercent, "%). Trading stopped for today.");
   }
   else if(dailyPnLPercent <= -InpStepDownLevel2) {
      // Only trade with trend
      TradingAllowed = true;
      TrendDirectionOnly = true;
      ReducedRiskFactor = 0.5;
      Print("Loss level 2 reached (", dailyPnLPercent, "%). Trading with trend direction only.");
   }
   else if(dailyPnLPercent <= -InpStepDownLevel1) {
      // Reduce position sizes
      TradingAllowed = true;
      ReducedRiskFactor = 0.5;
      Print("Loss level 1 reached (", dailyPnLPercent, "%). Trading with reduced position sizes.");
   }
}

//+------------------------------------------------------------------+
//| Check if current time is within allowed trading hours            |
//+------------------------------------------------------------------+
bool IsWithinTradingHours()
{
   // If time restrictions are not enabled, always return true
   if(!InpUseTimeRestrictions) return true;
   
   // Get current time
   MqlDateTime currentTime;
   TimeToStruct(TimeLocal(), currentTime);
   
   // Check if the current hour is within the allowed range
   int currentHour = currentTime.hour;
   
   // If end hour is less than start hour, it means the range spans midnight
   if(InpTradingEndHour < InpTradingStartHour) {
      return (currentHour >= InpTradingStartHour || currentHour <= InpTradingEndHour);
   }
   // Normal hour range
   else {
      return (currentHour >= InpTradingStartHour && currentHour <= InpTradingEndHour);
   }
}
