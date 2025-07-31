/*
 * QuantumArb 2.0 - Risk & Compliance: Real-time VaR Calculator
 *
 * File: src/risk_compliance/var_calculator/main.rs
 *
 * Description:
 * This microservice calculates the Value at Risk (VaR) for a given portfolio
 * in near real-time. It uses a Monte Carlo simulation method, which is
 * computationally intensive but highly flexible for handling complex,
 * non-normal return distributions.
 *
 * Its primary role is to:
 * 1. Maintain the current portfolio of positions.
 * 2. Periodically run a Monte Carlo simulation to generate thousands of
 * potential future portfolio values.
 * 3. Calculate the VaR at a specific confidence level (e.g., 99%) from
 * the simulation results.
 * 4. Expose the calculated VaR via an API for consumption by risk dashboards
 * and the main risk gateway.
 *
 * To run (with a Cargo.toml file):
 * [dependencies]
 * tokio = { version = "1", features = ["full"] }
 * warp = "0.3"
 * serde = { version = "1.0", features = ["derive"] }
 * rand = "0.8"
 * rand_distr = "0.4"
 */

use rand::thread_rng;
use rand_distr::{Distribution, Normal};
use serde::Serialize;
use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use tokio::time::{self, Duration};
use warp::Filter;

// --- Data Structures ---

#[derive(Debug, Clone, Serialize)]
struct Position {
    symbol: String,
    quantity: i64,      // Can be negative for short positions
    current_price: f64,
    daily_return_volatility: f64, // Standard deviation of daily returns
}

#[derive(Debug, Clone, Serialize)]
struct VaRResult {
    confidence_level: f64,
    var_amount: f64, // The calculated Value at Risk
    portfolio_value: f64,
    timestamp_utc: String,
}

type PortfolioState = Arc<Mutex<HashMap<String, Position>>>;
type VaRHistory = Arc<Mutex<Option<VaRResult>>>;

// --- Main Application Logic ---

#[tokio::main]
async fn main() {
    println!("--- Starting QuantumArb 2.0 Real-time VaR Calculator ---");

    // Initialize the portfolio state
    let portfolio = Arc::new(Mutex::new(load_initial_portfolio()));
    // Store the latest VaR result
    let latest_var = Arc::new(Mutex::new(None));

    // Spawn the background calculation task
    let portfolio_clone = portfolio.clone();
    let latest_var_clone = latest_var.clone();
    tokio::spawn(async move {
        run_var_calculations(portfolio_clone, latest_var_clone).await;
    });

    // --- API Endpoint to get the latest VaR ---
    let get_var = warp::path("var")
        .and(warp::get())
        .and(with_state(latest_var))
        .and_then(handler_get_latest_var);

    println!("API server running at http://127.0.0.1:3031/var");
    warp::serve(get_var).run(([127, 0, 0, 1], 3031)).await;
}

/// Warp filter to inject state into the handler.
fn with_state<T: Clone + Send>(
    state: T,
) -> impl Filter<Extract = (T,), Error = std::convert::Infallible> + Clone {
    warp::any().map(move || state.clone())
}

/// Handler for the /var API endpoint.
async fn handler_get_latest_var(state: VaRHistory) -> Result<impl warp::Reply, warp::Rejection> {
    let result = state.lock().unwrap().clone();
    match result {
        Some(var_result) => Ok(warp::reply::json(&var_result)),
        None => Ok(warp::reply::json(&serde_json::json!({ "error": "VaR not calculated yet." }))),
    }
}

/// Background task to periodically run the Monte Carlo VaR simulation.
async fn run_var_calculations(portfolio: PortfolioState, latest_var: VaRHistory) {
    let mut interval = time::interval(Duration::from_secs(15)); // Recalculate every 15 seconds
    loop {
        interval.tick().await;
        println!("\nRunning new Monte Carlo VaR simulation...");

        let portfolio_snapshot = portfolio.lock().unwrap().clone();
        let num_simulations = 10000;
        let confidence_level = 0.99;
        let time_horizon_days = 1;

        let mut final_values = Vec::with_capacity(num_simulations);
        let initial_portfolio_value: f64 = portfolio_snapshot
            .values()
            .map(|p| p.quantity as f64 * p.current_price)
            .sum();

        for _ in 0..num_simulations {
            let mut simulated_portfolio_value = 0.0;
            for position in portfolio_snapshot.values() {
                // Assume returns are normally distributed (a simplification)
                let normal = Normal::new(0.0, position.daily_return_volatility).unwrap();
                let random_return = normal.sample(&mut thread_rng());
                
                let simulated_price = position.current_price * (1.0 + random_return);
                simulated_portfolio_value += position.quantity as f64 * simulated_price;
            }
            final_values.push(simulated_portfolio_value);
        }

        // Calculate VaR by finding the appropriate percentile in the simulated losses
        let mut losses: Vec<f64> = final_values
            .into_iter()
            .map(|final_value| initial_portfolio_value - final_value)
            .collect();
        losses.sort_by(|a, b| a.partial_cmp(b).unwrap());

        let var_index = (num_simulations as f64 * confidence_level) as usize;
        let var_amount = losses[var_index];

        let result = VaRResult {
            confidence_level,
            var_amount,
            portfolio_value: initial_portfolio_value,
            timestamp_utc: chrono::Utc::now().to_rfc3339(),
        };
        
        println!("  -> Simulation Complete. 99% VaR: ${:.2}", result.var_amount);
        *latest_var.lock().unwrap() = Some(result);
    }
}

/// Loads a mock portfolio for the simulation.
fn load_initial_portfolio() -> HashMap<String, Position> {
    let mut portfolio = HashMap::new();
    portfolio.insert("BTC".to_string(), Position {
        symbol: "BTC".to_string(),
        quantity: 10,
        current_price: 60000.0,
        daily_return_volatility: 0.02, // 2% daily volatility
    });
    portfolio.insert("ETH".to_string(), Position {
        symbol: "ETH".to_string(),
        quantity: 50,
        current_price: 3000.0,
        daily_return_volatility: 0.03, // 3% daily volatility
    });
    portfolio
}
