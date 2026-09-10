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
terraform {
  required_version = ">= 1.0.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0.0"
    }
  }
}

locals {
  full_cluster_name = "${var.prefix}${var.cluster_name}"
}

resource "google_project_service" "container_api" {
  service            = "container.googleapis.com"
  disable_on_destroy = false
  project            = var.project_id
}

resource "google_service_account" "gke_nodes" {
  account_id   = trimsuffix(substr("${var.prefix}${var.cluster_name}-sa", 0, 30), "-")
  display_name = "GKE Node Service Account for ${local.full_cluster_name}"
  project      = var.project_id
}

resource "google_container_cluster" "primary" {
  name     = local.full_cluster_name
  location = var.region
  project  = var.project_id

  network    = var.network_name
  subnetwork = var.subnet_name

  enable_autopilot = true

  ip_allocation_policy {
    cluster_secondary_range_name  = var.cluster_secondary_range_name
    services_secondary_range_name = var.services_secondary_range_name
  }

  cluster_autoscaling {
    auto_provisioning_defaults {
      service_account = google_service_account.gke_nodes.email
      oauth_scopes = [
        "https://www.googleapis.com/auth/cloud-platform"
      ]
    }
  }

  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]
    managed_prometheus {
      enabled = var.is_gcp
    }
  }

  control_plane_endpoints_config {
    dns_endpoint_config {
      allow_external_traffic = true
    }
  }

  master_authorized_networks_config {
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = true
  }

  timeouts {
    create = "30m"
    update = "30m"
    delete = "30m"
  }

  deletion_protection = false

  depends_on = [
    google_project_service.container_api
  ]
}
