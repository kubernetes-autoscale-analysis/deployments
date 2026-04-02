#!/bin/bash
TAG=$1
if [ -z "$TAG" ]; then
  echo "Usage: $0 <tag> (kotlin-spring-boot | kotlin-wasm | wasm-cpp)"
  exit 1
fi

IMAGE="michaelwieczorek/web-matrix-calculation:$TAG"

echo "🧹 Cleaning up existing autoscalers..."
kubectl delete hpa wasm-hpa --ignore-not-found
kubectl delete vpa wasm-vpa --ignore-not-found

echo "🚀 Deploying application with KEDA (Tag: $TAG)..."
sed "s|image: .*|image: $IMAGE|" deployment.yml | kubectl apply -f -
kubectl apply -f service.yml
kubectl apply -f ingress.yml
kubectl apply -f autoscaler/keda-scaledobject.yaml

echo "✅ Deployment complete!"
kubectl get pods -l app=wasm-app
