/*
 * QuantumArb 2.0 - Risk & Compliance: Dynamic Risk Gateway
 *
 * File: src/risk_compliance/risk_gateway/main.rs
 *
 * Description:
 * This is the most advanced version of the Risk Gateway. It is now a dynamic,
 * VaR-aware service that adjusts its own limits in real-time based on the
 * portfolio's market risk, as calculated by the VaR service.
 *
 * New Functionality:
 * - A background task periodically fetches the 99% VaR from the var-calculator.
 * - Based on the VaR, it adjusts the 'max_order_size' and 'max_exposure' limits
 * for the account. If VaR is high, limits are tightened; if VaR is low, they
 * are loosened.
 * - This creates a closed-loop, adaptive risk management system.
 */

use redis::AsyncCommands;
use serde::{Deserialize, Serialize};
use std::sync::{Arc, Mutex};
use tokio::time::{self, Duration};
use uuid::Uuid;

// --- Data Structures ---

#[derive(Debug, Clone)]
struct OrderRequest {
    order_id: Uuid,
    account_id: u32,
    price: u64,
    size: u32,
}

#[derive(Debug, Serialize, Deserialize)]
struct AccountState {
    account_id: u32,
    base_max_exposure: f64, // The baseline limit
    current_max_exposure: f64, // The dynamically adjusted limit
    base_max_order_size: u32,
    current_max_order_size: u32,
    current_exposure: f64,
}

#[derive(Debug, PartialEq)]
enum RiskDecision {
    Approved,
    Rejected(String),
}

// Structure for the VaR service response
#[derive(Debug, Deserialize)]
struct VaRResult {
    var_amount: f64,
    portfolio_value: f64,
}

const REDIS_URL: &str = "redis://127.0.0.1/";
const VAR_CALCULATOR_URL: &str = "http://var-calculator.default.svc.cluster.local/var";

// --- Main Application Logic ---

#[tokio::main]
async fn main() {
    println!("--- Starting QuantumArb 2.0 Dynamic Risk Gateway ---");

    let client = redis::Client::open(REDIS_URL).expect("Invalid Redis URL");
    let con = Arc::new(tokio::sync::Mutex::new(
        client.get_async_connection().await.expect("Failed to connect to Redis"),
    ));

    setup_initial_account_state(con.clone()).await;

    // Spawn the background task to adjust limits based on VaR
    let con_clone = con.clone();
    tokio::spawn(async move {
        adjust_limits_from_var(con_clone).await;
    });

    // This part would listen for incoming order requests
    let mut interval = time::interval(Duration::from_secs(2));
    loop {
        interval.tick().await;
        let order_request = OrderRequest { order_id: Uuid::new_v4(), account_id: 101, price: 60150_00, size: (rand::random::<u32>() % 150) + 1 };
        println!("\nReceived Order Request: Size {}", order_request.size);
        let decision = check_pre_trade_risk(con.clone(), &order_request).await;
        println!("  -> Risk Decision: {:?}", decision);
    }
}

/// Sets up an initial account state in Redis.
async fn setup_initial_account_state(con_arc: Arc<tokio::sync::Mutex<redis::aio::Connection>>) {
    let mut con = con_arc.lock().await;
    let key = "account:101";
    if !con.exists::<_, bool>(key).await.unwrap_or(false) {
        let state = AccountState {
            account_id: 101,
            base_max_exposure: 100000.0,
            current_max_exposure: 100000.0,
            base_max_order_size: 100,
            current_max_order_size: 100,
            current_exposure: 50000.0,
        };
        let _: () = con.set(key, serde_json::to_string(&state).unwrap()).await.unwrap();
        println!("Initialized account 101 in Redis.");
    }
}

/// Background task that fetches VaR and adjusts risk limits.
async fn adjust_limits_from_var(con_arc: Arc<tokio::sync::Mutex<redis::aio::Connection>>) {
    let http_client = reqwest::Client::new();
    let mut interval = time::interval(Duration::from_secs(15));
    loop {
        interval.tick().await;
        println!("\nAdjusting limits based on VaR...");
        
        // Fetch latest VaR
        if let Ok(response) = http_client.get(VAR_CALCULATOR_URL).send().await {
            if let Ok(var_result) = response.json::<VaRResult>().await {
                let mut con = con_arc.lock().await;
                let key = "account:101";
                if let Ok(state_json) = con.get::<_, String>(key).await {
                    let mut state: AccountState = serde_json::from_str(&state_json).unwrap();

                    // Dynamic Adjustment Logic:
                    // If VaR is more than 5% of the portfolio value, tighten limits by 25%.
                    // Otherwise, use baseline limits.
                    let var_ratio = var_result.var_amount / var_result.portfolio_value;
                    if var_ratio > 0.05 {
                        println!("  -> High VaR detected ({:.2}%). Tightening limits.", var_ratio * 100.0);
                        state.current_max_order_size = (state.base_max_order_size as f32 * 0.75) as u32;
                        state.current_max_exposure = state.base_max_exposure * 0.75;
                    } else {
                        println!("  -> VaR is normal ({:.2}%). Using baseline limits.", var_ratio * 100.0);
                        state.current_max_order_size = state.base_max_order_size;
                        state.current_max_exposure = state.base_max_exposure;
                    }
                    
                    let _: () = con.set(key, serde_json::to_string(&state).unwrap()).await.unwrap();
                }
            }
        }
    }
}

/// Core risk check logic, now using the dynamically adjusted limits.
async fn check_pre_trade_risk(
    con_arc: Arc<tokio::sync::Mutex<redis::aio::Connection>>,
    order: &OrderRequest,
) -> RiskDecision {
    let mut con = con_arc.lock().await;
    let key = format!("account:{}", order.account_id);
    let state_json: String = match con.get(&key).await {
        Ok(val) => val,
        Err(_) => return RiskDecision::Rejected("Account not found".to_string()),
    };
    let state: AccountState = serde_json::from_str(&state_json).unwrap();

    // Check against the CURRENT (dynamically adjusted) limits
    if order.size > state.current_max_order_size {
        return RiskDecision::Rejected(format!(
            "Order size {} exceeds current dynamic limit {}",
            order.size, state.current_max_order_size
        ));
    }
    // ... other checks ...
    RiskDecision::Approved
}
