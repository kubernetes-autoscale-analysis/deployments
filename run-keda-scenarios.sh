#!/bin/bash
# Scenariusze testowe dla KEDA
set -e

REPETITIONS=${1:-1}
TECHNOLOGIES=("wasm-cpp" "kotlin-wasm" "kotlin-spring-boot")

for TECH in "${TECHNOLOGIES[@]}"; do
  echo "🚀 KEDA dla: $TECH (Powtórzenia: $REPETITIONS)"
  ./deploy-keda.sh "$TECH"
  sleep 30

  # B: Scalability (ID: 2)
  SCENARIO_ID=2
  ./run-tests.sh 200 50 "5m" "$SCENARIO_ID" "$REPETITIONS"
  
  echo "⏳ Oczekiwanie na pełne wyczyszczenie środowiska przed kolejnym scenariuszem..."
  sleep 60

  # C: Spike (ID: 3)
  SCENARIO_ID=3
  ./run-tests.sh 200 150 "3m" "$SCENARIO_ID" "$REPETITIONS"
  
  echo "⏳ Przerwa techniczna między technologiami..."
  sleep 30
done
