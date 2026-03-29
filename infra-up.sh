#!/bin/bash

# Zatrzymanie przy błędzie
set -e

CLUSTER_NAME="magisterka-cluster"

echo "🚀 Tworzenie klastra Kind: $CLUSTER_NAME..."
if kind get clusters | grep -q "^$CLUSTER_NAME$"; then
  echo "✅ Klaster $CLUSTER_NAME już istnieje."
else
  kind create cluster --name "$CLUSTER_NAME" --config kind-config.yaml
fi

echo "🌐 Instalacja Ingress NGINX..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

echo "📊 Instalacja Metrics Server..."
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl patch deployment metrics-server -n kube-system --type='json' -p '[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'

echo "📈 Instalacja KEDA..."
kubectl apply --server-side --force-conflicts -f https://github.com/kedacore/keda/releases/download/v2.19.0/keda-2.19.0.yaml

echo "📉 Instalacja VPA (Vertical Pod Autoscaler)..."
if [ ! -d "vpa-git" ]; then
  git clone https://github.com/kubernetes/autoscaler.git vpa-git
fi
cd vpa-git/vertical-pod-autoscaler
./hack/vpa-up.sh
cd ../..

echo "🔍 Instalacja Monitoring Stack (Prometheus + InfluxDB)..."
kubectl create namespace monitoring || true
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts || true
helm repo add influxdata https://helm.influxdata.com/ || true
helm repo update

# Instalacja Prometheus Stack (Prometheus + Grafana)
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack -n monitoring

# Instalacja InfluxDB v1 (lepsza kompatybilność z k6)
helm upgrade --install influxdb influxdata/influxdb -n monitoring \
  --set auth.enabled=false,persistence.enabled=false

echo "✅ Infrastruktura podstawowa gotowa!"
echo "Oczekiwanie na gotowość Ingress..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s

echo "🚀 Środowisko jest gotowe do testów!"
