#!/bin/bash
TAG=$1
if [ -z "$TAG" ]; then
  echo "Usage: $0 <tag> (kotlin-spring-boot | kotlin-wasm | wasm-cpp)"
  exit 1
fi

IMAGE="michaelwieczorek/web-matrix-calculation:$TAG"

echo "🧹 Cleaning up existing autoscalers..."
kubectl delete hpa wasm-hpa --ignore-not-found
kubectl delete scaledobject wasm-keda --ignore-not-found

echo "🚀 Deploying application with VPA (Tag: $TAG)..."
# Dynamiczne obniżenie zasobów tylko dla VPA, aby wymusić jego działanie
sed "s|image: .*|image: $IMAGE|" deployment.yml | \
sed '/resources:/,/limits:/ s/cpu: ".*"/cpu: "20m"/' | \
sed '/resources:/,/limits:/ s/memory: ".*"/memory: "32Mi"/' | \
sed '/limits:/,/data:/ s/cpu: ".*"/cpu: "200m"/' | \
sed '/limits:/,/data:/ s/memory: ".*"/memory: "128Mi"/' | \
kubectl apply -f -
kubectl apply -f service.yml
kubectl apply -f ingress.yml
kubectl apply -f autoscaler/vpa.yml

echo "✅ Deployment complete!"
kubectl get pods -l app=wasm-app
