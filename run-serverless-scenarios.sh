#!/bin/bash
# Scenariusze testowe dla Serverless (Google Cloud Run)
set -e

URL_CPP=${1:-"https://your-cpp-app.a.run.app"}
URL_KOTLIN_WASM=${2:-"https://your-kotlin-wasm-app.a.run.app"}
URL_KOTLIN_JVM=${3:-"https://your-kotlin-jvm-app.a.run.app"}
REPETITIONS=${4:-1}

run_cloud_test() {
  local url=$1
  local app_type=$2
  
  for i in $(seq 1 $REPETITIONS); do
    echo "🔄 Powtórzenie $i z $REPETITIONS dla $app_type"

    # A: Baseline (ID: 1)
    SCENARIO_ID=1 SCALING_TYPE="serverless" BASE_URL=$url APP_TYPE="$app_type" MATRIX_SIZE=200 VUS=10 DURATION="2m" \
      k6 run tests/k6/matrix-test-serverless.js

    # C: Spike (ID: 3)
    SCENARIO_ID=3 SCALING_TYPE="serverless" BASE_URL=$url APP_TYPE="$app_type" MATRIX_SIZE=200 VUS=100 DURATION="5m" \
      k6 run tests/k6/matrix-test-serverless.js
      
    if [ $i -lt $REPETITIONS ]; then
      echo "⏳ Przerwa między powtórzeniami cloud..."
      sleep 30
    fi
  done
}

run_cloud_test "$URL_CPP" "C++"
run_cloud_test "$URL_KOTLIN_WASM" "Kotlin WASM WASI"
run_cloud_test "$URL_KOTLIN_JVM" "Kotlin Spring Boot"
