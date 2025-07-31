#
# QuantumArb 2.0 - ML Pipeline: Model Training
#
# File: src/ml_pipeline/train_model.py
#
# Description:
# This script demonstrates the model training phase of the ML pipeline. It uses
# historical price data and engineered features (like those from the
# alt_data_processor) to train a predictive model.
#
# We use XGBoost, a powerful gradient boosting library popular in finance for its
# performance and accuracy. The goal is to predict a simple binary outcome: will
# the price go up in the next time period?
#
# Dependencies:
# pip install pandas scikit-learn xgboost
#

import pandas as pd
import numpy as np
import xgboost as xgb
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score, classification_report

def generate_mock_data(rows=1000):
    """Generates a mock DataFrame of historical data and features."""
    dates = pd.to_datetime(pd.date_range(start='2025-01-01', periods=rows, freq='min'))
    price = 100 + np.random.randn(rows).cumsum()
    
    # Simulate features from alt_data_processor
    sentiment = np.random.uniform(-1, 1, size=rows)
    # Simulate some technical indicators
    short_mavg = pd.Series(price).rolling(window=5).mean().fillna(method='bfill')
    long_mavg = pd.Series(price).rolling(window=20).mean().fillna(method='bfill')
    
    df = pd.DataFrame({
        'timestamp': dates,
        'close': price,
        'news_sentiment': sentiment,
        'short_mavg': short_mavg,
        'long_mavg': long_mavg
    })
    return df

def create_features_and_target(df):
    """
    Engineers features and creates the target variable for prediction.
    """
    # Features (X): What we use to predict.
    df['mavg_spread'] = df['short_mavg'] - df['long_mavg']
    features = df[['news_sentiment', 'mavg_spread']]
    
    # Target (y): What we want to predict.
    # 1 if the price goes up in the next minute, 0 otherwise.
    df['target'] = (df['close'].shift(-1) > df['close']).astype(int)
    
    # Drop rows with NaN values created by shifting
    df = df.dropna()
    
    X = df[['news_sentiment', 'mavg_spread']]
    y = df['target']
    
    return X, y

def train_xgboost_model(X_train, y_train):
    """Trains an XGBoost classifier."""
    print("--- Training XGBoost Model ---")
    model = xgb.XGBClassifier(
        objective='binary:logistic',
        eval_metric='logloss',
        use_label_encoder=False,
        n_estimators=100,
        learning_rate=0.1,
        max_depth=3
    )
    model.fit(X_train, y_train)
    print("Model training complete.")
    return model

if __name__ == "__main__":
    # 1. Generate and prepare data
    data = generate_mock_data()
    X, y = create_features_and_target(data)
    
    # 2. Split data into training and testing sets
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, shuffle=False
    )
    print(f"Training data shape: {X_train.shape}")
    print(f"Testing data shape: {X_test.shape}")
    
    # 3. Train the model
    model = train_xgboost_model(X_train, y_train)
    
    # 4. Evaluate the model on the test set
    print("\n--- Evaluating Model Performance ---")
    y_pred = model.predict(X_test)
    accuracy = accuracy_score(y_test, y_pred)
    print(f"Model Accuracy: {accuracy * 100:.2f}%")
    print("Classification Report:")
    print(classification_report(y_test, y_pred))
    
    # 5. Save the trained model for inference
    # In a real system, this would be saved to S3 and registered in a model registry.
    model_filename = 'xgb_price_predictor.json'
    model.save_model(model_filename)
    print(f"\nModel saved to '{model_filename}'")

