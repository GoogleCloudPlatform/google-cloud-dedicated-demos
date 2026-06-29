#!/usr/bin/env bash
#
# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TF_DIR="$BASE_DIR/terraform"

GCP_PROJECT_ID="${GCP_PROJECT_ID:-$(terraform -chdir="$TF_DIR" output -raw project_id)}"
GCS_BUCKET="${GCS_BUCKET_NAME:-$(terraform -chdir="$TF_DIR" output -raw claims_document_bucket)}"
UNIVERSE_DOMAIN="${UNIVERSE_DOMAIN:-$(terraform -chdir="$TF_DIR" output -raw universe_domain)}"
GKE_CLUSTER_NAME="${GKE_CLUSTER_NAME:-$(terraform -chdir="$TF_DIR" output -raw gke_cluster_name)}"
GCP_REGION="${GCP_REGION:-$(terraform -chdir="$TF_DIR" output -raw region)}"

gcloud container clusters get-credentials "$GKE_CLUSTER_NAME" --region "$GCP_REGION" --project "$GCP_PROJECT_ID" >/dev/null 2>&1

echo "Uploading schema, sample data CSVs, and claim documents to GCS..."
gcloud storage cp "$BASE_DIR/schema/transactional_db_schema_postgres.sql" "gs://$GCS_BUCKET/"
gcloud storage cp "$BASE_DIR/samples/dataset"/*.csv "gs://$GCS_BUCKET/"
gcloud storage cp "$BASE_DIR/samples/claims"/* "gs://$GCS_BUCKET/"

echo "Initializing BigQuery Data Warehouse historical records..."
bq --api="https://bigquery.$UNIVERSE_DOMAIN" load --source_format=CSV --autodetect "$GCP_PROJECT_ID:next_demo_health_insurance_ds.historical_customers" "$BASE_DIR/samples/dataset/historical_customers.csv"
bq --api="https://bigquery.$UNIVERSE_DOMAIN" load --source_format=CSV --autodetect "$GCP_PROJECT_ID:next_demo_health_insurance_ds.historical_claims" "$BASE_DIR/samples/dataset/historical_claims.csv"
bq --api="https://bigquery.$UNIVERSE_DOMAIN" load --source_format=CSV --autodetect "$GCP_PROJECT_ID:next_demo_health_insurance_ds.customer_plans" "$BASE_DIR/samples/dataset/customer_plans.csv"

echo "✅ GCS uploads and BigQuery initialization complete. DB init job will run during Helm deployment."
