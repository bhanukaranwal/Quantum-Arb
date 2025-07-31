#
# QuantumArb 2.0 - ML Pipeline: Simple Backtester
#
# File: src/ml_pipeline/simple_backtest.py
#
# Description:
# This script provides a basic framework for backtesting a trading strategy using
# historical market data. It uses the pandas library to manipulate time-series
# data and implements a simple Simple Moving Average (SMA) Crossover strategy.
#
# In a real-world SageMaker pipeline, this would be far more sophisticated,
# incorporating feature engineering, parameter optimization (e.g., using Optuna),
# and more robust performance analytics (e.g., using pyfolio).
#
# Dependencies:
# pip install pandas
#

import pandas as pd
import numpy as np
import io

# --- 1. Load Historical Data ---
# In a real system, this data would be pulled from a data lake (e.g., S3)
# containing historical tick or bar data. For this POC, we'll use a
# simple CSV string to represent one day of minute-bar data for a stock.
historical_data_csv = """
timestamp,open,high,low,close,volume
2025-07-31 09:30:00,150.10,150.20,150.05,150.15,10000
2025-07-31 09:31:00,150.15,150.35,150.12,150.30,12000
2025-07-31 09:32:00,150.30,150.33,150.25,150.28,8000
2025-07-31 09:33:00,150.28,150.50,150.28,150.45,15000
2025-07-31 09:34:00,150.45,150.46,150.30,150.32,11000
2025-07-31 09:35:00,150.32,150.32,150.10,150.15,20000
2025-07-31 09:36:00,150.15,150.25,150.05,150.20,9000
2025-07-31 09:37:00,150.20,150.60,150.20,150.55,25000
2025-07-31 09:38:00,150.55,150.70,150.55,150.65,18000
2025-07-31 09:39:00,150.65,150.66,150.50,150.52,13000
2025-07-31 09:40:00,150.52,150.58,150.40,150.42,14000
"""

data = pd.read_csv(io.StringIO(historical_data_csv), index_col='timestamp', parse_dates=True)

print("--- Loaded Historical Data ---")
print(data.head())
print("\n")


# --- 2. Define the Strategy ---
def sma_crossover_strategy(df, short_window=3, long_window=7):
    """
    Generates trading signals based on a dual moving average crossover.
    - Signal = 1:  Short SMA crosses above Long SMA (Buy Signal)
    - Signal = -1: Short SMA crosses below Long SMA (Sell Signal)
    - Signal = 0:  No signal
    """
    signals = pd.DataFrame(index=df.index)
    signals['price'] = df['close']
    signals['signal'] = 0.0

    # Calculate short and long simple moving averages
    signals['short_mavg'] = df['close'].rolling(window=short_window, min_periods=1, center=False).mean()
    signals['long_mavg'] = df['close'].rolling(window=long_window, min_periods=1, center=False).mean()

    # Generate signal when short SMA crosses over long SMA
    # Use .shift(1) to ensure we are using previous day's data to generate the signal for the current day
    signals['signal'][short_window:] = np.where(signals['short_mavg'][short_window:] > signals['long_mavg'][short_window:], 1.0, 0.0)

    # Generate trading orders by taking the difference of the signals
    signals['positions'] = signals['signal'].diff()

    return signals

# --- 3. Run the Backtest ---
print("--- Running Backtest ---")
signals = sma_crossover_strategy(data)
print("Generated Signals and Positions:")
print(signals.tail())
print("\n")


# --- 4. Calculate Performance ---
def calculate_performance(signals_df, initial_capital=100000.0):
    """
    Calculates the performance of the strategy.
    """
    initial_capital = float(initial_capital)
    positions = pd.DataFrame(index=signals_df.index).fillna(0.0)

    # Buy/sell 100 shares for each signal
    positions['stock'] = 100 * signals_df['signal']

    # Calculate portfolio value over time
    portfolio = positions.multiply(signals_df['price'], axis=0)
    pos_diff = positions.diff()

    portfolio['holdings'] = (positions.multiply(signals_df['price'], axis=0)).sum(axis=1)
    portfolio['cash'] = initial_capital - (pos_diff.multiply(signals_df['price'], axis=0)).sum(axis=1).cumsum()
    portfolio['total'] = portfolio['cash'] + portfolio['holdings']
    portfolio['returns'] = portfolio['total'].pct_change()

    return portfolio


print("--- Calculating Performance ---")
portfolio = calculate_performance(signals)
print("Portfolio Value Over Time:")
print(portfolio.tail())
print("\n")

# --- 5. Print Summary ---
print("--- Backtest Summary ---")
final_portfolio_value = portfolio['total'].iloc[-1]
total_return = (final_portfolio_value - 100000.0) / 100000.0 * 100
sharpe_ratio = portfolio['returns'].mean() / portfolio['returns'].std() * np.sqrt(252) # Annualized

print(f"Final Portfolio Value: ${final_portfolio_value:,.2f}")
print(f"Total Return: {total_return:.2f}%")
print(f"Annualized Sharpe Ratio: {sharpe_ratio:.2f}")

