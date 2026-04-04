#!/bin/bash
set -e

APP_NAME=$1
NAMESPACE=$2
IMAGE_TAG=$3
APP_PORT=$4
REPO_DIR=$5

if [ -z "$APP_NAME" ] || [ -z "$NAMESPACE" ] || [ -z "$IMAGE_TAG" ] || [ -z "$APP_PORT" ] || [ -z "$REPO_DIR" ]; then
  echo "Usage: ./deploy.sh <app_name> <namespace> <image_tag> <app_port> <repo_dir>"
  exit 1
fi

cd "$REPO_DIR"

echo "Using minikube docker environment"
eval "$(minikube docker-env)"

echo "Pre-deployment checks"
docker build -t ${APP_NAME}:${IMAGE_TAG} .

echo "Helm lint"
helm lint ./helm-charts-hello-world \
  --set image.repository=${APP_NAME} \
  --set image.tag=${IMAGE_TAG} \
  --set image.pullPolicy=IfNotPresent \
  --set image.pullSecret="" \
  --set service.type=ClusterIP \
  --set service.port=8000 \
  --set django.debug=True \
  --set django.allowedHosts="*" \
  --set serviceAccount.create=false \
  --set serviceAccount.name=default \
  --set serviceAccount.automount=false \
  --set ingress.enabled=false \
  --set autoscaling.enabled=false

echo "Helm template"
helm template ${APP_NAME}-${NAMESPACE} ./helm-charts-hello-world \
  --namespace ${NAMESPACE} \
  --set image.repository=${APP_NAME} \
  --set image.tag=${IMAGE_TAG} \
  --set image.pullPolicy=IfNotPresent \
  --set image.pullSecret="" \
  --set service.type=ClusterIP \
  --set service.port=8000 \
  --set django.debug=True \
  --set django.allowedHosts="*" \
  --set serviceAccount.create=false \
  --set serviceAccount.name=default \
  --set serviceAccount.automount=false \
  --set ingress.enabled=false \
  --set autoscaling.enabled=false > /tmp/${APP_NAME}-${NAMESPACE}.yaml

echo "Creating namespace if not exists"
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

echo "Deploying with Helm"
helm upgrade --install ${APP_NAME}-${NAMESPACE} ./helm-charts-hello-world \
  --namespace ${NAMESPACE} \
  --set image.repository=${APP_NAME} \
  --set image.tag=${IMAGE_TAG} \
  --set image.pullPolicy=IfNotPresent \
  --set image.pullSecret="" \
  --set service.type=ClusterIP \
  --set service.port=8000 \
  --set django.debug=True \
  --set django.allowedHosts="*" \
  --set serviceAccount.create=false \
  --set serviceAccount.name=default \
  --set serviceAccount.automount=false \
  --set ingress.enabled=false \
  --set autoscaling.enabled=false

echo "Waiting for deployment"
kubectl rollout status deployment/django-hello-world -n ${NAMESPACE} --timeout=180s

echo "Restarting port-forward"
pkill -f "port-forward.*${APP_PORT}:8000" || true
nohup kubectl port-forward -n ${NAMESPACE} svc/django-hello-world-svc 0.0.0.0:${APP_PORT}:8000 >/tmp/${APP_NAME}-${NAMESPACE}-portforward.log 2>&1 &
sleep 5

echo "Deployment completed"
echo "Namespace: ${NAMESPACE}"
echo "Port: ${APP_PORT}"
