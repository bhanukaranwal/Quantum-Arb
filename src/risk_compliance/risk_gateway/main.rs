/*
 * QuantumArb 2.0 - Risk & Compliance: Risk Gateway (Redis Enhanced)
 *
 * File: src/risk_compliance/risk_gateway/main.rs
 *
 * Description:
 * This is an enhanced version of the Risk Gateway microservice. It now integrates
 * with Redis to manage account state in a fast, persistent, and scalable manner.
 * This allows multiple replicas of the gateway to share a consistent view of
 * risk exposure.
 *
 * To run (with a Cargo.toml file):
 * [dependencies]
 * tokio = { version = "1", features = ["full"] }
 * redis = { version = "0.25", features = ["tokio-comp"] }
 * serde = { version = "1.0", features = ["derive"] }
 * serde_json = "1.0"
 * uuid = { version = "1", features = ["v4"] }
 */

use redis::AsyncCommands;
use serde::{Deserialize, Serialize};
use tokio::time::{self, Duration};
use uuid::Uuid;

// --- Data Structures ---

#[derive(Debug, Clone)]
struct OrderRequest {
    order_id: Uuid,
    account_id: u32,
    instrument_id: u32,
    price: u64,
    size: u32,
    side: OrderSide,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
enum OrderSide {
    Buy,
    Sell,
}

/// Account state is now stored in Redis. This struct is used for serialization.
#[derive(Debug, Serialize, Deserialize)]
struct AccountState {
    account_id: u32,
    current_exposure: f64,
    max_exposure: f64,
    max_order_size: u32,
}

#[derive(Debug, PartialEq)]
enum RiskDecision {
    Approved,
    Rejected(String),
}

const REDIS_URL: &str = "redis://127.0.0.1/";

// --- Main Application Logic ---

#[tokio::main]
async fn main() {
    println!("--- Starting QuantumArb 2.0 Risk Gateway (Redis Enhanced) ---");

    // Connect to Redis
    let client = redis::Client::open(REDIS_URL).expect("Invalid Redis URL");
    let mut con = client.get_async_connection().await.expect("Failed to connect to Redis");

    // Initialize account state in Redis if it doesn't exist
    setup_initial_account_state(&mut con).await;

    let mut interval = time::interval(Duration::from_secs(2));
    loop {
        interval.tick().await;

        let order_request = generate_simulated_order();
        println!("\nReceived Order Request: {:?}", order_request);

        // Perform the risk check using data from Redis
        let decision = check_pre_trade_risk(&mut con, &order_request).await;
        println!("  -> Risk Decision: {:?}", decision);

        // If approved, update the account state in Redis
        if decision == RiskDecision::Approved {
            update_account_state_in_redis(&mut con, &order_request).await;
            println!("  -> Account state updated in Redis.");
        }
    }
}

/// Sets up an initial account state in Redis for the POC.
async fn setup_initial_account_state(con: &mut redis::aio::Connection) {
    let account_id = 101;
    let key = format!("account:{}", account_id);

    let exists: bool = con.exists(&key).await.unwrap_or(false);
    if !exists {
        let initial_state = AccountState {
            account_id,
            current_exposure: 50000.0,
            max_exposure: 100000.0,
            max_order_size: 100,
        };
        let serialized_state = serde_json::to_string(&initial_state).unwrap();
        let _: () = con.set(&key, serialized_state).await.unwrap();
        println!("Initialized account {} in Redis.", account_id);
    }
}

/// Simulates a new order request.
fn generate_simulated_order() -> OrderRequest {
    OrderRequest {
        order_id: Uuid::new_v4(),
        account_id: 101,
        instrument_id: 1,
        price: 60150_00,
        size: (rand::random::<u32>() % 150) + 1,
        side: OrderSide::Buy,
    }
}

/// The core logic for checking risk, now fetching state from Redis.
async fn check_pre_trade_risk(
    con: &mut redis::aio::Connection,
    order: &OrderRequest,
) -> RiskDecision {
    let key = format!("account:{}", order.account_id);
    let state_json: String = match con.get(&key).await {
        Ok(val) => val,
        Err(_) => return RiskDecision::Rejected("Account not found in Redis".to_string()),
    };

    let state: AccountState = serde_json::from_str(&state_json).unwrap();

    if order.size > state.max_order_size {
        return RiskDecision::Rejected(format!(
            "Order size {} exceeds max limit {}",
            order.size, state.max_order_size
        ));
    }

    let order_notional_value = (order.price as f64 / 100.0) * order.size as f64;
    let potential_new_exposure = state.current_exposure + order_notional_value;

    if potential_new_exposure > state.max_exposure {
        return RiskDecision::Rejected(format!(
            "Order would breach max exposure limit. New exposure ${:.2} > ${:.2}",
            potential_new_exposure, state.max_exposure
        ));
    }

    RiskDecision::Approved
}

/// Updates the account's state in Redis after an order is approved.
async fn update_account_state_in_redis(
    con: &mut redis::aio::Connection,
    order: &OrderRequest,
) {
    let key = format!("account:{}", order.account_id);
    // In a real production system, you would use a WATCH/MULTI/EXEC transaction
    // to prevent race conditions.
    let state_json: String = con.get(&key).await.unwrap();
    let mut state: AccountState = serde_json::from_str(&state_json).unwrap();

    let order_notional_value = (order.price as f64 / 100.0) * order.size as f64;
    state.current_exposure += order_notional_value;

    let updated_state_json = serde_json::to_string(&state).unwrap();
    let _: () = con.set(&key, updated_state_json).await.unwrap();
}
