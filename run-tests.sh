#!/bin/bash

# Zatrzymanie przy błędzie
set -e

# Parametry testu
MATRIX_SIZE=${1:-100}
VUS=${2:-10}
DURATION=${3:-'1m'}
SCENARIO_ID=${4:-0}

# --- AUTO-DETEKCJA ŚRODOWISKA ---
echo "🔍 Wykrywanie konfiguracji środowiska..."

# 1. Wykrywanie technologii (na podstawie tagu obrazu w deployment)
IMAGE_TAG=$(kubectl get deployment wasm-app -o jsonpath='{.spec.template.spec.containers[0].image}' | awk -F: '{print $2}')

case "$IMAGE_TAG" in
  "kotlin-spring-boot") APP_TYPE="Kotlin Spring Boot" ;;
  "kotlin-wasm")        APP_TYPE="Kotlin WASM WASI" ;;
  "wasm-cpp")           APP_TYPE="C++" ;;
  *)                    APP_TYPE="Unknown ($IMAGE_TAG)" ;;
esac

# 2. Wykrywanie typu skalowania
if kubectl get hpa wasm-hpa >/dev/null 2>&1; then
  SCALING_TYPE="hpa"
elif kubectl get vpa wasm-vpa >/dev/null 2>&1; then
  SCALING_TYPE="vpa"
elif kubectl get scaledobject wasm-keda >/dev/null 2>&1; then
  SCALING_TYPE="keda"
else
  SCALING_TYPE="serverless"
fi

echo "✅ Wykryto: Technologia=$APP_TYPE, Skalowanie=$SCALING_TYPE"

# --- MONITORING TUNNEL ---
echo "🔌 Otwieranie tunelu do Prometheusa..."
# Bardziej odporny sposób na znalezienie serwisu Prometheusa
PROM_SVC=$(kubectl get svc -n monitoring --no-headers | grep "\-prometheus-prometheus" | awk '{print $1}' | head -n 1)

if [ -z "$PROM_SVC" ]; then
    echo "❌ Nie znaleziono serwisu Prometheusa w namespace 'monitoring'!"
    exit 1
fi

kubectl port-forward -n monitoring svc/$PROM_SVC 9090:9090 &
PF_PID=$!

# Funkcja czyszcząca
cleanup() {
    echo "🧹 Zamykanie tunelu Prometheusa..."
    kill $PF_PID || true
}
trap cleanup EXIT

# Czekanie na dostępność portu
echo "⏳ Oczekiwanie na gotowość Prometheusa..."
for i in {1..30}; do
    if curl -s http://localhost:9090/-/healthy > /dev/null; then
        echo "✅ Prometheus gotowy!"
        break
    fi
    sleep 1
done

# --- RESTART DLA ZIMNEGO STARTU ---
echo "♻️ Restartowanie podów dla czystego pomiaru (Cold Start)..."
kubectl rollout restart deployment wasm-app
kubectl rollout status deployment wasm-app --timeout=90s

# --- URUCHAMIANIE TESTU ---
echo "🚀 Uruchamianie testu k6 (MatrixSize: $MATRIX_SIZE, VUs: $VUS, Duration: $DURATION, ScenarioID: $SCENARIO_ID)..."
VUS=$VUS \
DURATION=$DURATION \
MATRIX_SIZE=$MATRIX_SIZE \
APP_TYPE="$APP_TYPE" \
SCALING_TYPE="$SCALING_TYPE" \
SCENARIO_ID="$SCENARIO_ID" \
k6 run tests/k6/matrix-test-kubernetes.js
