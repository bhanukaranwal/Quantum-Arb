/*
 * QuantumArb 2.0 - Core Services: Market Replay Service
 *
 * File: src/core_services/market_replay_service/main.rs
 *
 * Description:
 * This microservice is a critical tool for backtesting and simulation. It reads
 * historical market data from a source (e.g., a file, a database) and
 * publishes it to the internal message bus, simulating a live market feed.
 *
 * Its primary role is to:
 * 1. Load historical tick or bar data.
 * 2. Publish this data in the same format as a live feed (e.g., BboUpdate).
 * 3. Control the speed of the replay to simulate real-time or accelerated time.
 *
 * This allows the entire platform to be tested against historical scenarios.
 *
 * To run (with a Cargo.toml file):
 * [dependencies]
 * tokio = { version = "1", features = ["full"] }
 * serde = { version = "1.0", features = ["derive"] }
 * serde_json = "1.0"
 * chrono = "0.4"
 */

use serde::{Deserialize, Serialize};
use tokio::time::{self, Duration, Instant};

// --- Data Structures ---

/// Using the same BBO update structure as the strategy engine for compatibility.
#[derive(Debug, Clone, Serialize, Deserialize)]
struct BboUpdate {
    instrument_id: u32,
    best_bid_price: u64,
    best_bid_size: u32,
    best_ask_price: u64,
    best_ask_size: u32,
    // Add a timestamp to the data model for replaying
    timestamp_ns: u64,
}

// --- Main Application Logic ---

#[tokio::main]
async fn main() {
    println!("--- Starting QuantumArb 2.0 Market Replay Service ---");

    // 1. Load historical data from a source.
    let historical_data = load_mock_historical_data();
    println!("Loaded {} historical market data events.", historical_data.len());

    // 2. Start the replay loop.
    replay_market_data(historical_data).await;
}

/// Loads a mock dataset representing a few seconds of market activity.
fn load_mock_historical_data() -> Vec<BboUpdate> {
    vec![
        BboUpdate { instrument_id: 1, best_bid_price: 60000_05, best_ask_price: 60000_15, best_bid_size: 10, best_ask_size: 12, timestamp_ns: 1000000000 }, // Time 1.0s
        BboUpdate { instrument_id: 2, best_bid_price: 60035_10, best_ask_price: 60035_22, best_bid_size: 5, best_ask_size: 8, timestamp_ns: 1000500000 },  // Time 1.0005s
        BboUpdate { instrument_id: 1, best_bid_price: 60000_04, best_ask_price: 60000_14, best_bid_size: 15, best_ask_size: 10, timestamp_ns: 1001000000 }, // Time 1.001s
        BboUpdate { instrument_id: 1, best_bid_price: 60000_06, best_ask_price: 60000_16, best_bid_size: 8, best_ask_size: 11, timestamp_ns: 2000000000 },  // Time 2.0s
        BboUpdate { instrument_id: 2, best_bid_price: 60035_09, best_ask_price: 60035_21, best_bid_size: 7, best_ask_size: 9, timestamp_ns: 2000800000 },  // Time 2.0008s
    ]
}

/// The core replay logic.
async fn replay_market_data(data: Vec<BboUpdate>) {
    if data.is_empty() {
        println!("No data to replay.");
        return;
    }

    println!("\n--- Starting Market Replay in 3 seconds... ---");
    time::sleep(Duration::from_secs(3)).await;

    let start_time = Instant::now();
    let first_event_timestamp = data[0].timestamp_ns;

    for event in data {
        // Calculate how long to wait before publishing the next event to simulate real-time.
        let elapsed_time_ns = event.timestamp_ns - first_event_timestamp;
        let target_instant = start_time + Duration::from_nanos(elapsed_time_ns);
        
        let now = Instant::now();
        if target_instant > now {
            time::sleep_until(target_instant).await;
        }

        // Publish the event to the internal message bus.
        publish_to_internal_bus(&event);
    }

    println!("\n--- Market Replay Complete ---");
}

/// Simulates publishing the event to an internal message bus like NATS.
fn publish_to_internal_bus(event: &BboUpdate) {
    let topic = format!("market_data.instrument.{}", event.instrument_id);
    let event_json = serde_json::to_string(event).unwrap();
    println!(
        "[{:.3}s] Publishing to topic '{}': Price={}",
        Instant::now().elapsed().as_secs_f32(),
        topic,
        event.best_bid_price
    );
    // In a real system:
    // nats_client.publish(&topic, event_json.as_bytes()).await.unwrap();
}
