# CockroachDB / TPC-C / Chaos Mesh lab

All commands run in your normal Ubuntu terminal. Install Docker, Minikube, kubectl and Helm first (see https://minikube.sigs.k8s.io/docs/start/ and https://helm.sh/docs/intro/install/). This lab uses a dedicated Minikube profile and namespace `crdb-lab` to avoid targeting unrelated workloads.

## First run

1. Edit `cockroach.yaml` (`replicas`, default 3) and `config.env` (default 1 warehouse, 16 workers, 300 seconds). Keep at least three database pods.
2. `bash setup.sh` starts Minikube, applies both manifests, initializes the database once and waits for readiness. Use `CPUS=4 MEMORY_MB=6144 bash setup.sh` to override resources. Ensure your host has enough available memory.
3. `bash benchmark.sh init` populates TPC-C once. Do not rerun init for an existing dataset. For a different dataset size, use a fresh lab.
4. `bash benchmark.sh run baseline` runs and saves the baseline to a timestamped results folder.
5. `bash install-chaos.sh` installs Chaos Mesh.
6. In terminal 1 run `bash benchmark.sh run failure`. In terminal 2, after workload output has appeared and a normal observation interval has elapsed, run:

   ```bash
   date -u +%FT%TZ
   kubectl --context crdb-lab -n crdb-lab apply -f faults/failure.yaml
   kubectl --context crdb-lab -n crdb-lab describe podchaos node-failure
   ```

   Record the actual injection/recovery events and timestamps, not just the apply time. After the benchmark, save the fault status and remove the resource:

   ```bash
   kubectl --context crdb-lab -n crdb-lab get podchaos node-failure -o yaml > failure-status.yaml
   kubectl --context crdb-lab -n crdb-lab delete -f faults/failure.yaml
   ```

   Move the status file into the corresponding results directory. Repeat with `faults/latency.yaml`, `faults/loss.yaml`, or `faults/partition.yaml` (resource names `network-latency`, `network-loss`, `network-partition`; use `get networkchaos NAME -o yaml`). Only apply one fault at a time. Verify recovery before the next trial.

## What each file does

- `cockroach.yaml`: headless peer discovery service, client service and StatefulSet. The startup command executes inside each database pod. Each pod has its own storage.
- `workload.yaml`: an idle pod with the CockroachDB binary; benchmark commands run here, not on the database server.
- `setup.sh`: infrastructure and database setup only.
- `install-chaos.sh`: installs the fault injection controller independently.
- `benchmark.sh`: initializes the dataset or runs a benchmark and exports logs and histograms.
- `config.env`: benchmark settings (trusted local shell configuration).
- `faults/`: independent editable Chaos Mesh manifests. Network faults target node 0 versus nodes 1 and 2, not all links in a larger cluster. Edit selectors for other conditions.

## Useful commands

```bash
kubectl --context crdb-lab -n crdb-lab get pods
kubectl --context crdb-lab -n crdb-lab logs cockroachdb-0
kubectl --context crdb-lab -n crdb-lab exec cockroachdb-0 -- /cockroach/cockroach node status --insecure
kubectl --context crdb-lab -n crdb-lab port-forward svc/cockroachdb-public 8080:8080
```

The console is at http://localhost:8080. Scale up with `kubectl --context crdb-lab -n crdb-lab scale statefulset cockroachdb --replicas=5` and wait for readiness and data rebalancing. Do not scale down without decommissioning; use fresh clusters for clean comparisons.

Stop: `minikube stop -p crdb-lab`. Resume: `minikube start -p crdb-lab`, then check pods. Do not run init again. To completely reset (DESTROYS database storage): `minikube delete -p crdb-lab`. Local results remain. If setup partially fails, inspect logs before deciding whether to reset or finish initialization manually.

## Limitations

Pinned versions match the earlier example; verify image availability, Kubernetes compatibility and CockroachDB licensing before large deployments. Insecure local lab only. Shared hardware limits scalability claims. Default replication policy is three; verify range placement before experiments. `WAIT=false` produces a TPC-C-derived stress workload, not a certified TPC-C result. The database is reused across runs; for rigorous comparisons restore equivalent starting states, repeat trials and record actual fault timings. Prometheus/Grafana and automated fault timing are deliberately not included. Shell syntax and YAML parsing were checked offline; live Kubernetes execution has not been tested.

References: https://github.com/cockroachdb/cockroach/tree/master/cloud/kubernetes ; https://www.cockroachlabs.com/docs/stable/cockroach-workload ; https://chaos-mesh.org/docs/production-installation-using-helm/ ; https://chaos-mesh.org/docs/simulate-network-chaos-on-kubernetes/ ; https://chaos-mesh.org/docs/simulate-pod-chaos-on-kubernetes/
