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

echo "🌐 Instalacja KEDA HTTP Add-on..."
helm repo add kedacore https://kedacore.github.io/charts || true
helm repo update kedacore || true
helm upgrade --install http-add-on kedacore/keda-add-ons-http --namespace keda

echo "📉 Instalacja VPA (Vertical Pod Autoscaler)..."
if kubectl get pods -n kube-system | grep -q "vpa-recommender"; then
  echo "✅ VPA jest już zainstalowane."
else
  echo "📥 Pobieranie i instalacja VPA..."
  TEMP_VPA_DIR=$(mktemp -d)
  git clone https://github.com/kubernetes/autoscaler.git "$TEMP_VPA_DIR"
  cd "$TEMP_VPA_DIR/vertical-pod-autoscaler"
  ./hack/vpa-up.sh
  cd -
  rm -rf "$TEMP_VPA_DIR"
fi

echo "🔍 Instalacja Monitoring Stack (Prometheus + Grafana)..."
kubectl create namespace monitoring || true
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts || true
# Ciche repo update, aby nie blokować przy problemach sieciowych
helm repo update prometheus-community || true

# Instalacja Prometheus Stack (Prometheus + Grafana)
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack -n monitoring

echo "✅ Infrastruktura podstawowa gotowa!"
echo "Oczekiwanie na gotowość Ingress..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s || echo "⚠️ Ingress nie jest jeszcze gotowy, ale instalacja trwa dalej..."

echo "🚀 Środowisko jest gotowe do testów!"
