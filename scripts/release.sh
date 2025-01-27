#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

GCS_BUCKET_NAME="gs://tsorage/helm-tsorage-repository"

# setup for helm-gcs plugin
echo "${GCLOUD_SERVICE_ACCOUNT_KEY}" > svc-acc.json
export GOOGLE_APPLICATION_CREDENTIALS=svc-acc.json

# initializing helm repo
# (only needed on first run, but will do nothing if already exists)
echo "Initializing helm repo"
helm gcs init ${GCS_BUCKET_NAME}

# add gcs bucket as helm repo
echo "Adding gcs bucket repo ${GCS_BUCKET_NAME}"
helm repo add private ${GCS_BUCKET_NAME}

prev_rev=$(git rev-parse HEAD^)
echo "Identifying changed charts since git rev ${prev_rev}"

changed_charts=()
readarray -t changed_charts <<< "$(git diff --find-renames --diff-filter=d --name-only "$prev_rev" -- charts | cut -d '/' -f 2 | uniq)"

if [[ -n "${changed_charts[*]}" ]]; then
    for chart in "${changed_charts[@]}"; do
        echo "Packaging chart '$chart'..."
        chart_file=$(helm package "charts/$chart" | awk '{print $NF}')

        echo "Pushing $chart_file..."
        helm gcs push "$chart_file" private
    done
else
    echo "No chart changes detected"
fi
