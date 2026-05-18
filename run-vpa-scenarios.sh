#!/bin/bash
# Scenariusze testowe dla VPA (Vertical Pod Autoscaler)
set -e

REPETITIONS=${1:-1}
TECHNOLOGIES=("wasm-cpp" "kotlin-wasm" "kotlin-spring-boot")

for TECH in "${TECHNOLOGIES[@]}"; do
  echo "🚀 VPA dla: $TECH (Powtórzenia: $REPETITIONS)"
  ./deploy-vpa.sh "$TECH"
  sleep 20

  # D: Soak & Adaptation (ID: 4)
  SCENARIO_ID=4
  
  ./run-tests.sh 400 15 "5m" "$SCENARIO_ID" "$REPETITIONS"
  
  echo "⏳ Przerwa na stabilizację zasobów..."
  sleep 60
  
  ./run-tests.sh 200 30 "7m" "$SCENARIO_ID" "$REPETITIONS"

  echo "⏳ Przerwa techniczna między technologiami..."
  sleep 30
done
