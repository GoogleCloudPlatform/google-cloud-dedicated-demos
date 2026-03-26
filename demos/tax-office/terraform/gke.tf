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
resource "google_container_cluster" "tax_office_cluster" {
  name       = local.cluster_name
  location   = var.region
  project    = var.project_id
  network    = google_compute_network.tax_office_network.self_link
  subnetwork = google_compute_subnetwork.tax_office_node_subnet.self_link

  # Workload Identity Federation configuration
  workload_identity_config {
    workload_pool = local.wif_pool_id
  }

  cluster_autoscaling {
    auto_provisioning_defaults {
      service_account = google_service_account.tax_office_node_sa.email
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
      enabled = true
    }
  }

  enable_autopilot = true

  deletion_protection = false

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

  depends_on = [time_sleep.wait_for_service_enablement]
}
