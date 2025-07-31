/*
 * QuantumArb 2.0 - Risk & Compliance: Risk Gateway
 *
 * File: src/risk_compliance/risk_gateway/main.rs
 *
 * Description:
 * This microservice acts as a centralized pre-trade risk gateway. It receives
 * order requests from the strategy engine and validates them against a more
* complex set of rules than what is feasible on the FPGA.
 *
 * In a real system, this service would:
 * - Maintain a real-time state of account positions and exposure.
 * - Subscribe to a control plane to receive dynamic risk limit updates.
 * - Log every decision for audit and compliance purposes (e.g., to a WORM store).
 * - Communicate over a low-latency RPC framework like gRPC.
 *
 * This POC demonstrates the core validation logic.
 *
 * To run (with a Cargo.toml file):
 * [dependencies]
 * tokio = { version = "1", features = ["full"] }
 * uuid = { version = "1", features = ["v4"] }
 */

use std::collections::HashMap;
use tokio::time::{self, Duration};
use uuid::Uuid;

// --- Data Structures ---

/// Represents a trading order request to be validated.
#[derive(Debug, Clone)]
struct OrderRequest {
    order_id: Uuid,
    account_id: u32,
    instrument_id: u32,
    price: u64,
    size: u32,
    side: OrderSide,
}

#[derive(Debug, Clone, PartialEq)]
enum OrderSide {
    Buy,
    Sell,
}

/// Represents the current state and limits for a trading account.
/// In a real system, this would be stored in a low-latency database like Redis or an in-memory store.
#[derive(Debug)]
struct AccountState {
    account_id: u32,
    // Total notional exposure (sum of position values)
    current_exposure: f64,
    // Max allowed notional exposure
    max_exposure: f64,
    // Max size for a single order
    max_order_size: u32,
    // Positions held per instrument
    positions: HashMap<u32, i64>, // Using i64 to handle long/short positions
}

/// The result of a risk check.
#[derive(Debug, PartialEq)]
enum RiskDecision {
    Approved,
    Rejected(String), // Reason for rejection
}


// --- Main Application Logic ---

#[tokio::main]
async fn main() {
    println!("--- Starting QuantumArb 2.0 Risk Gateway ---");

    // Initialize account state (in a real app, load from a persistent store)
    let mut account = AccountState {
        account_id: 101,
        current_exposure: 50000.0,
        max_exposure: 100000.0,
        max_order_size: 100,
        positions: HashMap::from([(1, 10), (2, -5)]), // Long 10 of instrument 1, short 5 of 2
    };

    println!("Initial Account State: {:?}", account);

    // --- Main Processing Loop ---
    // This loop simulates receiving order requests to be validated.
    let mut interval = time::interval(Duration::from_secs(2));
    loop {
        interval.tick().await;

        // Simulate an incoming order request from the strategy engine
        let order_request = generate_simulated_order();
        println!("\nReceived Order Request: {:?}", order_request);

        // Perform the risk check
        let decision = check_pre_trade_risk(&account, &order_request);
        println!("  -> Risk Decision: {:?}", decision);

        // If approved, update the account state to reflect the new pending order
        if decision == RiskDecision::Approved {
            update_account_state(&mut account, &order_request);
            println!("  -> Updated Account State: Exposure = ${:.2}", account.current_exposure);
        }
    }
}

/// Simulates a new order request.
fn generate_simulated_order() -> OrderRequest {
    OrderRequest {
        order_id: Uuid::new_v4(),
        account_id: 101,
        instrument_id: 1,
        price: 60150_00, // $60,150.00
        size: (rand::random::<u32>() % 150) + 1, // Random size up to 150
        side: OrderSide::Buy,
    }
}

/// The core logic for checking pre-trade risk.
fn check_pre_trade_risk(state: &AccountState, order: &OrderRequest) -> RiskDecision {
    // 1. Check max order size
    if order.size > state.max_order_size {
        return RiskDecision::Rejected(format!(
            "Order size {} exceeds max limit {}",
            order.size, state.max_order_size
        ));
    }

    // 2. Check max exposure
    let order_notional_value = (order.price as f64 / 100.0) * order.size as f64;
    let potential_new_exposure = state.current_exposure + order_notional_value;

    if potential_new_exposure > state.max_exposure {
        return RiskDecision::Rejected(format!(
            "Order would breach max exposure limit. New exposure ${:.2} > ${:.2}",
            potential_new_exposure, state.max_exposure
        ));
    }

    // Add other checks here (e.g., order frequency, symbol-specific limits, etc.)

    RiskDecision::Approved
}

/// Updates the account's state after an order is approved.
/// This would be more complex in a real system, handling partial fills, cancellations, etc.
fn update_account_state(state: &mut AccountState, order: &OrderRequest) {
    let order_notional_value = (order.price as f64 / 100.0) * order.size as f64;
    state.current_exposure += order_notional_value;

    let position_change = match order.side {
        OrderSide::Buy => order.size as i64,
        OrderSide::Sell => -(order.size as i64),
    };

    *state.positions.entry(order.instrument_id).or_insert(0) += position_change;
}

