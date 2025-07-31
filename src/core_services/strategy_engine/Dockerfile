#
# QuantumArb 2.0 - Dockerfile for Strategy Engine
#
# File: src/core_services/strategy_engine/Dockerfile
#
# Description:
# This Dockerfile uses a multi-stage build to create a lightweight, optimized
# container image for the Rust-based strategy-engine service.
#

# --- Stage 1: Builder ---
# This stage uses the official Rust image to compile the application.
# It contains all the build tools and dependencies.
FROM rust:1.79-slim as builder

# Set the working directory
WORKDIR /usr/src/app

# Copy the Cargo configuration and source code
COPY ./Cargo.toml ./Cargo.lock ./
COPY ./src ./src

# Build the application in release mode. This creates a statically linked binary.
# The --release flag enables optimizations.
RUN cargo build --release

# --- Stage 2: Final Image ---
# This stage uses a minimal Debian image for a small and secure final container.
# It does not contain any build tools or source code.
FROM debian:12-slim

# Set the working directory
WORKDIR /usr/local/bin

# Copy the compiled binary from the 'builder' stage to the final image.
COPY --from=builder /usr/src/app/target/release/strategy-engine .

# Set the command to run when the container starts.
CMD ["./strategy-engine"]
