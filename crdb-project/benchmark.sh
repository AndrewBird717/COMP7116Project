#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
source config.env
k=(kubectl --context crdb-lab -n crdb-lab)
url='postgresql://root@cockroachdb-public:26257?sslmode=disable'
case "${1:-}" in
  init)
    "${k[@]}" exec workload -- /cockroach/cockroach workload init tpcc --data-loader=INSERT \
    --init-conns=2 --drop --warehouses="$WAREHOUSES" "$url"
    ;;
  run)
    name=${2:-baseline}
    [[ "$name" =~ ^[a-zA-Z0-9_-]+$ ]] || { echo 'Invalid run name'; exit 1; }
    dir="results/$(date -u +%Y%m%dT%H%M%SZ)-$name"
    mkdir -p results; mkdir "$dir"
    cp config.env "$dir/"
    "${k[@]}" get pods -o wide > "$dir/pods-before.txt"
    date -u +%FT%TZ > "$dir/start.txt"
    echo "Saving to $dir"
    status=0
    "${k[@]}" exec workload -- /cockroach/cockroach workload run tpcc --warehouses="$WAREHOUSES" --workers="$WORKERS" --wait="$WAIT" --duration="$DURATION" --tolerate-errors --histograms="/tmp/$(basename "$dir").json" "$url" 2>&1 | tee "$dir/workload.log" || status=$?
    date -u +%FT%TZ > "$dir/end.txt"
    "${k[@]}" exec workload -- cat "/tmp/$(basename "$dir").json" > "$dir/histograms.json" || { rm -f "$dir/histograms.json"; echo 'Histogram export failed'; status=1; }
    exit "$status"
    ;;
  *) echo 'Usage: ./benchmark.sh init | run [name]'; exit 2;;
esac
