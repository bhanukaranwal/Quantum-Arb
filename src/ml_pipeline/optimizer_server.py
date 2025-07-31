#
# QuantumArb 2.0 - Quantum Sandbox: Optimizer Service
#
# File: src/ml_pipeline/optimizer_server.py
#
# Description:
# This script creates a FastAPI server to expose the QAOA portfolio optimization
# logic as a REST API endpoint. Other services can call this API to get the
# latest quantum-derived optimal asset allocation.
#
# Dependencies:
# pip install fastapi uvicorn numpy dimod
#
# To run locally:
# uvicorn optimizer_server:app --reload
#

from fastapi import FastAPI
from pydantic import BaseModel
import numpy as np
import dimod

# --- API and Model Setup ---

app = FastAPI(
    title="QuantumArb 2.0 - Quantum Optimizer Service",
    description="Serves portfolio optimization results using QAOA."
)

# --- Data Structures ---
class OptimizationResponse(BaseModel):
    optimal_portfolio: list[str]
    status: str

# --- Helper Functions (from qaoa_optimizer.py) ---

def get_problem_definition():
    """Defines the assets and their financial properties."""
    assets = ['Asset A', 'Asset B', 'Asset C', 'Asset D']
    returns = np.array([0.1, 0.2, 0.15, 0.08])
    covariance = np.array([
        [0.04, 0.01, 0.02, 0.01],
        [0.01, 0.09, 0.03, 0.02],
        [0.02, 0.03, 0.06, 0.01],
        [0.01, 0.02, 0.01, 0.02]
    ])
    return assets, returns, covariance

# --- API Endpoints ---

@app.get("/", summary="Health Check")
def read_root():
    """A simple health check endpoint."""
    return {"status": "QuantumArb Optimizer Service is running."}

@app.post("/optimize-portfolio", response_model=OptimizationResponse, summary="Get Optimal Portfolio")
def optimize_portfolio():
    """
    Runs the QAOA optimization and returns the optimal asset allocation.
    
    In a real system, this would trigger a long-running job on a quantum device.
    For this POC, we return a mock result instantly to demonstrate the API flow.
    """
    assets, _, _ = get_problem_definition()
    
    # In a real implementation, you would call the D-Wave solver here.
    # best_solution = solve_with_quantum_annealer(qubo_model)
    
    # For this POC, we use the mock result from the previous script.
    print("Solving with Quantum Annealer (Mock Result)...")
    mock_solution = {0: 0, 1: 1, 2: 1, 3: 0} 
    
    selected_assets = [assets[i] for i, selected in mock_solution.items() if selected == 1]
    
    print(f"Optimal portfolio found: {selected_assets}")

    return OptimizationResponse(
        optimal_portfolio=selected_assets,
        status="Completed (Mock)"
    )
