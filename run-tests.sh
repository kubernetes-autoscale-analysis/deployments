#!/bin/bash

# Zatrzymanie przy błędzie
set -e

# Parametry testu
MATRIX_SIZE=${1:-100}
VUS=${2:-10}
DURATION=${3:-'1m'}
SCENARIO_ID=${4:-0}
REPETITIONS=${5:-1}

for i in $(seq 1 $REPETITIONS); do
  echo "🔄 Powtórzenie $i z $REPETITIONS"

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
  elif kubectl get httpscaledobjects.http.keda.sh wasm-keda >/dev/null 2>&1; then
    SCALING_TYPE="keda"
  else
    SCALING_TYPE="serverless"
  fi

  echo "✅ Wykryto: Technologia=$APP_TYPE, Skalowanie=$SCALING_TYPE"

  # --- HOST DLA KEDA HTTP ---
  if [ "$SCALING_TYPE" == "keda" ]; then
    HTTP_HOST="wasm.local"
  else
    HTTP_HOST=""
  fi

  # --- MONITORING TUNNEL ---
  echo "🔌 Otwieranie tunelu do Prometheusa..."
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
  for j in {1..30}; do
      if curl -s http://localhost:9090/-/healthy > /dev/null; then
          echo "✅ Prometheus gotowy!"
          break
      fi
      sleep 1
  done

  # --- RESTART DLA ZIMNEGO STARTU ---
  echo "♻️ Przygotowanie czystego środowiska (Cold Start)..."
  # Zapamiętujemy docelową liczbę replik
  TARGET_REPLICAS=$(kubectl get deployment wasm-app -o jsonpath='{.spec.replicas}')
  [ -z "$TARGET_REPLICAS" ] || [ "$TARGET_REPLICAS" -eq 0 ] && TARGET_REPLICAS=2

  echo "⏬ Skalowanie do zera..."
  kubectl scale deployment wasm-app --replicas=0
  kubectl wait --for=delete pod -l app=wasm-app --timeout=60s || true

  if [ "$SCALING_TYPE" == "keda" ]; then
    sleep 10 # Bufor dla KEDA Interceptor
  fi

  echo "⏫ Skalowanie do $TARGET_REPLICAS i start pomiaru..."
  kubectl scale deployment wasm-app --replicas=$TARGET_REPLICAS

  # --- URUCHAMIANIE TESTU ---
  echo "🚀 [POWTÓRZENIE $i] Uruchamianie testu k6 (MatrixSize: $MATRIX_SIZE, VUs: $VUS, Duration: $DURATION, ScenarioID: $SCENARIO_ID)..."
  k6 run \
    -e VUS=$VUS \
    -e DURATION=$DURATION \
    -e MATRIX_SIZE=$MATRIX_SIZE \
    -e APP_TYPE="$APP_TYPE" \
    -e SCALING_TYPE="$SCALING_TYPE" \
    -e SCENARIO_ID="$SCENARIO_ID" \
    -e HTTP_HOST="$HTTP_HOST" \
    tests/k6/matrix-test-kubernetes.js

  cleanup
  trap - EXIT
  
  if [ $i -lt $REPETITIONS ]; then
    echo "⏳ Przerwa przed kolejnym powtórzeniem..."
    sleep 20
  fi
done
