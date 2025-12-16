# Hades EA - Professional Trend Following System

![MQL5](https://img.shields.io/badge/Platform-MetaTrader%205-blue)
![Strategy](https://img.shields.io/badge/Strategy-Trend%20Following-green)
![FTMO](https://img.shields.io/badge/FTMO-Compatible-orange)
![License](https://img.shields.io/badge/License-MIT-yellow)

## Overview

**Hades EA** is a professional-grade Expert Advisor designed specifically for FTMO and prop firm challenges. Built on proven trend-following methodologies inspired by top-performing MQL5 strategies, Hades combines technical precision with strict risk management.

## Key Features

- **Triple EMA Trend Filter** (21/50/200) - Only trades in the direction of the trend
- **ATR-Based Breakout System** - Volatility-adjusted entries
- **RSI Confirmation** - Filters overbought/oversold conditions
- **FTMO-Compliant Risk Management** - Built-in drawdown protection
- **Dynamic Trailing Stop** - ATR-based profit protection
- **Session Filtering** - London & New York sessions optimized
- **1:3 Risk/Reward Ratio** - Professional-grade R:R

## FTMO Compliance

| Parameter | Setting | FTMO Limit |
|-----------|---------|------------|
| Daily Drawdown | 4.5% | 5% |
| Total Drawdown | 9% | 10% |
| Risk per Trade | 1% | - |
| Max Open Trades | 1 | - |
| Max Trades/Day | 2 | - |

## Supported Pairs

- EURUSD
- GBPUSD
- USDJPY
- AUDUSD
- NZDUSD
- USDCHF
- USDCAD

## Strategy Logic

### Entry Conditions (BUY)
1. **Trend Alignment**: EMA21 > EMA50 > EMA200
2. **Breakout**: Price breaks above 20-period high
3. **RSI Filter**: RSI > 50 and < 70
4. **Price Action**: Close above fast EMA

### Entry Conditions (SELL)
1. **Trend Alignment**: EMA21 < EMA50 < EMA200
2. **Breakout**: Price breaks below 20-period low
3. **RSI Filter**: RSI < 50 and > 30
4. **Price Action**: Close below fast EMA

### Exit Strategy
- **Take Profit**: 3x Stop Loss (1:3 RR)
- **Stop Loss**: 1.5x ATR from entry
- **Trailing Stop**: Activates after 30 pips profit, trails at 1x ATR

## Installation

1. Copy `Hades_EA.mq5` to `MQL5/Experts/`
2. Copy preset files from `Presets/` to `MQL5/Presets/`
3. Compile in MetaEditor
4. Attach to H1 chart
5. Load appropriate preset for your pair

## Parameters

### Risk Management
| Parameter | Default | Description |
|-----------|---------|-------------|
| InpRiskPercent | 1.0 | Risk % per trade |
| InpMaxDailyDrawdown | 4.5 | Max daily DD % |
| InpMaxTotalDrawdown | 9.0 | Max total DD % |
| InpMaxTradesPerDay | 2 | Max trades per day |
| InpMaxOpenTrades | 1 | Max simultaneous trades |

### Strategy
| Parameter | Default | Description |
|-----------|---------|-------------|
| InpRiskReward | 3.0 | Risk/Reward ratio |
| InpEmaFast | 21 | Fast EMA period |
| InpEmaMedium | 50 | Medium EMA period |
| InpEmaSlow | 200 | Slow EMA period |
| InpRsiPeriod | 14 | RSI period |
| InpAtrPeriod | 14 | ATR period |
| InpAtrMultiplier | 1.5 | ATR multiplier for SL |

### Trailing Stop
| Parameter | Default | Description |
|-----------|---------|-------------|
| InpUseTrailingStop | true | Enable trailing stop |
| InpTrailingAtrMult | 1.0 | Trailing ATR multiplier |
| InpTrailingStartPips | 30 | Start trailing after X pips |

## Backtesting

**Recommended Settings:**
- Period: 2024-2025
- Timeframe: H1
- Initial Deposit: $10,000
- Leverage: 1:100
- Spread: Variable (ECN)

## Disclaimer

Trading involves substantial risk of loss. This EA is provided for educational purposes. Past performance does not guarantee future results. Always test on demo accounts before live trading. The authors are not responsible for any financial losses.

## Credits

Inspired by proven strategies from:
- [EA Trend Following (MQL5)](https://www.mql5.com/en/market/product/116289)
- [Trend Matrix EA](https://www.mql5.com/en/blogs/post/754634)
- [NSA Prop Firm Robot](https://www.mql5.com/en/blogs/post/766009)

## License

MIT License - Free to use and modify.

---

**Hades** - *God of the Underworld, Master of Hidden Wealth*
