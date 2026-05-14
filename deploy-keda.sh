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
kubectl delete scaledobject wasm-keda --ignore-not-found
kubectl delete httpscaledobject wasm-keda --ignore-not-found
kubectl delete service keda-interceptor-proxy --ignore-not-found

echo "🚀 Deploying application with KEDA (Tag: $TAG)..."

case "$TAG" in
  "kotlin-spring-boot") PORT=8080 ;;
  "kotlin-wasm")        PORT=8081 ;;
  "wasm-cpp")           PORT=8082 ;;
  *)                    PORT=8082 ;;
esac

METRICS_PATH="/metrics"
if [ "$TAG" == "kotlin-spring-boot" ]; then METRICS_PATH="/actuator/prometheus"; fi

sed "s|image: .*|image: $IMAGE|; \
     s|containerPort: .*|containerPort: $PORT|; \
     s|8082|$PORT|g; \
     s|path: \"/metrics\"|path: \"$METRICS_PATH\"|g" deployment.yml | kubectl apply -f -
sed "s|targetPort: .*|targetPort: $PORT|" service.yml | kubectl apply -f -
kubectl apply -f autoscaler/keda-ingress.yml
kubectl apply -f autoscaler/keda-scaledobject.yaml

echo "✅ Deployment complete!"
kubectl get pods -l app=wasm-app
