#!/bin/bash

set -eou pipefail

# Load utils
source common.sh

# Steps:
# 1. Install the argocd-operator chart within the argo-operator-system namespace
# 2. Install the argocd-instance chart within the platform-management-system namespace
# 3. Install the aurora-platform chart within the platform-management-system namespace
# 4. Create an image pull secret and attach it to every service account within the platform-management-system namespace
# 5. Wait for Argo CD credentials

echo "Creating ${BOOTSTRAP_CLUSTER} cluster..."
create_cluster "${BOOTSTRAP_CLUSTER}" --k3s-arg "--kube-apiserver-arg=--service-node-port-range=30000-30050@server:0" -p "30000-30050:30000-30050@server:0"

# Adding Managed Identity
# Note we pass Client ID for the AAD Pod Identity / AVP
echo "Adding Managed Identity to VM..."
if [ -z "${MSI_CLIENT_ID}" ]; then
  MSI_CLIENT_ID=$(az vm identity assign --ids $(curl --silent -H 'Metadata: true' 'http://169.254.169.254/metadata/instance?api-version=2021-02-01' | jq -r .compute.resourceId) --identities "$MSI_RESOURCE_ID" | jq -r ".userAssignedIdentities[\"$MSI_RESOURCE_ID\"].clientId")
fi

echo "[${BOOTSTRAP_CLUSTER}] Creating Labels..."
do_kubectl "${BOOTSTRAP_CLUSTER}" label node "k3d-${BOOTSTRAP_CLUSTER}-server-0" node.ssc-spc.gc.ca/purpose=system

echo "[${BOOTSTRAP_CLUSTER}] Creating argo-operator-system namespace..."
cat <<EOF | do_kubectl "${BOOTSTRAP_CLUSTER}" apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: argo-operator-system
  labels:
    namespace.ssc-spc.gc.ca/purpose: platform
EOF

echo "[${BOOTSTRAP_CLUSTER}] Creating platform-system namespace..."
cat <<EOF | do_kubectl "${BOOTSTRAP_CLUSTER}" apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: platform-system
  labels:
    namespace.ssc-spc.gc.ca/purpose: platform
EOF

echo "[${BOOTSTRAP_CLUSTER}] Creating platform-management-system namespace..."
cat <<EOF | do_kubectl "${BOOTSTRAP_CLUSTER}" apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: platform-management-system
  labels:
    namespace.ssc-spc.gc.ca/purpose: platform
EOF

echo [Adding Helm Repositories...]
helm repo add aurora https://gccloudone-aurora.github.io/aurora-platform-charts --force-update

#############################
### argocd-operator chart ###
#############################

echo "[${BOOTSTRAP_CLUSTER}] Installing Argo CD Operator in argo-operator-system..."
do_helm "${BOOTSTRAP_CLUSTER}" \
  -n argo-operator-system \
  upgrade \
  --install \
  --atomic \
  --history-max 2 \
  -f base/argocd-operator.yaml \
  argo-operator \
  aurora/argocd-operator

##############################
### argocd-instance chart  ###
##############################

echo "[${BOOTSTRAP_CLUSTER}] Installing Argo CD instance in platform-management-system..."
do_helm "${BOOTSTRAP_CLUSTER}" \
  -n platform-management-system \
  upgrade \
  --install \
  --atomic \
  --history-max 2 \
  --set argocdInstance.argocdVaultPlugin.credentials.avpType="azurekeyvault" \
  --set argocdInstance.argocdVaultPlugin.credentials.azureClientID="${MSI_CLIENT_ID}" \
  -f base/argocd-instance.yaml \
  --force \
  --version 0.0.7 \
  argocd-instance \
  aurora/argocd-instance

##############################
### aurora-platform chart ###
##############################

echo "[${BOOTSTRAP_CLUSTER}] Installing Aurora platform in platform-management-system..."
do_helm "${BOOTSTRAP_CLUSTER}" \
  -n platform-management-system \
  upgrade \
  --install \
  --atomic \
  --history-max 2 \
  --set global.project="default" \
  --set mgmt.components.argoFoundation.argocdInstance.argocdVaultPlugin.credentials.azureClientID="${MSI_CLIENT_ID}" \
  --set mgmt.components.argoFoundation.argocdInstance.aadPodIdentity.enabled="false" \
  --set mgmt.components.argoFoundation.argocdInstance.netpol.enabled="false" \
  --set mgmt.components.argoFoundation.argocdInstance.notifications.enabled="false" \
  --set "mgmt.components.argoFoundation.argocdProjects.platform.applicationSet.generator.git.repoURL=${CLUSTER_REPOSITORY}" \
  --set "mgmt.components.argoFoundation.argocdProjects.platform.applicationSet.generator.git.revision=main" \
  --set "mgmt.components.argoFoundation.argocdProjects.platform.applicationSet.generator.git.files[0].path=${CLUSTER_PATH}/**/config.yaml" \
  --set "mgmt.components.argoFoundation.argocdProjects.platform.applicationSet.template.source.repoURL=${HELM_REPOSITORY}" \
  --set "mgmt.components.argoFoundation.argocdProjects.solutions.applicationSet.generator.git.repoURL=${CLUSTER_REPOSITORY}" \
  --set "mgmt.components.argoFoundation.argocdProjects.solutions.applicationSet.generator.git.revision=main" \
  --set "mgmt.components.argoFoundation.argocdProjects.solutions.applicationSet.generator.git.files[0].path=${NAMESPACE_PATH}/**/config.yaml" \
  --set "mgmt.components.argoFoundation.argocdProjects.solutions.applicationSet.template.source.repoURL=${HELM_REPOSITORY}" \
  --set "mgmt.components.billOfLanding.enabled=false" \
  -f base/argocd-bootstrap.yaml \
  --force \
  --version 0.0.26 \
  aurora-platform \
  aurora/aurora-platform

#########################
### Image Pull Secret ###
#########################

if [[ -n "$IMAGE_PULL_SECRET" ]]; then
  echo "[${BOOTSTRAP_CLUSTER}] Installing Image Pull Secret..."
  cat <<EOF | do_kubectl "${BOOTSTRAP_CLUSTER}" apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: aurora-image-pull-secret
  namespace: platform-management-system
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: >-
    ${IMAGE_PULL_SECRET}
EOF

  echo "[${BOOTSTRAP_CLUSTER}] Adding Image Pull Secret to Service Accounts for Argo CD..."
  NAMESPACE="platform-management-system"
  SECRET_NAME="aurora-image-pull-secret"
  SERVICE_ACCOUNTS=$(do_kubectl "${BOOTSTRAP_CLUSTER}" get serviceaccounts -n "$NAMESPACE" --no-headers -o custom-columns=':.metadata.name')

  for SA in $SERVICE_ACCOUNTS; do
    CURRENT_SECRETS=$(do_kubectl "${BOOTSTRAP_CLUSTER}" get serviceaccount "$SA" -n "$NAMESPACE" -o jsonpath="{.imagePullSecrets[*].name}")
    if [[ "$CURRENT_SECRETS" != *"$SECRET_NAME"* ]]; then
      do_kubectl "${BOOTSTRAP_CLUSTER}" patch serviceaccount "$SA" -n "$NAMESPACE" -p '{"imagePullSecrets": [{"name": "'$SECRET_NAME'"}]}'
      echo "Added imagePullSecret '$SECRET_NAME' to ServiceAccount '$SA'"
    else
      echo "ImagePullSecret '$SECRET_NAME' already exists in ServiceAccount '$SA'"
    fi
  done
else
  echo "[${BOOTSTRAP_CLUSTER}] Skipping Image Pull Secret setup as IMAGE_PULL_SECRET is empty."
fi

##################################
### Output Argo CD Credentials ###
##################################

# Output credentials for Argo CD
echo
echo "=================================="
echo

until do_kubectl "${BOOTSTRAP_CLUSTER}" get service -n platform-management-system argocd-server >/dev/null 2>&1; do
  sleep 0
done

argocd_port=$(do_kubectl "${BOOTSTRAP_CLUSTER}" get service -n platform-management-system argocd-server -o jsonpath='{.spec.ports[?(@.name == "https")].nodePort}')

until do_kubectl "${BOOTSTRAP_CLUSTER}" get secret -n platform-management-system argocd-cluster >/dev/null 2>&1; do
  sleep 0
done

argocd_password=$(do_kubectl "${BOOTSTRAP_CLUSTER}" get secret -n platform-management-system argocd-cluster -o jsonpath='{.data.admin\.password}' | base64 --decode)

echo "Argo CD: https://$(hostname -f):$argocd_port"
echo "  Username: admin"
echo "  Password: $argocd_password"
