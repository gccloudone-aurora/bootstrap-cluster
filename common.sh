#!/bin/bash

set -eou pipefail

source .env

################
### SETTINGS ###
################

# List of clusters
BOOTSTRAP_CLUSTER="bootstrap-local-cc-00"

# Use a local kubeconfig file
export KUBECONFIG=$PWD/.kubeconfig

# Fix incorrect DNS configuration: https://github.com/k3d-io/k3d/issues/209
export K3D_FIX_DNS=1

#################
### FUNCTIONS ###
#################

create_cluster () {
  cluster=$1
  shift

  if ! k3d cluster list "${cluster}" >/dev/null 2>&1; then
    echo "[${cluster}]: Creating cluster..."
    if [ -f /usr/local/share/ca-certificates/custom.crt ]; then
      echo "[${cluster}]: Custom certificate found, adding volume..."
      k3d cluster create --volume /usr/local/share/ca-certificates/custom.crt:/etc/ssl/certs/custom.crt --k3s-arg '--disable=traefik@server:0' "$@" "${cluster}"
    else
      k3d cluster create --k3s-arg '--disable=traefik@server:0' "$@" "${cluster}"
    fi
  else
    echo "[${cluster}]: Cluster already exists, skipping..."
  fi
}

delete_cluster () {
  cluster=$1
  shift

  echo "[${cluster}]: Deleting cluster..."
  k3d cluster list "${cluster}" >/dev/null 2>&1 && k3d cluster delete "${cluster}"
}

do_kubectl () {
  cluster="k3d-$1"
  shift

  kubectl --context "${cluster}" "$@"
}

do_helm () {
  cluster="k3d-$1"
  shift

  helm --kubeconfig "${KUBECONFIG}" --kube-context "${cluster}" "$@"
}
