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

RELEASE_NAME="${APP_NAME}-${NAMESPACE}"

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
  --set service.type=ClusterIP \
  --set service.port=8000 \
  --set django.debug=true \
  --set django.allowedHosts="*" \
  --set serviceAccount.create=false \
  --set serviceAccount.name=default \
  --set serviceAccount.automount=false \
  --set ingress.enabled=false \
  --set autoscaling.enabled=false \
  --set httpRoute.enabled=false

echo "Helm template"
helm template ${RELEASE_NAME} ./helm-charts-hello-world \
  --namespace ${NAMESPACE} \
  --set image.repository=${APP_NAME} \
  --set image.tag=${IMAGE_TAG} \
  --set image.pullPolicy=IfNotPresent \
  --set service.type=ClusterIP \
  --set service.port=8000 \
  --set django.debug=true \
  --set django.allowedHosts="*" \
  --set serviceAccount.create=false \
  --set serviceAccount.name=default \
  --set serviceAccount.automount=false \
  --set ingress.enabled=false \
  --set autoscaling.enabled=false \
  --set httpRoute.enabled=false > /tmp/${APP_NAME}-${NAMESPACE}.yaml

echo "Creating namespace if not exists"
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

echo "Deleting previous release if exists"
helm uninstall ${RELEASE_NAME} -n ${NAMESPACE} || true
kubectl delete deployment django-hello-world -n ${NAMESPACE} --ignore-not-found=true
kubectl delete service django-hello-world-svc -n ${NAMESPACE} --ignore-not-found=true
kubectl delete secret sh.helm.release.v1.${RELEASE_NAME}.v1 -n ${NAMESPACE} --ignore-not-found=true
kubectl delete secret sh.helm.release.v1.${RELEASE_NAME}.v2 -n ${NAMESPACE} --ignore-not-found=true
kubectl delete secret sh.helm.release.v1.${RELEASE_NAME}.v3 -n ${NAMESPACE} --ignore-not-found=true
sleep 5

echo "Installing release"
helm install ${RELEASE_NAME} ./helm-charts-hello-world \
  --namespace ${NAMESPACE} \
  --set image.repository=${APP_NAME} \
  --set image.tag=${IMAGE_TAG} \
  --set image.pullPolicy=IfNotPresent \
  --set service.type=ClusterIP \
  --set service.port=8000 \
  --set django.debug=true \
  --set django.allowedHosts="*" \
  --set serviceAccount.create=false \
  --set serviceAccount.name=default \
  --set serviceAccount.automount=false \
  --set ingress.enabled=false \
  --set autoscaling.enabled=false \
  --set httpRoute.enabled=false

echo "Waiting for deployment"
kubectl rollout status deployment/django-hello-world -n ${NAMESPACE} --timeout=180s

echo "Restarting port-forward"
pkill -f "port-forward.*${APP_PORT}:8000" || true

nohup kubectl port-forward \
  --address 0.0.0.0 \
  -n ${NAMESPACE} \
  svc/django-hello-world-svc \
  ${APP_PORT}:8000 \
  >/tmp/${APP_NAME}-${NAMESPACE}-portforward.log 2>&1 &

sleep 8

echo "Port-forward log:"
cat /tmp/${APP_NAME}-${NAMESPACE}-portforward.log || true

echo "Deployment completed"
echo "Namespace: ${NAMESPACE}"
echo "Port: ${APP_PORT}"
