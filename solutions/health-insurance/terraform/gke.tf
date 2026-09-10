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
resource "google_container_cluster" "demo-cluster" {
  name                = var.gke_name
  project             = data.google_project.this.project_id
  enable_autopilot    = true
  location            = var.region
  deletion_protection = false
  network             = google_compute_network.vpc_default.self_link
  subnetwork          = google_compute_subnetwork.subnet_u_france_east1.self_link

  ip_allocation_policy {
    cluster_secondary_range_name  = "gke-pods-range"
    services_secondary_range_name = "gke-services-range"
  }

  cluster_autoscaling {
    auto_provisioning_defaults {
      service_account = google_service_account.jupyter_sa.email
      oauth_scopes = [
        "https://www.googleapis.com/auth/cloud-platform"
      ]
    }
  }

  master_authorized_networks_config {
  }

  workload_identity_config {
    workload_pool = "${local.wif_name_for_universe}.svc.id.goog"
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = true
  }

  control_plane_endpoints_config {
    dns_endpoint_config {
      allow_external_traffic = true
    }
  }

  timeouts {
    create = "30m"
    update = "30m"
  }

  depends_on = [
    time_sleep.wait_for_service_enablement,
    google_sql_database_instance.sql
  ]
}
