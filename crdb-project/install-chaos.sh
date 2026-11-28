#!/usr/bin/env bash
set -euo pipefail
helm repo add chaos-mesh https://charts.chaos-mesh.org --force-update
helm repo update
helm upgrade --install chaos-mesh chaos-mesh/chaos-mesh --kube-context crdb-lab --namespace chaos-mesh --create-namespace --set chaosDaemon.runtime=containerd --set chaosDaemon.socketPath=/run/containerd/containerd.sock --version 2.8.8 --wait --timeout 10m
kubectl --context crdb-lab -n chaos-mesh get pods
