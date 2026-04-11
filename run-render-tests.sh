#!/bin/bash

set -e

# Parametry testu
MATRIX_SIZE=${1:-100}
VUS=${2:-10}
DURATION=${3:-'1m'}

echo "🚀 Rozpoczynanie testów na platformie Render.com..."
echo "📊 Konfiguracja: MatrixSize=$MATRIX_SIZE, VUs=$VUS, Duration=$DURATION"

# Lista endpointów do przetestowania
declare -A APPS
APPS["Kotlin WASM WASI"]="https://web-matrix-calculation-kotlin-wasm.onrender.com"
APPS["C++"]="https://web-matrix-calculation-wasm-cpp.onrender.com"
APPS["Kotlin Spring Boot"]="https://web-matrix-calculation-kotlin-spring-boot.onrender.com"

for APP_TYPE in "${!APPS[@]}"; do
    BASE_URL="${APPS[$APP_TYPE]}"
    
    echo ""
    echo "------------------------------------------------------------"
    echo "🏃 Testowanie: $APP_TYPE"
    echo "🔗 URL: $BASE_URL"
    echo "------------------------------------------------------------"

    BASE_URL=$BASE_URL \
    APP_TYPE="$APP_TYPE" \
    MATRIX_SIZE=$MATRIX_SIZE \
    VUS=$VUS \
    DURATION=$DURATION \
    k6 run tests/k6/matrix-test-serverless.js

    echo "✅ Zakończono test dla $APP_TYPE"
done

echo ""
echo "🎉 Wszystkie testy na Render.com zostały zakończone!"
