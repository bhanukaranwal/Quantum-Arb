/*
 * QuantumArb 2.0 - Core Services: Strategy Engine (ML Integrated)
 *
 * File: src/core_services/strategy_engine/main.rs
 *
 * Description:
 * This is the ML-integrated version of the Strategy Engine. It now calls the
 * ML inference server to get a predictive signal before acting on a potential
 * arbitrage opportunity. This adds an intelligent filter to the core logic,
 * aiming to improve the profitability of trades.
 *
 * To run (with a Cargo.toml file):
 * [dependencies]
 * tokio = { version = "1", features = ["full"] }
 * serde = { version = "1.0", features = ["derive"] }
 * serde_json = "1.0"
 * reqwest = "0.12"
 */

use serde::{Deserialize, Serialize};
use std::time::Duration;
use tokio::time;

// --- Data Structures ---

#[derive(Debug, Clone, Deserialize)]
struct BboUpdate {
    instrument_id: u32,
    best_bid_price: u64,
    best_bid_size: u32,
    best_ask_price: u64,
    best_ask_size: u32,
}

#[derive(Debug)]
struct ArbitrageStrategy {
    strategy_id: String,
    instrument_id_venue_a: u32,
    instrument_id_venue_b: u32,
    min_spread_bps: f64,
    is_active: bool,
}

#[derive(Debug, Serialize)]
enum TradeAction {
    Buy(u32, u64, u32),
    Sell(u32, u64, u32),
    Hold(String), // Add a reason for holding
}

// --- NEW: Structures for ML Inference ---
#[derive(Debug, Serialize)]
struct PredictionFeatures {
    news_sentiment: f32,
    mavg_spread: f32,
}

#[derive(Debug, Deserialize)]
struct PredictionResponse {
    prediction: i32, // 0 for down/sell, 1 for up/buy
    signal: String,
}

const INFERENCE_SERVER_URL: &str = "http://inference-server.default.svc.cluster.local/predict";

// --- Main Application Logic ---

#[tokio::main]
async fn main() {
    println!("--- Starting QuantumArb 2.0 Strategy Engine (ML Integrated) ---");

    let active_strategy = ArbitrageStrategy {
        strategy_id: "BTC-USD-LSE-CME".to_string(),
        instrument_id_venue_a: 1,
        instrument_id_venue_b: 2,
        min_spread_bps: 5.0,
        is_active: true,
    };

    let http_client = reqwest::Client::new();
    println!("Loaded strategy: {:?}", active_strategy);

    let mut interval = time::interval(Duration::from_secs(4));
    loop {
        interval.tick().await;

        let update_a = get_simulated_bbo_update(1, 60000_00, 10);
        let update_b = get_simulated_bbo_update(2, 60035_00, 12);

        println!("\nReceived BBO A: {:?}, BBO B: {:?}", update_a, update_b);

        if active_strategy.is_active {
            let action = evaluate_arbitrage_opportunity(&http_client, &active_strategy, &update_a, &update_b).await;
            process_trade_action(action);
        }
    }
}

/// Simulates receiving a BBO update from a data feed.
fn get_simulated_bbo_update(instrument_id: u32, base_price: u64, spread: u64) -> BboUpdate {
    let price_jitter = (rand::random::<u64>() % 20) as i64 - 10;
    let current_price = (base_price as i64 + price_jitter) as u64;
    BboUpdate {
        instrument_id,
        best_bid_price: current_price,
        best_bid_size: 10 + (rand::random::<u32>() % 5),
        best_ask_price: current_price + spread,
        best_ask_size: 10 + (rand::random::<u32>() % 5),
    }
}

/// NEW: Function to get a prediction from the ML inference server.
async fn get_ml_prediction(client: &reqwest::Client, features: &PredictionFeatures) -> Option<PredictionResponse> {
    println!("  -> Querying ML inference server...");
    match client.post(INFERENCE_SERVER_URL).json(features).send().await {
        Ok(response) => {
            if response.status().is_success() {
                response.json::<PredictionResponse>().await.ok()
            } else {
                println!("  -> ML Server returned error: {}", response.status());
                None
            }
        }
        Err(e) => {
            println!("  -> Failed to connect to ML server: {}", e);
            None
        }
    }
}

/// Core logic now includes a call to the ML model.
async fn evaluate_arbitrage_opportunity(
    client: &reqwest::Client,
    strategy: &ArbitrageStrategy,
    bbo_a: &BboUpdate,
    bbo_b: &BboUpdate,
) -> TradeAction {
    let spread = (bbo_b.best_bid_price as f64 - bbo_a.best_ask_price as f64) / bbo_a.best_ask_price as f64 * 10000.0;

    if spread > strategy.min_spread_bps {
        println!("  -> Arbitrage opportunity detected. Spread: {:.2} bps.", spread);

        // Before trading, get a confirmation from the ML model.
        // In a real system, features would be calculated from real data.
        let features = PredictionFeatures {
            news_sentiment: 0.75, // Mock feature
            mavg_spread: 1.5,     // Mock feature
        };

        if let Some(prediction) = get_ml_prediction(client, &features).await {
            println!("  -> ML Model Prediction: {} ({})", prediction.signal, prediction.prediction);
            // We only proceed if the model predicts the price will go UP (1),
            // confirming the long leg of our arbitrage.
            if prediction.prediction == 1 {
                return TradeAction::Buy(strategy.instrument_id_venue_a, bbo_a.best_ask_price, bbo_a.best_ask_size);
            } else {
                return TradeAction::Hold("ML model predicted against the trade.".to_string());
            }
        } else {
            return TradeAction::Hold("Failed to get ML prediction.".to_string());
        }
    }

    TradeAction::Hold("No profitable spread detected.".to_string())
}

/// Processes the decision from the evaluation logic.
fn process_trade_action(action: TradeAction) {
    match action {
        TradeAction::Buy(id, price, size) => {
            println!("  [ACTION] Sending BUY order: Instrument {}, Price {}, Size {}", id, price, size);
        }
        TradeAction::Sell(id, price, size) => {
            println!("  [ACTION] Sending SELL order: Instrument {}, Price {}, Size {}", id, price, size);
        }
        TradeAction::Hold(reason) => {
            println!("  [ACTION] Holding position. Reason: {}", reason);
        }
    }
}
