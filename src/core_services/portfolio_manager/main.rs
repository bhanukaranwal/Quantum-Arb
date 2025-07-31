/*
 * QuantumArb 2.0 - Core Services: Portfolio Manager
 *
 * File: src/core_services/portfolio_manager/main.rs
 *
 * Description:
 * This microservice is the single source of truth for the firm's trading
 * positions and profit & loss (P&L). It consumes execution reports to update
 * positions and continuously marks them to market to calculate unrealized P&L.
 *
 * Its primary role is to:
 * 1. Subscribe to execution reports to track fills.
 * 2. Subscribe to market data to get real-time prices for P&L calculation.
 * 3. Maintain a state of all positions (e.g., quantity, average entry price).
 * 4. Calculate and expose Realized and Unrealized P&L via an API.
 */

use serde::Serialize;
use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use tokio::time::{self, Duration};
use warp::Filter;

// --- Data Structures ---

#[derive(Debug, Clone, Serialize)]
struct Position {
    symbol: String,
    quantity: i64,
    average_entry_price: f64,
    current_market_price: f64,
    unrealized_pnl: f64,
}

#[derive(Debug, Clone, Serialize)]
struct PortfolioSnapshot {
    positions: HashMap<String, Position>,
    realized_pnl: f64,
    total_unrealized_pnl: f64,
    total_portfolio_value: f64,
    timestamp_utc: String,
}

// Represents a fill from an execution report
struct Fill {
    symbol: String,
    quantity: i64, // Positive for buy, negative for sell
    price: f64,
}

type SharedPortfolio = Arc<Mutex<PortfolioSnapshot>>;

// --- Main Application Logic ---

#[tokio::main]
async fn main() {
    println!("--- Starting QuantumArb 2.0 Portfolio Manager ---");

    // Initialize the shared portfolio state
    let portfolio = Arc::new(Mutex::new(PortfolioSnapshot {
        positions: HashMap::new(),
        realized_pnl: 0.0,
        total_unrealized_pnl: 0.0,
        total_portfolio_value: 0.0,
        timestamp_utc: chrono::Utc::now().to_rfc3339(),
    }));

    // Spawn background tasks
    let portfolio_clone_1 = portfolio.clone();
    tokio::spawn(async move {
        listen_for_fills(portfolio_clone_1).await;
    });

    let portfolio_clone_2 = portfolio.clone();
    tokio::spawn(async move {
        mark_to_market(portfolio_clone_2).await;
    });

    // --- API Endpoint to get the latest portfolio snapshot ---
    let get_portfolio = warp::path("portfolio")
        .and(warp::get())
        .and(with_state(portfolio))
        .and_then(handler_get_portfolio);
    
    println!("API server running at http://127.0.0.1:3032/portfolio");
    warp::serve(get_portfolio).run(([127, 0, 0, 1], 3032)).await;
}

/// Warp filter to inject state into the handler.
fn with_state(
    state: SharedPortfolio,
) -> impl Filter<Extract = (SharedPortfolio,), Error = std::convert::Infallible> + Clone {
    warp::any().map(move || state.clone())
}

/// Handler for the /portfolio API endpoint.
async fn handler_get_portfolio(state: SharedPortfolio) -> Result<impl warp::Reply, warp::Rejection> {
    let portfolio_snapshot = state.lock().unwrap().clone();
    Ok(warp::reply::json(&portfolio_snapshot))
}

/// Simulates listening for execution reports (fills) from the message bus.
async fn listen_for_fills(portfolio: SharedPortfolio) {
    let mut interval = time::interval(Duration::from_secs(5));
    loop {
        interval.tick().await;
        // Simulate receiving a new fill
        let fill = Fill { symbol: "BTC".to_string(), quantity: 2, price: 60100.50 };
        println!("\nReceived Fill: Buy 2 BTC @ 60100.50");

        let mut p = portfolio.lock().unwrap();
        let position = p.positions.entry(fill.symbol.clone()).or_insert(Position {
            symbol: fill.symbol.clone(),
            quantity: 0,
            average_entry_price: 0.0,
            current_market_price: fill.price,
            unrealized_pnl: 0.0,
        });

        // Update position based on the fill
        let old_quantity = position.quantity;
        let new_quantity = old_quantity + fill.quantity;

        // If position is closed or reduced, calculate realized P&L
        if old_quantity.signum() != new_quantity.signum() && new_quantity != 0 {
            let closed_quantity = std::cmp::min(old_quantity.abs(), fill.quantity.abs());
            let realized = (fill.price - position.average_entry_price) * closed_quantity as f64 * old_quantity.signum() as f64;
            p.realized_pnl += realized;
            println!("  -> Realized P&L: ${:.2}", realized);
        }
        
        // Update average entry price
        if new_quantity != 0 {
            position.average_entry_price = ((position.average_entry_price * old_quantity as f64) + (fill.price * fill.quantity as f64)) / new_quantity as f64;
        } else {
            position.average_entry_price = 0.0; // Position is flat
        }
        position.quantity = new_quantity;
    }
}

/// Simulates receiving market data and marking positions to market.
async fn mark_to_market(portfolio: SharedPortfolio) {
    let mut interval = time::interval(Duration::from_secs(1));
    loop {
        interval.tick().await;
        let mut p = portfolio.lock().unwrap();
        if p.positions.is_empty() { continue; }

        let mut total_unrealized = 0.0;
        let mut total_value = 0.0;

        // Simulate new market price for BTC
        let new_btc_price = 60100.50 + (rand::random::<f64>() * 20.0 - 10.0);
        
        if let Some(position) = p.positions.get_mut("BTC") {
            position.current_market_price = new_btc_price;
            position.unrealized_pnl = (position.current_market_price - position.average_entry_price) * position.quantity as f64;
            total_unrealized += position.unrealized_pnl;
            total_value += position.quantity as f64 * position.current_market_price;
        }
        
        p.total_unrealized_pnl = total_unrealized;
        p.total_portfolio_value = total_value;
        p.timestamp_utc = chrono::Utc::now().to_rfc3339();
    }
}
