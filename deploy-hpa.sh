#!/bin/bash
TAG=$1
if [ -z "$TAG" ]; then
  echo "Usage: $0 <tag> (kotlin-spring-boot | kotlin-wasm | wasm-cpp)"
  exit 1
fi

IMAGE="michaelwieczorek/web-matrix-calculation:$TAG"

echo "🧹 Cleaning up existing autoscalers..."
kubectl delete vpa wasm-vpa --ignore-not-found
kubectl delete scaledobject wasm-keda --ignore-not-found

echo "🚀 Deploying application with HPA (Tag: $TAG)..."
sed "s|image: .*|image: $IMAGE|" deployment.yml | kubectl apply -f -
kubectl apply -f service.yml
kubectl apply -f ingress.yml
kubectl apply -f autoscaler/hpa.yml

echo "✅ Deployment complete!"
kubectl get pods -l app=wasm-app
