#!/bin/bash
# Scenariusze testowe dla HPA (Horizontal Pod Autoscaler)
set -e

REPETITIONS=${1:-1}
TECHNOLOGIES=("wasm-cpp" "kotlin-wasm" "kotlin-spring-boot")

for TECH in "${TECHNOLOGIES[@]}"; do
  echo "🚀 HPA dla: $TECH (Powtórzenia: $REPETITIONS)"
  ./deploy-hpa.sh "$TECH"
  sleep 30

  # A: Baseline (ID: 1)
  SCENARIO_ID=1
  for SIZE in 100 200 500; do
    ./run-tests.sh "$SIZE" 10 "2m" "$SCENARIO_ID" "$REPETITIONS"
    sleep 30
  done

  echo "⏳ Oczekiwanie na schłodzenie środowiska przed kolejnym scenariuszem..."
  sleep 60

  # B: Ramp-up (ID: 2)
  SCENARIO_ID=2
  ./run-tests.sh 200 100 "5m" "$SCENARIO_ID" "$REPETITIONS"

  echo "⏳ Oczekiwanie na schłodzenie środowiska przed kolejnym scenariuszem..."
  sleep 60

  # C: Spike (ID: 3)
  SCENARIO_ID=3
  ./run-tests.sh 200 200 "2m" "$SCENARIO_ID" "$REPETITIONS"

  echo "⏳ Przerwa techniczna między technologiami..."
  sleep 30
done
