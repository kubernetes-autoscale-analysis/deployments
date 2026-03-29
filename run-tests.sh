#!/bin/bash

# Zatrzymanie przy błędzie
set -e

# Parametry testu
MATRIX_SIZE=${1:-100}
VUS=${2:-10}
DURATION=${3:-'1m'}

# Konfiguracja InfluxDB (zgodna z v1)
INFLUX_URL="http://localhost:8086"
DB_NAME="k6"

echo "🔌 Otwieranie tunelu do InfluxDB..."
kubectl port-forward -n monitoring svc/influxdb 8086:8086 &
PF_PID=$!

# Funkcja czyszcząca
cleanup() {
    echo "🧹 Zamykanie tunelu InfluxDB..."
    kill $PF_PID || true
}
trap cleanup EXIT

# Czekanie na dostępność portu
echo "⏳ Oczekiwanie na gotowość InfluxDB..."
for i in {1..30}; do
    if curl -s $INFLUX_URL/ping > /dev/null; then
        echo "✅ InfluxDB gotowy!"
        break
    fi
    sleep 1
done

echo "📦 Tworzenie bazy danych $DB_NAME..."
curl -G "$INFLUX_URL/query" --data-urlencode "q=CREATE DATABASE $DB_NAME"

echo "🚀 Uruchamianie testu k6 (MatrixSize: $MATRIX_SIZE, VUs: $VUS, Duration: $DURATION)..."
VUS=$VUS \
DURATION=$DURATION \
MATRIX_SIZE=$MATRIX_SIZE \
k6 run \
    --out influxdb=http://localhost:8086/$DB_NAME \
    tests/k6/matrix-test.js
