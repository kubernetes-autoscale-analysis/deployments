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
kubectl delete httpscaledobject wasm-keda --ignore-not-found
kubectl delete service keda-interceptor-proxy --ignore-not-found

echo "🚀 Deploying application with HPA (Tag: $TAG)..."

case "$TAG" in
  "kotlin-spring-boot") PORT=8080 ;;
  "kotlin-wasm")        PORT=8081 ;;
  "wasm-cpp")           PORT=8082 ;;
  *)                    PORT=8082 ;;
esac

METRICS_PATH="/metrics"
if [ "$TAG" == "kotlin-spring-boot" ]; then METRICS_PATH="/actuator/prometheus"; fi

# DYNAMICZNA KONFIGURACJA ZASOBÓW POD HPA
# Requests: 10m CPU / 32Mi RAM (wyjątek: 300m/256Mi dla Spring Boot)
# Limits: 800m CPU / 512Mi RAM
CPU_REQUEST="10m"
MEM_REQUEST="32Mi"
if [ "$TAG" == "kotlin-spring-boot" ]; then 
  CPU_REQUEST="300m"
  MEM_REQUEST="256Mi"
fi

sed "s|image: .*|image: $IMAGE|; \
     s|containerPort: .*|containerPort: $PORT|; \
     s|8082|$PORT|g; \
     s|path: \"/metrics\"|path: \"$METRICS_PATH\"|g" deployment.yml | \
sed "/requests:/,/limits:/ s/cpu: \".*\"/cpu: \"$CPU_REQUEST\"/" | \
sed "/requests:/,/limits:/ s/memory: \".*\"/memory: \"$MEM_REQUEST\"/" | \
sed '/limits:/,/^[[:space:]]*$/ s/cpu: ".*"/cpu: "800m"/' | \
sed '/limits:/,/^[[:space:]]*$/ s/memory: ".*"/memory: "512Mi"/' | \
kubectl apply -f -
sed "s|targetPort: .*|targetPort: $PORT|" service.yml | kubectl apply -f -
kubectl apply -f ingress.yml
kubectl apply -f autoscaler/hpa.yml

echo "✅ Deployment complete!"
kubectl get pods -l app=wasm-app
