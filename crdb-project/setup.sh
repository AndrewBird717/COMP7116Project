#!/usr/bin/env bash
# Run from Ubuntu, not from inside Minikube. Fresh lab only.
set -euo pipefail
cd "$(dirname "$0")"
for cmd in docker minikube kubectl helm; do command -v "$cmd" >/dev/null || { echo "Install $cmd first"; exit 1; }; done
minikube start -p crdb-lab --driver=docker --container-runtime=containerd --cpus="${CPUS:-4}" --memory="${MEMORY_MB:-6144}"
k=(kubectl --context crdb-lab -n crdb-lab)
if "${k[@]}" get statefulset cockroachdb >/dev/null 2>&1; then
  echo 'Database already exists; use README resume instructions, not setup.sh.'; exit 1
fi
kubectl --context crdb-lab create namespace crdb-lab --dry-run=client -o yaml | kubectl --context crdb-lab apply -f -
"${k[@]}" apply -f cockroach.yaml -f workload.yaml
# Init must happen BEFORE readiness. Retry until RPC is available.
initialized=0
for ((i=0;i<90;i++)); do
  if output=$("${k[@]}" exec cockroachdb-0 -- /cockroach/cockroach init --insecure --host=localhost:26257 2>&1); then
    echo "$output"; initialized=1; break
  fi
  echo "$output"
  if [[ "$output" == *"already initialized"* ]]; then initialized=1; break; fi
  sleep 5
done
[[ "$initialized" == 1 ]] || { echo 'Initialization failed; inspect pod logs.'; exit 1; }
"${k[@]}" rollout status statefulset/cockroachdb --timeout=300s
"${k[@]}" wait --for=condition=Ready pod/workload --timeout=300s
"${k[@]}" exec cockroachdb-0 -- /cockroach/cockroach node status --insecure
