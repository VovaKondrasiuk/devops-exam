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

eval $(minikube docker-env)

echo "Pre-deployment checks"
docker build -t ${APP_NAME}:${IMAGE_TAG} .
helm lint ./helm-charts-hello-world
helm template ${APP_NAME}-${NAMESPACE} ./helm-charts-hello-world \
  --namespace ${NAMESPACE} \
  --set image.repository=${APP_NAME} \
  --set image.tag=${IMAGE_TAG} \
  --set service.port=8000 > /tmp/${APP_NAME}-${NAMESPACE}.yaml

kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install ${APP_NAME}-${NAMESPACE} ./helm-charts-hello-world \
  --namespace ${NAMESPACE} \
  --set image.repository=${APP_NAME} \
  --set image.tag=${IMAGE_TAG} \
  --set service.port=8000

kubectl rollout restart deployment/${APP_NAME}-${NAMESPACE}-helm-charts-hello-world -n ${NAMESPACE} || true
kubectl rollout status deployment/${APP_NAME}-${NAMESPACE}-helm-charts-hello-world -n ${NAMESPACE} --timeout=180s

pkill -f "port-forward.*${NAMESPACE}.*${APP_PORT}:8000" || true
nohup kubectl port-forward -n ${NAMESPACE} svc/${APP_NAME}-${NAMESPACE}-helm-charts-hello-world 0.0.0.0:${APP_PORT}:8000 > /tmp/${APP_NAME}-${NAMESPACE}-portforward.log 2>&1 &
sleep 5

echo "Deployment completed"
