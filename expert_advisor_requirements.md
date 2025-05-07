You are a highly profitable trader and an expert MQL5 developer. Write the complete source code for a MetaTrader 5 Expert Advisor that trades Forex using only tick data and raw price action.

Core Strategy Rules:

The core idea of the strategy is cut the losses short and let the profits run long. Here short and long refer to time and not pips or price.

No technical indicators whatsoever—only raw price movements, tick data, and price structure.

The EA should operate on a scalping model suitable for M1 or tick chart environments.

The entry logic should be based on micro price behavior, including short-term momentum bursts, micro pullbacks, and tick-by-tick bullish/bearish pressure.

Include logic for detecting sudden volatility changes based on tick frequency or tick range expansion and incorporate that into trade filtering (no indicators, just tick patterns).

The account is a fixed spread 1 pip account.

Technical Requirements:

Fully compatible with MetaTrader 5.

Must work on any major Forex pair (e.g., EURUSD, GBPUSD).

The code should include robust error handling and OrderSend/modify retry logic.

Include parameters for customization

Ensure compatibility with MT5 Strategy Tester for Genetic Algorithm Optimization.

Tick Simulation Compatibility:

Code must be testable with MetaTrader 5 tick-by-tick simulation mode.

Structure price-reading logic via OnTick() and avoid reliance on OHLC.