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
# GKE Autopilot cluster for monitoring stack (Grafana, Mimir, OpenTelemetry)
resource "google_container_cluster" "monitoring_cluster" {
  count               = local.config.enable_gke == true ? 1 : 0
  name                = local.config.gke_name
  project             = data.google_client_config.default.project
  location            = data.google_client_config.default.region
  enable_autopilot    = true
  deletion_protection = false
  resource_labels     = local.common_labels
  network             = google_compute_network.monitoring_vpc[0].self_link
  subnetwork          = google_compute_subnetwork.monitoring_subnet[0].self_link

  workload_identity_config {
    workload_pool = "${local.wif_name_for_universe}.svc.id.goog"
  }

  gateway_api_config {
    channel = "CHANNEL_STANDARD"
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = "gke-pods-range"
    services_secondary_range_name = "gke-services-range"
  }

  cluster_autoscaling {
    auto_provisioning_defaults {
      service_account =  google_service_account.monitoring_node_sa[0].email
      oauth_scopes = [
        "https://www.googleapis.com/auth/cloud-platform"
      ]
    }
  }

  master_authorized_networks_config {
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
    delete = "30m"
  }
}
