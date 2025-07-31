/*
 * QuantumArb 2.0 - Core Services: Latency Oracle
 *
 * File: src/core_services/latency_oracle/main.rs
 *
 * Description:
 * This microservice continuously monitors the latency of different network paths
 * (e.g., a primary microwave link and a backup fiber link) to a specific
 * destination, like an exchange's matching engine.
 *
 * It exposes a simple API endpoint that other services, primarily the
 * exchange_gateway, can query to get the fastest currently available path
 * for sending an order.
 *
 * To run (with a Cargo.toml file):
 * [dependencies]
 * tokio = { version = "1", features = ["full"] }
 * warp = "0.3"
 * serde = { version = "1.0", features = ["derive"] }
 * rand = "0.8"
 */

use serde::Serialize;
use std::sync::{Arc, Mutex};
use tokio::time::{self, Duration};
use warp::Filter;

// --- Data Structures ---

#[derive(Debug, Clone, Serialize, Copy)]
enum NetworkPath {
    Microwave,
    Fiber,
}

/// Represents the state of the network paths.
/// In a real system, this would be updated by a background process
/// that sends and receives custom ICMP or UDP packets to measure RTT.
#[derive(Debug, Clone, Serialize)]
struct PathState {
    path: NetworkPath,
    latency_us: u32, // Latency in microseconds
}

/// The shared state that the API and the monitoring loop will use.
/// We use Arc<Mutex> to allow safe concurrent access.
type SharedState = Arc<Mutex<Vec<PathState>>>;

// --- Main Application Logic ---

#[tokio::main]
async fn main() {
    println!("--- Starting QuantumArb 2.0 Latency Oracle ---");

    // Initialize the shared state with some default values.
    let state = Arc::new(Mutex::new(vec![
        PathState { path: NetworkPath::Microwave, latency_us: 4010 }, // ~4.01ms
        PathState { path: NetworkPath::Fiber, latency_us: 4550 },     // ~4.55ms
    ]));

    // Spawn a background task to simulate latency monitoring.
    let monitoring_state = state.clone();
    tokio::spawn(async move {
        monitor_network_paths(monitoring_state).await;
    });

    // --- API Endpoint Definition ---
    // GET /fastest-path -> returns the path with the lowest latency.
    let get_fastest_path = warp::path("fastest-path")
        .and(warp::get())
        .and(with_state(state))
        .and_then(handler_get_fastest_path);

    println!("API server running at http://127.0.0.1:3030/fastest-path");
    warp::serve(get_fastest_path).run(([127, 0, 0, 1], 3030)).await;
}

/// Warp filter to inject the shared state into the handler.
fn with_state(state: SharedState) -> impl Filter<Extract = (SharedState,), Error = std::convert::Infallible> + Clone {
    warp::any().map(move || state.clone())
}

/// The handler function for the /fastest-path endpoint.
async fn handler_get_fastest_path(state: SharedState) -> Result<impl warp::Reply, warp::Rejection> {
    let paths = state.lock().unwrap();
    
    // Find the path with the minimum latency.
    let fastest_path = paths.iter().min_by_key(|p| p.latency_us).unwrap();

    println!("  -> API Request: Fastest path is {:?} with {}µs latency.", fastest_path.path, fastest_path.latency_us);
    Ok(warp::reply::json(fastest_path))
}

/// Background task to simulate continuous monitoring of network paths.
async fn monitor_network_paths(state: SharedState) {
    let mut interval = time::interval(Duration::from_secs(1));
    loop {
        interval.tick().await;

        let mut paths = state.lock().unwrap();
        println!("\nMonitoring network paths...");

        for path_state in paths.iter_mut() {
            // Simulate random fluctuations in latency.
            // Microwave is generally faster but more susceptible to jitter (e.g., from weather).
            let jitter_us = match path_state.path {
                NetworkPath::Microwave => rand::random::<i32>() % 100 - 50, // -50µs to +50µs
                NetworkPath::Fiber => rand::random::<i32>() % 20 - 10,       // -10µs to +10µs
            };
            
            // Apply the jitter, ensuring latency doesn't go below a baseline.
            let new_latency = (path_state.latency_us as i32 + jitter_us).max(4000);
            path_state.latency_us = new_latency as u32;

            println!("  -> Path: {:?}, New Latency: {}µs", path_state.path, path_state.latency_us);
        }
    }
}
