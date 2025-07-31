/*
 * QuantumArb 2.0 - Risk & Compliance: Trade Surveillance Service
 *
 * File: src/risk_compliance/trade_surveillance_service/main.rs
 *
 * Description:
 * This microservice performs post-trade surveillance to detect potentially
 * manipulative or non-compliant trading patterns, as required by regulations
 * like FINRA Rule 3110.
 *
 * It consumes a stream of all order-related events and applies rules to
 * identify patterns like spoofing, layering, or wash trading.
 *
 * This POC implements a simple rule to detect "layering": placing a large
 * order to create a false sense of liquidity, and then cancelling it shortly after.
 */

use serde::Serialize;
use std::collections::{HashMap, VecDeque};
use std::sync::{Arc, Mutex};
use tokio::time::{self, Duration, Instant};
use warp::Filter;

// --- Data Structures ---

#[derive(Debug, Clone)]
enum OrderEventType {
    New,
    Canceled,
    Filled,
}

#[derive(Debug, Clone)]
struct OrderEvent {
    strategy_id: String,
    order_id: String,
    event_type: OrderEventType,
    size: u32,
    timestamp: Instant,
}

#[derive(Debug, Clone, Serialize)]
struct ComplianceAlert {
    alert_id: String,
    strategy_id: String,
    pattern_detected: String,
    description: String,
    timestamp_utc: String,
}

// State to track recent orders for each strategy
type StrategyOrderHistory = Arc<Mutex<HashMap<String, VecDeque<OrderEvent>>>>;
type GeneratedAlerts = Arc<Mutex<Vec<ComplianceAlert>>>;

// --- Main Application Logic ---

#[tokio::main]
async fn main() {
    println!("--- Starting QuantumArb 2.0 Trade Surveillance Service ---");

    let order_history = Arc::new(Mutex::new(HashMap::new()));
    let alerts = Arc::new(Mutex::new(Vec::new()));

    // Spawn background task to simulate receiving order events
    let history_clone = order_history.clone();
    let alerts_clone = alerts.clone();
    tokio::spawn(async move {
        listen_for_order_events(history_clone, alerts_clone).await;
    });

    // --- API Endpoint to get the latest compliance alerts ---
    let get_alerts = warp::path("alerts")
        .and(warp::get())
        .and(with_state(alerts))
        .and_then(handler_get_alerts);

    println!("API server running at http://127.0.0.1:3033/alerts");
    warp::serve(get_alerts).run(([127, 0, 0, 1], 3033)).await;
}

/// Warp filter to inject state into the handler.
fn with_state<T: Clone + Send>(
    state: T,
) -> impl Filter<Extract = (T,), Error = std::convert::Infallible> + Clone {
    warp::any().map(move || state.clone())
}

/// Handler for the /alerts API endpoint.
async fn handler_get_alerts(state: GeneratedAlerts) -> Result<impl warp::Reply, warp::Rejection> {
    let alerts_snapshot = state.lock().unwrap().clone();
    Ok(warp::reply::json(&alerts_snapshot))
}

/// Simulates listening for all order events from the message bus.
async fn listen_for_order_events(history: StrategyOrderHistory, alerts: GeneratedAlerts) {
    let mut interval = time::interval(Duration::from_secs(2));
    loop {
        interval.tick().await;

        // Simulate a sequence of events indicative of layering
        let events = vec![
            OrderEvent { strategy_id: "NLP-NEWS-TRADER".to_string(), order_id: "A1".to_string(), event_type: OrderEventType::New, size: 5000, timestamp: Instant::now() },
            OrderEvent { strategy_id: "NLP-NEWS-TRADER".to_string(), order_id: "A2".to_string(), event_type: OrderEventType::New, size: 10, timestamp: Instant::now() + Duration::from_millis(50) },
            OrderEvent { strategy_id: "NLP-NEWS-TRADER".to_string(), order_id: "A2".to_string(), event_type: OrderEventType::Filled, size: 10, timestamp: Instant::now() + Duration::from_millis(100) },
            OrderEvent { strategy_id: "NLP-NEWS-TRADER".to_string(), order_id: "A1".to_string(), event_type: OrderEventType::Canceled, size: 5000, timestamp: Instant::now() + Duration::from_millis(150) },
        ];
        
        println!("\nReceived Batch of 4 Order Events...");
        for event in events {
            let mut history_lock = history.lock().unwrap();
            let strategy_history = history_lock.entry(event.strategy_id.clone()).or_insert_with(VecDeque::new);
            strategy_history.push_back(event.clone());

            // Keep history to a reasonable size
            if strategy_history.len() > 100 {
                strategy_history.pop_front();
            }
            
            // Run detection logic
            detect_layering_pattern(strategy_history, &alerts);
        }
    }
}

/// The core detection logic for a layering/spoofing pattern.
fn detect_layering_pattern(history: &VecDeque<OrderEvent>, alerts: &GeneratedAlerts) {
    // A very simple rule: find a large new order followed by a cancellation of that same order
    // within a short time window (e.g., 200ms).
    if history.len() < 2 { return; }

    if let (Some(last_event), Some(first_event)) = (history.back(), history.front()) {
        if last_event.order_id == first_event.order_id &&
           matches!(first_event.event_type, OrderEventType::New) &&
           matches!(last_event.event_type, OrderEventType::Canceled) &&
           first_event.size > 1000 && // Was a large order
           last_event.timestamp.duration_since(first_event.timestamp) < Duration::from_millis(200) {
            
            let description = format!(
                "Strategy placed large order {} (size {}) and canceled it within 200ms.",
                first_event.order_id, first_event.size
            );
            
            let alert = ComplianceAlert {
                alert_id: format!("ALERT-{}", rand::random::<u32>()),
                strategy_id: first_event.strategy_id.clone(),
                pattern_detected: "Potential Layering/Spoofing".to_string(),
                description,
                timestamp_utc: chrono::Utc::now().to_rfc3339(),
            };
            
            println!("  -> COMPLIANCE ALERT: {}", alert.pattern_detected);
            alerts.lock().unwrap().push(alert);
            
            // Clear history after detection to avoid re-alerting
            // In a real system, you'd have more sophisticated state management.
            // history.clear();
        }
    }
}
