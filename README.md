# TimePivot EA

A tick-based scalping expert advisor for MetaTrader 5 that trades solely on raw price action without using any technical indicators.

## Core Strategy Concept

The TimePivot EA implements a "cut losses short, let profits run long" philosophy where short and long refer to time, not price distance. The strategy focuses exclusively on EURUSD with a fixed spread of 1 pip.

## Key Features

### Price Action Approach

- **Momentum Bursts**: Detected through tick velocity (rapid directional price movement)
- **Micro Pullbacks**: Small retracements against the immediate trend
- **Tick Pressure**: Analysis of buy/sell tick frequency and volume

### Volatility Detection
- Real-time measurement of tick frequency changes
- Tick range expansion monitoring without using traditional indicators

## Risk Management

### Position Sizing
- Base risk: 1-2% of account equity per trade
- Volatility adjustment: Smaller positions during higher volatility
- Consecutive loss reduction: 50% position size reduction after 2-3 losses
- Success scaling: Up to 3% risk after winning streaks

### Trade Management
- Maximum concurrent trades: 2 per symbol (EURUSD focus)
- Maximum total open trades: 5-7 across all symbols

### Daily Loss Management
- 30% daily loss limit with stepped shutdown:
  - At 15% daily loss: Position sizes reduced by 50%
  - At 20% daily loss: Only trade with daily trend direction
  - At 30% daily loss: Complete trading shutdown for the day

## Time-Based Exit Strategy

- Short time limit for cutting losses: ~3 minutes
- Profit run time multiplier: 6x the loss time limit
- Minimum profit threshold: 10 points required before trailing stop is activated
- Dynamic trailing stops that widen based on trade duration
- Break-even functionality that secures small profits (moves stop loss to entry + 3 points)
- Commission handling with 10 points per trade factored into profit calculations
- Aggressive trailing stop with time acceleration factor for better profit capture
- Partial position closing at 30+ points profit (closes 50% of position)

## Trading Hours Restrictions

- Configurable trading hours to limit exposure during unfavorable market conditions
- Default setting: Only trade between 6:00 AM and 9:00 PM
- Option to disable time restrictions if continuous trading is preferred
- Automatic closing of all trades at 10:00 PM to avoid overnight swap fees

## Installation Instructions

1. Download the TimePivot.mq5 file
2. Place the file in your MetaTrader 5's MQL5/Experts folder
3. Restart MetaTrader 5 or refresh the Navigator panel
4. Drag and drop TimePivot onto an EURUSD chart

## Configuration Parameters

### Risk Management

- **InpRiskPercent** (default: 1.0): Risk per trade as percentage of account balance
- **InpMaxConcurrentTrades** (default: 2): Maximum concurrent trades per symbol
- **InpDailyLossLimit** (default: 30.0): Daily loss limit as percentage
- **InpStepDownLevel1** (default: 15.0): First level to reduce position size
- **InpStepDownLevel2** (default: 20.0): Second level to limit to trend direction

### Time-based Exit Parameters

- **InpLossTimeLimit** (default: 3): Minutes to cut losses
- **InpProfitRunTimeMultiplier** (default: 6): Multiplier for profit run time
- **InpMinProfitPoints** (default: 10.0): Minimum profit in points before trailing stop is activated
- **InpCommissionPoints** (default: 10.0): Commission in points per trade (1 pip = 10 points)

### Trading Hours Parameters

- **InpUseTimeRestrictions** (default: true): Enable or disable trading hour restrictions
- **InpTradingStartHour** (default: 6): Hour to start trading (0-23)
- **InpTradingEndHour** (default: 21): Hour to stop opening new trades (0-23)
- **InpCloseAllHour** (default: 22): Hour to close all trades to avoid swap fees (0-23)

### Momentum & Volatility Parameters

- **InpTickMomentumPeriod** (default: 20): Number of ticks to analyze for momentum
- **InpMomentumThreshold** (default: 3.0): Momentum burst threshold multiplier
- **InpDirectionalThreshold** (default: 0.69): Directional strength threshold
- **InpVolatilityThreshold** (default: 2.4): Volatility expansion threshold
- **InpLowVolFreqThreshold** (default: 0.51): Low volatility frequency threshold

## Testing

The EA includes a specific testing version (TimePivotTest.mq5) optimized for the MT5 Strategy Tester with additional metrics and reporting.

### Backtesting Requirements

- Use the "Every tick based on real ticks" mode in the Strategy Tester
- Make sure your data center provides high-quality tick data
- For proper testing, use at least 3 months of tick data

## Limitations

- Currently optimized only for EURUSD
- Requires a fixed spread of 1 pip for optimal performance
- Performance heavily depends on the quality of tick data

## Disclaimer

Trading foreign exchange on margin carries a high level of risk, and may not be suitable for all investors. Past performance is not indicative of future results. The high degree of leverage can work against you as well as for you. Before deciding to invest in foreign exchange you should carefully consider your investment objectives, level of experience, and risk appetite.
