#!/bin/bash

set -eou pipefail

# Load utils
source common.sh

# Check if bootstrap cluster has been created yet
echo "Checking for existence of ${BOOTSTRAP_CLUSTER} cluster..."
if ! k3d cluster list "${BOOTSTRAP_CLUSTER}" >/dev/null 2>&1; then
  echo "Error cluster ${BOOTSTRAP_CLUSTER} doesn't exist!!!"
  exit
fi

echo "[${CLUSTER_NAME}] Retrieving context from cluster..."
az aks get-credentials --resource-group "${CLUSTER_RESOURCE_GROUP}" --name "${CLUSTER_NAME}" --file .kubeconfig

echo "[${CLUSTER_NAME}] Creating platform-management-system namespace..."
cat <<EOF | kubectl --context "${CLUSTER_NAME}" apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: platform-management-system
  labels:
    namespace.ssc-spc.gc.ca/purpose: platform
EOF

api_server=$(kubectl --context "${CLUSTER_NAME}" config view -o jsonpath="{.clusters[?(@.name == '${CLUSTER_NAME}')].cluster.server}")
token=$(kubectl --context "${CLUSTER_NAME}" get secret -n platform-system "argocd-mgmt-token" -o jsonpath='{.data.token}' | base64 --decode)
ca=$(kubectl --context "${CLUSTER_NAME}" get secret -n platform-system "argocd-mgmt-token" -o jsonpath='{.data.ca\.crt}')

cat <<EOF | do_kubectl "${BOOTSTRAP_CLUSTER}" apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: "${CLUSTER_NAME,,}"
  namespace: platform-management-system
  labels:
    argocd.argoproj.io/secret-type: cluster
    cluster.ssc-spc.gc.ca/use: argocd
type: Opaque
stringData:
  name: "${CLUSTER_NAME,,}"
  server: "${api_server}"
  config: |
    {
      "bearerToken": "${token}",
      "tlsClientConfig": {
        "insecure": false,
        "caData": "${ca}"
      }
    }
EOF
