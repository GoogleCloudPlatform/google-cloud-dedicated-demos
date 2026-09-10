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
# =========================================================================
# 1. UNIVERSE A: STS CONTROL PLANE (GCP)
# =========================================================================

# Source GCS Bucket
resource "google_storage_bucket" "source_bucket" {
  count                       = var.enable_sts_control_plane ? 1 : 0
  name                        = "${var.prefix}${var.source_bucket_name}"
  location                    = "europe-west3" # Universe A GCS default location
  project                     = var.project_id
  uniform_bucket_level_access = true
  force_destroy               = true
}

# IAM Service Account for STS Agent Reader in GCP
resource "google_service_account" "sts_agent_reader" {
  count        = var.enable_sts_control_plane ? 1 : 0
  account_id   = trimsuffix(substr("${var.prefix}sts-agent-reader", 0, 30), "-")
  display_name = "STS Agent Reader for Cross-Universe"
  project      = var.project_id
}

# Grant Viewer role to the SA on the Source Bucket
resource "google_storage_bucket_iam_member" "source_bucket_viewer" {
  count  = var.enable_sts_control_plane ? 1 : 0
  bucket = google_storage_bucket.source_bucket[0].name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.sts_agent_reader[0].email}"
}

# Grant transferAgent role on the GCP project to the SA
resource "google_project_iam_member" "project_transfer_agent" {
  count   = var.enable_sts_control_plane ? 1 : 0
  project = var.project_id
  role    = "roles/storagetransfer.transferAgent"
  member  = "serviceAccount:${google_service_account.sts_agent_reader[0].email}"
}

# Create Private Key for the Service Account
resource "google_service_account_key" "sts_agent_reader_key" {
  count              = var.enable_sts_control_plane ? 1 : 0
  service_account_id = google_service_account.sts_agent_reader[0].name
}

# Auto-save key to local filesystem for the Universe B (GCD) workspace
resource "local_file" "sts_agent_reader_key_file" {
  count    = var.enable_sts_control_plane ? 1 : 0
  content  = base64decode(google_service_account_key.sts_agent_reader_key[0].private_key)
  filename = "${path.module}/../../envs/gcd/sts-agent-reader-key.json"
}

# Storage Transfer Agent Pool
resource "google_storage_transfer_agent_pool" "agent_pool" {
  count        = var.enable_sts_control_plane ? 1 : 0
  name         = "${var.prefix}${var.agent_pool_name}"
  project      = var.project_id
  display_name = "Federation Demo Agent Pool"
}

# Storage Transfer Job: GCS to POSIX
resource "google_storage_transfer_job" "gcs_to_posix_job" {
  count       = var.enable_sts_control_plane ? 1 : 0
  name        = "transferJobs/OPI${var.prefix}${var.transfer_job_name}"
  description = var.transfer_job_name
  project     = var.project_id

  transfer_spec {
    gcs_data_source {
      bucket_name = google_storage_bucket.source_bucket[0].name
    }
    posix_data_sink {
      root_directory = "/transfer_root"
    }
    sink_agent_pool_name = google_storage_transfer_agent_pool.agent_pool[0].id
  }

  status = "ENABLED"
}

# =========================================================================
# 2. UNIVERSE B: STS DATA PLANE (GCD / TPC SOVEREIGN)
# =========================================================================

# Destination GCS Bucket
resource "google_storage_bucket" "dest_bucket" {
  count                       = var.enable_sts_data_plane ? 1 : 0
  name                        = "${var.prefix}${var.dest_bucket_name}"
  location                    = var.dest_bucket_location
  project                     = var.project_id
  force_destroy               = true
  uniform_bucket_level_access = true
}

# Get default Compute Engine Service Account email
data "google_compute_default_service_account" "default" {
  count   = var.enable_sts_data_plane ? 1 : 0
  project = var.project_id

  # Defer evaluation until the network subnet is fully created and API is active
  depends_on = [
    var.subnet_id
  ]
}

# Grant objectAdmin role on the destination GCS bucket to default Compute SA
resource "google_storage_bucket_iam_member" "dest_bucket_admin" {
  count  = var.enable_sts_data_plane ? 1 : 0
  bucket = google_storage_bucket.dest_bucket[0].name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${data.google_compute_default_service_account.default[0].email}"
}

# Private STS Agent VM Instance
resource "google_compute_instance" "sts_agent_vm" {
  count        = var.enable_sts_data_plane ? 1 : 0
  name         = "${var.prefix}${var.sts_agent_vm_name}"
  machine_type = var.vm_machine_type
  zone         = var.zone
  project      = var.project_id

  boot_disk {
    initialize_params {
      image = var.vm_image
    }
  }

  network_interface {
    subnetwork = var.subnet_id
    # Private IP only (no-address)
  }

  # VM Instance scopes for write permissions
  service_account {
    scopes = ["cloud-platform"]
  }

  metadata = {
    # Startup script path points to our repository copy
    startup-script = file("${path.module}/../../../scripts/sts-agent-vm-start-script.sh")

    # Credentials JSON from Universe A (copied by local_file above)
    # We use fileexists() to prevent plan failures when the key file is not yet generated in GCP step
    creds-json = fileexists("${path.module}/../../envs/gcd/sts-agent-reader-key.json") ? file("${path.module}/../../envs/gcd/sts-agent-reader-key.json") : ""

    # Startup-script attributes
    DEST_BUCKET_NAME = "${var.prefix}${var.dest_bucket_name}"
    AGENT_POOL_NAME  = "${var.prefix}${var.agent_pool_name}"
    PROJECT_ID       = var.gcp_project_id
  }

  depends_on = [
    google_storage_bucket_iam_member.dest_bucket_admin
  ]
}
