#
# QuantumArb 2.0 - ML Pipeline: Alternative Data Processor
#
# File: src/ml_pipeline/alt_data_processor.py
#
# Description:
# This script is responsible for consuming the normalized alternative data events
# from the internal message bus (published by the data-bus-connector). It then
# processes this data to create features that can be used by downstream machine
# learning models.
#
# In a real SageMaker pipeline, this would be a continuously running process,
# perhaps using a streaming framework like Spark Streaming or Flink, and would
# store the generated features in a dedicated Feature Store.
#
# Dependencies:
# pip install pandas
#

import pandas as pd
import json
import time

# --- Data Structures ---

# A mock feature store to hold the latest feature values for each symbol.
# In a real system, this would be a dedicated database like Redis or Amazon's Feature Store.
FEATURE_STORE = {}

# --- Main Application Logic ---

def process_event_stream():
    """
    Simulates a long-running process that consumes events from a message bus.
    """
    print("--- Starting Alternative Data Processor ---")
    print("Listening for normalized events on topic 'alt_data.normalized'...")

    while True:
        # 1. Simulate receiving a normalized event from the message bus.
        event_json = get_simulated_normalized_event()
        event = json.loads(event_json)
        print(f"\nConsumed Event: ID {event['event_id'][:8]}...")

        # 2. Process the event to generate or update features.
        update_features_from_event(event)

        # 3. Display the current state of the feature store.
        print("--- Current Feature Store State ---")
        for symbol, features in FEATURE_STORE.items():
            print(f"  Symbol: {symbol}, Features: {features}")

        time.sleep(5)


def get_simulated_normalized_event():
    """
    Simulates receiving a JSON message from the internal message bus.
    This is the output format of the data_bus_connector service.
    """
    return json.dumps({
        "event_id": "a1b2c3d4-e5f6-7890-1234-567890abcdef",
        "source_type": "news",
        "source_name": "FinancialWire",
        "content": "Tech Giant 'Innovate Inc.' Announces Breakthrough in Chip Technology",
        "metadata": {
            "sentiment_score": "0.75",
            "related_symbols": "INVT,CHIP,SEMI"
        },
        "timestamp_utc": "2025-07-31T12:00:00Z"
    })


def update_features_from_event(event):
    """
    Parses a normalized event and updates the feature store.
    """
    metadata = event.get("metadata", {})
    if "related_symbols" not in metadata:
        return

    symbols = metadata["related_symbols"].split(',')
    sentiment_score = float(metadata.get("sentiment_score", 0.0))

    print(f"  -> Processing event for symbols: {symbols}")

    for symbol in symbols:
        if symbol not in FEATURE_STORE:
            FEATURE_STORE[symbol] = {
                'latest_news_sentiment': 0.0,
                'news_event_count': 0
            }

        # Update the features for the given symbol
        # In a real system, you might use a rolling average or a more complex calculation.
        FEATURE_STORE[symbol]['latest_news_sentiment'] = sentiment_score
        FEATURE_STORE[symbol]['news_event_count'] += 1


if __name__ == "__main__":
    process_event_stream()

