/*
 * QuantumArb 2.0 - Core Services: Exchange Gateway (Oracle Integrated)
 *
 * File: src/core_services/exchange_gateway/main.rs
 *
 * Description:
 * This is the final, fully integrated version of the Exchange Gateway. It now
 * queries the Latency Oracle before sending an order to dynamically select the
 * fastest available network path (e.g., Microwave or Fiber).
 *
 * This completes the core tick-to-trade path, incorporating dynamic routing
 * for ultra-low-latency performance.
 *
 * To run (with a Cargo.toml file):
 * [dependencies]
 * tokio = { version = "1", features = ["full"] }
 * serde = { version = "1.0", features = ["derive"] }
 * serde_json = "1.0"
 * uuid = { version = "1", features = ["v4"] }
 * reqwest = "0.12"
 */

use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use tokio::time::{self, Duration};
use uuid::Uuid;

// --- Data Structures ---

#[derive(Debug, Clone, Serialize, Deserialize)]
struct InboundOrder {
    internal_order_id: Uuid,
    instrument_symbol: String,
    price: u64,
    size: u32,
    side: OrderSide,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
enum OrderStatus {
    New,
    SentToExchange,
    PartiallyFilled,
    Filled,
    Canceled,
    RejectedByExchange,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
enum OrderSide {
    Buy,
    Sell,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct ExecutionReport {
    exchange_order_id: String,
    internal_order_id: Uuid,
    status: OrderStatus,
    filled_size: u32,
    filled_price: u64,
}

// --- NEW: Structures for Latency Oracle ---
#[derive(Debug, Deserialize, Copy, Clone)]
enum NetworkPath {
    Microwave,
    Fiber,
}

#[derive(Debug, Deserialize)]
struct OracleResponse {
    path: NetworkPath,
    latency_us: u32,
}

const LATENCY_ORACLE_URL: &str = "http://latency-oracle.default.svc.cluster.local/fastest-path";


// --- Main Application Logic ---

#[tokio::main]
async fn main() {
    println!("--- Starting QuantumArb 2.0 Exchange Gateway (Oracle Integrated) ---");

    let mut open_orders: HashMap<Uuid, InboundOrder> = HashMap::new();
    let http_client = reqwest::Client::new();

    println!("Simulating connection to 'CME Group' exchange...");

    let mut interval = time::interval(Duration::from_secs(4));
    loop {
        interval.tick().await;

        let inbound_order = generate_simulated_inbound_order();
        let order_id = inbound_order.internal_order_id;
        println!("\nReceived Inbound Order: ID {}", order_id);

        // NEW: Query the latency oracle to get the fastest path
        let fastest_path = get_fastest_path(&http_client).await.unwrap_or(NetworkPath::Fiber); // Default to Fiber on error

        // Send the order to the "exchange" via the selected path
        send_order_to_exchange(&inbound_order, fastest_path);
        open_orders.insert(order_id, inbound_order);

        let exec_report = generate_simulated_execution_report(order_id);
        println!("  -> Received Execution Report: Status {:?}", exec_report.status);

        process_execution_report(&mut open_orders, &exec_report);
        publish_report_to_internal_bus(&exec_report);
    }
}

/// NEW: Function to get the fastest path from the Latency Oracle.
async fn get_fastest_path(client: &reqwest::Client) -> Option<NetworkPath> {
    println!("  -> Querying Latency Oracle for fastest path...");
    match client.get(LATENCY_ORACLE_URL).send().await {
        Ok(response) => match response.json::<OracleResponse>().await {
            Ok(oracle_response) => {
                println!("  -> Oracle recommends: {:?} ({}µs)", oracle_response.path, oracle_response.latency_us);
                Some(oracle_response.path)
            }
            Err(_) => {
                println!("  -> Error parsing Oracle response.");
                None
            }
        },
        Err(_) => {
            println!("  -> Failed to connect to Latency Oracle.");
            None
        }
    }
}

/// Simulates a new order arriving from the internal system.
fn generate_simulated_inbound_order() -> InboundOrder {
    InboundOrder {
        internal_order_id: Uuid::new_v4(),
        instrument_symbol: "ESZ25".to_string(),
        price: 4500_25,
        size: 10,
        side: OrderSide::Buy,
    }
}

/// Simulates sending the order, now with path selection.
fn send_order_to_exchange(order: &InboundOrder, path: NetworkPath) {
    println!(
        "  -> Sending order via [{:?}] path: Symbol {}, Size {}",
        path, order.instrument_symbol, order.size
    );
}

/// Simulates an execution report coming back from the exchange.
fn generate_simulated_execution_report(internal_id: Uuid) -> ExecutionReport {
    ExecutionReport {
        exchange_order_id: format!("EXCH-{}", Uuid::new_v4().to_simple()),
        internal_order_id: internal_id,
        status: OrderStatus::Filled,
        filled_size: 10,
        filled_price: 4500_25,
    }
}

/// Updates the local state based on the execution report.
fn process_execution_report(
    open_orders: &mut HashMap<Uuid, InboundOrder>,
    report: &ExecutionReport,
) {
    if report.status == OrderStatus::Filled || report.status == OrderStatus::Canceled {
        if open_orders.remove(&report.internal_order_id).is_some() {
            println!("  -> Order {} is now closed.", report.internal_order_id);
        }
    }
}

/// Publishes the execution report to an internal topic for other services.
fn publish_report_to_internal_bus(report: &ExecutionReport) {
    let report_json = serde_json::to_string_pretty(report).unwrap();
    println!(
        "  -> Publishing to topic 'execution_reports':\n{}",
        report_json
    );
}
