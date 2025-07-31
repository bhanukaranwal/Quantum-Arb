#
# QuantumArb 2.0 - ML Pipeline: Quantum Research Sandbox
#
# File: src/ml_pipeline/quantum_sandbox_poc.py
#
# Description:
# This script is a proof-of-concept for the quantum research sandbox. It uses the
# AWS Braket SDK to build and simulate a simple quantum circuit. The goal is to
# establish a framework for exploring quantum algorithms like QAOA (Quantum
# Approximate Optimization Algorithm) and QRL (Quantum Reinforcement Learning)
# for financial modeling.
#
# This example creates a Bell state, which is a fundamental example of quantum
# entanglement.
#
# Dependencies:
# pip install amazon-braket-sdk
#

from braket.circuits import Circuit
from braket.devices import LocalSimulator
from braket.aws import AwsDevice
import os

def create_bell_state_circuit():
    """
    Creates a quantum circuit that prepares a Bell state.
    A Bell state is a maximally entangled state of two qubits.
    Circuit:
    q0: --H--C--
           |
    q1: -----X--
    H = Hadamard gate (creates superposition)
    C-X = Controlled-NOT gate (entangles the qubits)
    """
    circuit = Circuit()
    # Apply a Hadamard gate to the first qubit to put it in superposition
    circuit.h(0)
    # Apply a CNOT gate with qubit 0 as control and qubit 1 as target
    circuit.cnot(0, 1)
    # The result is an entangled Bell pair. Measuring them will yield either
    # |00> or |11> with equal probability, but never |01> or |10>.
    return circuit

def run_on_local_simulator(circuit, shots=1000):
    """
    Executes the given quantum circuit on a local, software-based simulator.
    """
    print("--- Running on Local Simulator ---")
    device = LocalSimulator()
    print(f"Device: {device.name}")

    # Add a measurement instruction to all qubits to get classical outcomes
    circuit.probability() # This is often more efficient on simulators

    task = device.run(circuit, shots=shots)
    result = task.result()

    # Print the measurement probabilities
    print("Measurement Probabilities:")
    for state, probability in result.values[0].items():
        # Format the state to be the correct number of bits
        formatted_state = format(int(state), f'0{circuit.qubit_count}b')
        print(f"  State |{formatted_state}>: {probability * 100:.2f}%")

    return result

def run_on_aws_qpu(circuit, shots=1000):
    """
    (Conceptual) Executes the circuit on a real AWS-managed QPU.
    NOTE: This requires AWS credentials and will incur costs.
    This function is for demonstration purposes and is not run by default.
    """
    print("\n--- Running on AWS Quantum Processing Unit (QPU) ---")
    # Example using a Rigetti QPU. Other options: IonQ, Oxford Quantum Circuits
    # The device ARN can be found in the AWS Braket console.
    # device_arn = "arn:aws:braket:us-west-2::device/qpu/rigetti/Aspen-M-3"
    # device = AwsDevice(device_arn)
    print("## This is a conceptual function. ##")
    print("To run on real hardware, uncomment the lines in this function,")
    print("ensure you have valid AWS credentials, and provide a device ARN.")
    #
    # circuit.measure_all() # Real QPUs need explicit measurement gates
    # task = device.run(circuit, shots=shots)
    # result = task.result()
    # print(f"Counts for state measurements: {result.measurement_counts}")


if __name__ == "__main__":
    print("--- QuantumArb 2.0: Quantum Sandbox POC ---")

    # 1. Create the quantum circuit
    bell_circuit = create_bell_state_circuit()
    print("Constructed Bell State Circuit:")
    print(bell_circuit)
    print("\n")

    # 2. Run the simulation
    # We primarily use the local simulator for development and testing.
    simulation_result = run_on_local_simulator(bell_circuit, shots=1024)

    # 3. (Optional) Show how to run on a real QPU
    run_on_aws_qpu(bell_circuit)

