# Stay EA: Tick-Based Scalping Strategy

## Core Strategy Concept
EA for EURUSD with fixed spread of 1 pip

The "Stay EA" is a tick-based scalping expert advisor for MetaTrader 5 that trades solely on raw price action without any technical indicators. The central philosophy is "cut losses short, let profits run long" where short and long refer to time, not price distance.

## Price Action Approach

### Entry Logic
- **Momentum Bursts**: Detected through tick velocity (rapid directional price movement)
- **Micro Pullbacks**: Small retracements against the immediate trend
- **Tick Pressure**: Analysis of buy/sell tick frequency and volume

### Volatility Detection
- Real-time measurement of tick frequency changes
- Tick range expansion monitoring
- No indicators - pure tick pattern analysis

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
- Minimum profit threshold: 10 points before trailing stop activation
- Dynamic trailing stops that widen based on trade duration

## Trading Hour Constraints

- Limited trading hours: 6:00 AM to 9:00 PM
- Configurable start and end times
- Option to disable time restrictions
- Prevents trading during typically low-liquidity or high-spread periods
- Forced closing of all open positions at 10:00 PM to avoid overnight swap fees

## Technical Implementation

- Pure MQL5 implementation without external indicators
- Tick data storage arrays for pattern analysis
- Built-in volatility calculation based on tick range and frequency
- Spread consideration: Fixed 1 pip spread for EURUSD

## Optimization Framework

- Compatible with MT5 Strategy Tester for Genetic Algorithm optimization
- Key optimization parameters:
  - Tick momentum period
  - Volatility threshold values
  - Time limits for loss cutting and profit running

## Development Roadmap

1. Core tick data collection and analysis system
2. Entry signal generation based on micro price patterns
3. Position sizing and risk management implementation
4. Time-based exit logic with trailing mechanism
5. Full testing in tick simulation mode

- **Momentum Burst Thresholds**:
  - Bullish burst: >69% of recent ticks moving up AND tick velocity >3x normal
  - Bearish burst: >69% of recent ticks moving down AND tick velocity >3x normal

  
- **Volatility Thresholds**:
  - High volatility: Current tick range > 2.4 standard deviations above average
  - Low volatility: Tick frequency < 51% of baseline average
