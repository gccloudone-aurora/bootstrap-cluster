# bootstrap-cluster

Bootstrap environment from a local Argo CD instance then transfer control to Management Argo CD instance.

## Description

Leverage a Bootstrap environment using k3d for a local Argo CD then transfer control to the management Argo CD instance.

## Changelog

Changes to this project are tracked in the [CHANGELOG](/CHANGELOG.md) which uses the [keepachangelog](https://keepachangelog.com/en/1.0.0/) format.

## Workfow

The setup process is fairly simple and all you need to do execute the `./setup.sh` script.

```sh
❯ ./setup.sh

Creating bootstrap cluster...
[bootstrap-local-cc-00]: Creating cluster...
INFO[0000] Prep: Network
INFO[0000] Created network 'k3d-bootstrap-local-cc-00'
INFO[0000] Created image volume k3d-bootstrap-local-cc-00-images
INFO[0000] Starting new tools node...
INFO[0001] Starting Node 'k3d-bootstrap-local-cc-00-tools'
INFO[0001] Creating node 'k3d-bootstrap-local-cc-00-server-0'
INFO[0002] Creating LoadBalancer 'k3d-bootstrap-local-cc-00-serverlb'
INFO[0002] Using the k3d-tools node to gather environment information
INFO[0003] HostIP: using network gateway 172.22.0.1 address
INFO[0003] Starting cluster 'bootstrap-local-cc-00'
INFO[0003] Starting servers...
INFO[0003] Starting Node 'k3d-bootstrap-local-cc-00-server-0'
INFO[0010] All agents already running.
INFO[0010] Starting helpers...
INFO[0011] Starting Node 'k3d-bootstrap-local-cc-00-serverlb'
INFO[0020] Injecting records for hostAliases (incl. host.k3d.internal) and for 2 network members into CoreDNS configmap...
INFO[0022] Cluster 'bootstrap-local-cc-00' created successfully!
INFO[0023] You can now use it like this:
kubectl cluster-info
Install ArgoCD Operator on bootstrap...
namespace/argocd-system created
Release "argocd-operator" does not exist. Installing it now.
NAME: argocd-operator
LAST DEPLOYED: Mon Sep 18 10:40:00 2025
NAMESPACE: argocd-system
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:

**********************
** CONGRATULATIONS! **
**********************

The ArgoCD Operator and associated Argo Projects have been installed.
Install ArgoCD instance in platform-management-system
namespace/platform-management-system created
argocd.argoproj.io/argocd created
configmap/argocd-cm patched
[platform-bootstrap] Configuring platform...
serviceaccount/argocd-mgmt created
secret/argocd-mgmt-token created
clusterrolebinding.rbac.authorization.k8s.io/argocd-mgmt created
secret/platform-bootstrap created

==================================

Argo CD: https://localhost:30043
  Username: admin
  Password: XXXXX
```
