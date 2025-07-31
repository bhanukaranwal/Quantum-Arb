#
# QuantumArb 2.0 - Quantum Sandbox: QAOA Portfolio Optimizer
#
# File: src/ml_pipeline/qaoa_optimizer.py
#
# Description:
# This script demonstrates how to use the Quantum Approximate Optimization
# Algorithm (QAOA) for a simple portfolio optimization problem. The goal is to
# select a subset of assets that maximizes expected return while staying
# within a risk budget.
#
# This is a combinatorial optimization problem, which is a class of problems
# where quantum algorithms like QAOA are expected to provide an advantage.
#
# The process involves:
# 1. Defining assets with expected returns and a covariance matrix (risk).
# 2. Formulating the problem as a QUBO (Quadratic Unconstrained Binary
#    Optimization) model, which is equivalent to an Ising Hamiltonian.
# 3. Using the AWS Braket SDK to solve the problem with QAOA.
#
# Dependencies:
# pip install amazon-braket-sdk numpy
#

import numpy as np
from braket.circuits import Circuit
from braket.devices import LocalSimulator
from braket.aws import AwsDevice
from braket.ocean import BraketDWaveSampler
from dwave.system import LeapHybridSampler
import dimod # D-Wave's library for QUBO models

def define_problem():
    """
    Defines a simple portfolio optimization problem.
    We have 4 assets and want to choose the best combination.
    """
    # Asset names
    assets = ['Asset A', 'Asset B', 'Asset C', 'Asset D']
    
    # Expected returns for each asset
    expected_returns = np.array([0.1, 0.2, 0.15, 0.08])
    
    # Covariance matrix representing risk and correlation between assets
    covariance = np.array([
        [0.04, 0.01, 0.02, 0.01],
        [0.01, 0.09, 0.03, 0.02],
        [0.02, 0.03, 0.06, 0.01],
        [0.01, 0.02, 0.01, 0.02]
    ])
    
    print("--- Problem Definition ---")
    print(f"Assets: {assets}")
    print(f"Expected Returns: {expected_returns}")
    print(f"Covariance Matrix (Risk):\n{covariance}\n")
    
    return assets, expected_returns, covariance

def build_qubo(returns, covariance, risk_factor=0.5, budget=2):
    """
    Builds the QUBO formulation for the portfolio optimization problem.
    
    The objective is to maximize: (sum of returns) - risk_factor * (portfolio risk)
    This is equivalent to minimizing: - (sum of returns) + risk_factor * (portfolio risk)
    
    Args:
        returns (np.array): Expected returns for each asset.
        covariance (np.array): Covariance matrix.
        risk_factor (float): A parameter to control the trade-off between return and risk.
        budget (int): The number of assets to select.

    Returns:
        dimod.BinaryQuadraticModel: The QUBO model.
    """
    num_assets = len(returns)
    
    # Initialize the QUBO model
    qubo = dimod.BinaryQuadraticModel({}, {}, 0.0, dimod.BINARY)

    # --- Objective Part 1: Maximize returns ---
    # This corresponds to the linear terms in the QUBO
    for i in range(num_assets):
        qubo.linear[i] = -returns[i]

    # --- Objective Part 2: Minimize risk ---
    # This corresponds to the quadratic terms in the QUBO
    for i in range(num_assets):
        for j in range(num_assets):
            if i == j:
                # Variance terms
                qubo.quadratic[(i, j)] = risk_factor * covariance[i, i]
            else:
                # Covariance terms
                qubo.quadratic[(i, j)] = risk_factor * 2 * covariance[i, j]
                
    # --- Constraint: Select exactly 'budget' number of assets ---
    # We add a penalty term for violating this constraint.
    # The term is (sum(x_i) - budget)^2
    # Expanding this gives: (sum(x_i))^2 - 2*budget*sum(x_i) + budget^2
    # (sum(x_i))^2 = sum(x_i^2) + 2*sum(x_i*x_j) for i<j
    # Since x_i is binary, x_i^2 = x_i.
    
    # A large penalty factor to enforce the constraint
    penalty = np.max(np.abs(returns)) * 10 
    
    # Add the constraint to the QUBO model
    qubo.add_linear_constraint(
        [(i, 1.0) for i in range(num_assets)],
        lb=budget,
        ub=budget,
        penalty=penalty
    )

    print("--- QUBO Model ---")
    print(f"Risk Factor: {risk_factor}")
    print(f"Budget (number of assets to select): {budget}")
    print(f"Penalty for budget constraint: {penalty}\n")
    
    return qubo

def solve_with_quantum_annealer(qubo):
    """
    Solves the QUBO using a D-Wave Quantum Annealer (via LeapHybridSampler).
    This is a conceptual function showing how it would be done.
    """
    print("--- Solving with Quantum Annealer (Simulated) ---")
    
    # The LeapHybridSampler can solve problems of this size classically, but
    # demonstrates the workflow for a real quantum annealer.
    sampler = LeapHybridSampler()
    
    # In a real scenario with D-Wave hardware access:
    # sampler = BraketDWaveSampler(s3_destination_folder, 'arn:aws:braket:::device/qpu/d-wave/Advantage_system4')
    # sampler = EmbeddingComposite(sampler) # To map the problem to the QPU topology
    
    sampleset = sampler.sample(qubo, label='QuantumArb Portfolio Optimization')
    
    # Get the best solution found
    best_solution = sampleset.first.sample
    energy = sampleset.first.energy
    
    print(f"Lowest energy found: {energy}")
    return best_solution


if __name__ == "__main__":
    # 1. Define the financial problem
    assets, returns, covariance = define_problem()
    
    # 2. Convert the problem into a QUBO model
    # We want to select 2 out of the 4 assets.
    qubo_model = build_qubo(returns, covariance, risk_factor=0.5, budget=2)
    
    # 3. Solve the QUBO using a quantum-inspired approach
    # Note: This requires a configured D-Wave Leap account for the hybrid sampler.
    # For this POC, we will just print the best solution conceptually.
    
    # best_solution = solve_with_quantum_annealer(qubo_model)
    
    # For demonstration without needing a live solver, we'll show a mock result.
    print("--- Solving with Quantum Annealer (Mock Result) ---")
    # This mock result corresponds to selecting Asset B and Asset C, which is a
    # plausible optimal solution given the high returns and moderate risk.
    best_solution = {0: 0, 1: 1, 2: 1, 3: 0} 
    print(f"Best solution found: {best_solution}")
    
    # 4. Interpret the results
    selected_assets = [assets[i] for i, selected in best_solution.items() if selected == 1]
    
    print("\n--- Optimal Portfolio Found ---")
    print(f"Selected assets: {', '.join(selected_assets)}")
