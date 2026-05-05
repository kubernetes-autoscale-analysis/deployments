#!/bin/bash
# Scenariusze testowe dla KEDA
set -e

TECHNOLOGIES=("wasm-cpp" "kotlin-wasm" "kotlin-spring-boot")

for TECH in "${TECHNOLOGIES[@]}"; do
  echo "🚀 KEDA dla: $TECH"
  ./deploy-keda.sh "$TECH"
  sleep 30

  # B: Scalability (ID: 2)
  SCENARIO_ID=2
  ./run-tests.sh 200 50 "5m"
  
  # C: Spike (ID: 3)
  SCENARIO_ID=3
  ./run-tests.sh 200 150 "3m"
done
