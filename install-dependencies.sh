#!/usr/bin/env bash
# Run as your ordinary Ubuntu user: bash install-dependencies.sh
set -euo pipefail
trap 'echo "Installation failed at line $LINENO" >&2' ERR
if [[ $EUID -eq 0 ]]; then
  echo 'Run without sudo; the script requests sudo where needed.' >&2; exit 1
fi
. /etc/os-release
[[ $ID == ubuntu ]] || { echo 'This installer targets Ubuntu.' >&2; exit 1; }
ARCH=$(dpkg --print-architecture)
case "$ARCH" in amd64|arm64) ;; *) echo "Unsupported architecture: $ARCH" >&2; exit 1;; esac
sudo -v
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
cd "$TMP"
echo '[1/5] Installing Ubuntu packages and Docker'
sudo apt-get update
sudo apt-get install -y ca-certificates curl docker.io conntrack iptables unzip git jq python3 python3-pip python3-venv
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"
sudo docker info >/dev/null

echo '[2/5] Installing Minikube'
MINIKUBE_VERSION=${MINIKUBE_VERSION:-latest}
if [[ $MINIKUBE_VERSION == latest ]]; then
  BASE=https://github.com/kubernetes/minikube/releases/latest/download
else
  BASE=https://github.com/kubernetes/minikube/releases/download/$MINIKUBE_VERSION
fi
curl -fL --retry 3 "$BASE/minikube-linux-$ARCH" -o minikube
curl -fL --retry 3 "$BASE/minikube-linux-$ARCH.sha256" -o minikube.sha256
printf '%s  minikube\n' "$(awk 'NR==1{print $1}' minikube.sha256)" | sha256sum -c -
sudo install -m 0755 minikube /usr/local/bin/minikube

echo '[3/5] Installing kubectl'
KUBECTL_VERSION=${KUBECTL_VERSION:-$(curl -fsSL --retry 3 https://dl.k8s.io/release/stable.txt)}
BASE=https://dl.k8s.io/release/$KUBECTL_VERSION/bin/linux/$ARCH
curl -fL --retry 3 "$BASE/kubectl" -o kubectl
curl -fL --retry 3 "$BASE/kubectl.sha256" -o kubectl.sha256
printf '%s  kubectl\n' "$(cat kubectl.sha256)" | sha256sum -c -
sudo install -m 0755 kubectl /usr/local/bin/kubectl

echo '[4/5] Installing Helm 3'
curl -fsSL --retry 3 https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 -o get-helm.sh
# Official installer verifies downloaded release checksum by default.
bash get-helm.sh

echo '[5/5] Checking installed versions'
docker --version
minikube version
kubectl version --client
helm version
python3 --version
printf '\nInstallation complete. Log out and back in (or reboot) to activate Docker group membership.\n'
printf 'Then run docker ps and, from your project directory, bash setup.sh.\n'
printf 'If kubectl is more than one minor version away from the cluster, use minikube kubectl -- or rerun with KUBECTL_VERSION set to the matching version.\n'
