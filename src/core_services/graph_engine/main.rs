/*
 * QuantumArb 2.0 - Core Services: Cross-Asset Graph Engine
 *
 * File: src/core_services/graph_engine/main.rs
 *
 * Description:
 * This advanced microservice models financial markets as a directed graph, where
 * assets are nodes and exchange rates are weighted edges. It uses graph theory
 * algorithms to detect complex, multi-leg arbitrage opportunities that are not
 * visible to simpler systems.
 *
 * This POC implements a detector for triangular arbitrage in FX markets by
 * searching for negative cycles in the graph of log-transformed exchange rates.
 */

use petgraph::graph::{Graph, NodeIndex};
use petgraph::algo::bellman_ford;
use serde::Serialize;
use std::collections::HashMap;
use tokio::time::{self, Duration};
use warp::Filter;

// --- Data Structures ---

#[derive(Debug, Clone, Serialize)]
struct ArbitrageOpportunity {
    path: Vec<String>,
    profit_ratio: f64,
}

// --- Main Application Logic ---

#[tokio::main]
async fn main() {
    println!("--- Starting QuantumArb 2.0 Cross-Asset Graph Engine ---");

    // This would be updated in real-time from market data feeds
    let mut exchange_rates = HashMap::new();
    exchange_rates.insert(("USD", "EUR"), 0.92);
    exchange_rates.insert(("EUR", "JPY"), 165.25);
    // This rate creates an arbitrage opportunity: 1/151.95 = 0.00658
    exchange_rates.insert(("JPY", "USD"), 0.00665); 

    // Build the graph
    let mut graph = Graph::<&str, f64>::new();
    let mut node_map = HashMap::new();

    for (from, to) in exchange_rates.keys() {
        node_map.entry(from).or_insert_with(|| graph.add_node(from));
        node_map.entry(to).or_insert_with(|| graph.add_node(to));
    }

    for ((from, to), rate) in &exchange_rates {
        let from_node = node_map[from];
        let to_node = node_map[to];
        // Use the negative logarithm of the rate as the edge weight
        graph.add_edge(from_node, to_node, -rate.log(std::f64::consts::E));
    }

    // Use Bellman-Ford algorithm to detect negative cycles
    println!("Searching for arbitrage opportunities (negative cycles)...");
    let start_node = node_map["USD"];
    match bellman_ford(&graph, start_node) {
        Ok(_) => println!("No arbitrage opportunities found."),
        Err(e) => {
            println!("ARBITRAGE DETECTED!");
            // The error from bellman_ford in petgraph contains the cycle
            // A real implementation would parse this to show the path.
            let opportunity = ArbitrageOpportunity {
                path: vec!["USD".to_string(), "EUR".to_string(), "JPY".to_string(), "USD".to_string()],
                profit_ratio: 1.015, // Mock profit
            };
            println!("  -> Path: {}", opportunity.path.join(" -> "));
            println!("  -> Profit: {:.2}%", (opportunity.profit_ratio - 1.0) * 100.0);
        }
    }
}
