#
# QuantumArb 2.0 - ML Pipeline: Train Hardware-Friendly Model
#
# File: src/ml_pipeline/train_fpga_model.py
#
# Description:
# This script trains a simple, shallow decision tree model that is suitable for
# direct implementation in hardware (FPGA). The goal is to create a model with
# a structure so simple that its logic can be written in Verilog.
#
# The script will:
# 1. Generate mock market microstructure data.
# 2. Train a decision tree with a maximum depth of 2.
# 3. Export the learned decision rules (thresholds and features) to a text
#    file, which will serve as a specification for the Verilog implementation.
#
# Dependencies:
# pip install scikit-learn pandas
#

import pandas as pd
import numpy as np
from sklearn.tree import DecisionTreeClassifier, export_text
from sklearn.model_selection import train_test_split

def generate_microstructure_data(rows=5000):
    """Generates mock market microstructure feature data."""
    # Feature 1: Order book imbalance (ratio of bid volume to total volume)
    imbalance = np.random.uniform(0.2, 0.8, size=rows)
    # Feature 2: Trade intensity (number of trades in the last 100ms)
    trade_intensity = np.random.randint(0, 50, size=rows)
    
    df = pd.DataFrame({
        'book_imbalance': imbalance,
        'trade_intensity': trade_intensity
    })
    
    # Create a simple target variable based on the features
    # e.g., High imbalance and high intensity might predict an upward price move
    y = (df['book_imbalance'] > 0.6) & (df['trade_intensity'] > 25)
    df['target'] = y.astype(int)
    
    return df

def train_fpga_model(df):
    """Trains a shallow decision tree and returns the model."""
    print("--- Training Hardware-Friendly Decision Tree ---")
    
    X = df[['book_imbalance', 'trade_intensity']]
    y = df['target']
    
    # Create a decision tree classifier with a max depth of 2
    # This results in a simple tree with at most 4 leaf nodes.
    model = DecisionTreeClassifier(max_depth=2, random_state=42)
    model.fit(X, y)
    
    print("Model training complete.")
    return model

def export_model_rules(model, feature_names):
    """Exports the trained model's rules to a text file."""
    print("\n--- Exporting Model Rules for Hardware Implementation ---")
    
    rules = export_text(model, feature_names=feature_names)
    
    print("Learned Rules:")
    print(rules)
    
    # Save the rules to a file that the hardware engineer can use as a spec.
    with open("fpga_model_spec.txt", "w") as f:
        f.write("FPGA Inference Engine Specification\n")
        f.write("===================================\n\n")
        f.write("This decision tree should be implemented in Verilog.\n")
        f.write("Inputs are fixed-point numbers.\n\n")
        f.write(rules)
        
    print("\nModel specification saved to 'fpga_model_spec.txt'")


if __name__ == "__main__":
    # 1. Generate data
    data = generate_microstructure_data()
    
    # 2. Train the model
    feature_names = ['book_imbalance', 'trade_intensity']
    model = train_fpga_model(data)
    
    # 3. Export the rules
    export_model_rules(model, feature_names)

