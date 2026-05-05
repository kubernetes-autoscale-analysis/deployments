#!/bin/bash
# Scenariusze testowe dla VPA (Vertical Pod Autoscaler)
set -e

TECHNOLOGIES=("wasm-cpp" "kotlin-wasm" "kotlin-spring-boot")

for TECH in "${TECHNOLOGIES[@]}"; do
  echo "🚀 VPA dla: $TECH"
  ./deploy-vpa.sh "$TECH"
  sleep 20

  # D: Soak & Adaptation (ID: 4)
  SCENARIO_ID=4
  ./run-tests.sh 400 15 "15m"
  ./run-tests.sh 200 30 "20m"
done
