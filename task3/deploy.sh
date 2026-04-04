#!/bin/bash
set -e

APP_NAME=$1
NAMESPACE=$2
IMAGE_TAG=$3
APP_PORT=$4
REPO_DIR=$5

# === CONFIG ===
DOCKER_USERNAME=${DOCKER_USERNAME}
DOCKER_PASSWORD=${DOCKER_PASSWORD}
IMAGE_NAME="${DOCKER_USERNAME}/${APP_NAME}:${IMAGE_TAG}"
RELEASE_NAME="${APP_NAME}-${NAMESPACE}"

if [ -z "$APP_NAME" ] || [ -z "$NAMESPACE" ] || [ -z "$IMAGE_TAG" ] || [ -z "$APP_PORT" ] || [ -z "$REPO_DIR" ]; then
  echo "Usage: ./deploy.sh <app_name> <namespace> <image_tag> <app_port> <repo_dir>"
  exit 1
fi

cd "$REPO_DIR"

echo "=== Docker build ==="
docker build -t ${APP_NAME}:${IMAGE_TAG} .

echo "=== Docker login ==="
echo "${DOCKER_PASSWORD}" | docker login -u "${DOCKER_USERNAME}" --password-stdin

echo "=== Tag image ==="
docker tag ${APP_NAME}:${IMAGE_TAG} ${IMAGE_NAME}

echo "=== Push image to Docker Hub ==="
docker push ${IMAGE_NAME}

echo "=== Switch to Minikube docker ==="
eval "$(minikube docker-env)"

echo "=== Helm lint ==="
helm lint ./helm-charts-hello-world \
  --set image.repository=${DOCKER_USERNAME}/${APP_NAME} \
  --set image.tag=${IMAGE_TAG} \
  --set image.pullPolicy=Always \
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

echo "=== Create namespace ==="
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

echo "=== Delete old release ==="
helm uninstall ${RELEASE_NAME} -n ${NAMESPACE} || true
sleep 5

echo "=== Deploy with Helm ==="
helm install ${RELEASE_NAME} ./helm-charts-hello-world \
  --namespace ${NAMESPACE} \
  --set image.repository=${DOCKER_USERNAME}/${APP_NAME} \
  --set image.tag=${IMAGE_TAG} \
  --set image.pullPolicy=Always \
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

echo "=== Wait for deployment ==="
kubectl rollout status deployment/django-hello-world -n ${NAMESPACE} --timeout=180s

echo "=== Restart port-forward ==="
pkill -f "port-forward.*${APP_PORT}:8000" || true

nohup kubectl port-forward \
  --address 0.0.0.0 \
  -n ${NAMESPACE} \
  svc/django-hello-world-svc \
  ${APP_PORT}:8000 \
  >/tmp/${APP_NAME}-${NAMESPACE}-portforward.log 2>&1 &

sleep 8

echo "=== Port-forward log ==="
cat /tmp/${APP_NAME}-${NAMESPACE}-portforward.log || true

echo "=== DONE ==="
echo "Namespace: ${NAMESPACE}"
echo "Image: ${IMAGE_NAME}"
echo "Port: ${APP_PORT}"
