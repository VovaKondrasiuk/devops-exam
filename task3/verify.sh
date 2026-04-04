#!/bin/bash
set -e

NAMESPACE=$1
APP_PORT=$2

if [ -z "$NAMESPACE" ] || [ -z "$APP_PORT" ]; then
  echo "Usage: ./verify.sh <namespace> <app_port>"
  exit 1
fi

echo "Checking pods in namespace ${NAMESPACE}"
kubectl get pods -n ${NAMESPACE}

echo "Checking service in namespace ${NAMESPACE}"
kubectl get svc -n ${NAMESPACE}

echo "Checking HTTP response on port ${APP_PORT}"
for i in 1 2 3 4 5; do
  if curl -I http://127.0.0.1:${APP_PORT}; then
    curl http://127.0.0.1:${APP_PORT}
    exit 0
  fi
  echo "Retry $i..."
  sleep 3
done

echo "Port-forward log:"
cat /tmp/hello-world-${NAMESPACE}-portforward.log || true

exit 1
