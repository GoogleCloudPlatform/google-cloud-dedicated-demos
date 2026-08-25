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
locals {
  raw_config = yamldecode(file("${path.module}/defaults.yaml"))

  # Segregate configs
  tf_cfg      = try(local.raw_config.terraform, {})
  grafana_cfg = try(local.raw_config.grafana, {})
  apps_cfg    = try(local.raw_config.apps, {})
  gce_cfg     = try(local.raw_config.gce, {})

  # Extract required fields
  project_id            = try(local.tf_cfg.project_id, null)
  project_parts         = split(":", coalesce(local.project_id, ""))
  project_prefix        = try(element(local.project_parts, 0), "")
  project_name_id       = try(element(local.project_parts, 1), local.project_id)
  wif_name_for_universe = "${local.project_name_id}.${local.project_prefix}"
  universe_api_domain   = try(local.tf_cfg.universe_api_domain, null)
  region                = try(local.tf_cfg.region, null)

  # Setting up effective names
  effective_resources_prefix = try(local.tf_cfg.resources_prefix, local.project_name_id)
  effective_k8s_ns           = try(local.tf_cfg.k8s_namespace, local.project_name_id)

  # Main Configuration
  # ------------------
  config = {
    project_id          = local.project_id
    resources_prefix    = local.effective_resources_prefix
    region              = local.region
    universe_api_domain = local.universe_api_domain
    k8s_namespace       = local.effective_k8s_ns

    # Infrastructure Toggles & Naming (Drastically simplified interpolations)
    enable_storage_bucket = try(local.tf_cfg.enable_storage_bucket, true)
    storage_bucket_name   = try(local.tf_cfg.storage_bucket_name, "${local.effective_resources_prefix}-storage")

    enable_gke = try(local.tf_cfg.enable_gke, true)
    gke_name   = try(local.tf_cfg.gke_name, "${local.effective_resources_prefix}-cluster")

    enable_artifact_registry = try(local.tf_cfg.enable_artifact_registry, true)
    artifact_registry        = try(local.tf_cfg.artifact_registry, "${local.effective_resources_prefix}-registry")
    artifact_registry_uri    = try(local.tf_cfg.artifact_registry_uri, null)

    # Networking
    vpc_name          = try(local.tf_cfg.vpc_name, "${local.effective_resources_prefix}-vpc")
    subnet_name       = try(local.tf_cfg.subnet_name, "${local.effective_resources_prefix}-subnet")
    proxy_subnet_name = try(local.tf_cfg.proxy_subnet_name, "${local.effective_resources_prefix}-proxy-subnet")
    router_name       = try(local.tf_cfg.router_name, "${local.effective_resources_prefix}-router")
    nat_name          = try(local.tf_cfg.nat_name, "${local.effective_resources_prefix}-nat")

    # Service Accounts & Services
    grafana_sa         = try(local.tf_cfg.grafana_sa, "grafana-sa")
    mimir_sa           = try(local.tf_cfg.mimir_sa, "mimir-storage-sa")
    otel_sa            = try(local.tf_cfg.otel_sa, "otel-collector")
    monitoring_node_sa = try(local.tf_cfg.monitoring_node_sa, "monitoring-node-sa")
    logging_vm_sa      = try(local.tf_cfg.logging_vm_sa, "${local.effective_resources_prefix}-vm-sa")
    services = try(local.tf_cfg.services, [
      "artifactregistry.googleapis.com", "cloudresourcemanager.googleapis.com",
      "compute.googleapis.com", "container.googleapis.com",
      "dns.googleapis.com", "iam.googleapis.com",
      "storage.googleapis.com", "logging.googleapis.com", "monitoring.googleapis.com"
    ])

    # Grafana Settings
    grafana_admin_user         = try(local.grafana_cfg.admin_user, null)
    grafana_admin_password     = try(local.grafana_cfg.admin_password, null)
    grafana_client_id          = try(local.grafana_cfg.oauth.client_id, null)
    grafana_client_secret      = try(local.grafana_cfg.oauth.client_secret, null)
    grafana_oauth_provider_url = try(local.grafana_cfg.oauth.provider_url, null)
    grafana_enable_oauth_Login = try(local.grafana_cfg.oauth.enable, true)
    grafana_disable_login_form = try(local.grafana_cfg.disable_login_form, true)

    # Compute Engine (GCE)
    gce_enabled                   = try(local.gce_cfg.enabled, true)
    gce_instance_name             = try(local.gce_cfg.instance_name, "${local.effective_resources_prefix}-monitoring-demo-vm")
    gce_machine_type              = try(local.gce_cfg.machine_type, length(local.project_prefix) > 0 ? "c3-standard-4" : "e2-medium")
    gce_image                     = try(local.gce_cfg.image, length(local.project_prefix) > 0 ? "${local.project_prefix}-system:debian-cloud/debian-12" : "debian-cloud/debian-12")
    gce_enable_demo_log_generator = try(local.gce_cfg.enable_demo_log_generator, true)
  }

  # Standard FinOps and Sovereign governance metadata labels
  common_labels = {
    environment  = "demo"
    managed_by   = "terraform"
    component    = "monitoring"
    architecture = "sovereign-mvp"
  }
}

check "config_validation" {
  assert {
    condition     = try(length(local.config.project_id), 0) > 0 && can(regex(":", try(local.config.project_id, "")))
    error_message = "Project ID must not be empty and must include the universe prefix (e.g., eu0:monitoring-demo)."
  }

  assert {
    condition     = try(length(local.effective_resources_prefix), 0) > 0
    error_message = "Resources Prefix must not be empty (e.g., monitoring)."
  }

  assert {
    condition     = try(length(local.config.region), 0) > 0
    error_message = "Region must not be empty."
  }

  assert {
    condition     = try(length(local.config.universe_api_domain), 0) > 0
    error_message = "Universe API Domain must not be empty."
  }

  assert {
    condition     = local.config.enable_artifact_registry || try(length(local.config.artifact_registry_uri), 0) > 0
    error_message = "When enable_artifact_registry is false, artifact_registry_uri must be provided in defaults.yaml."
  }

  assert {
    condition     = try(length(local.config.grafana_admin_user), 0) > 0
    error_message = "Grafana adminUser must be explicitly provided in defaults.yaml."
  }

  assert {
    condition     = try(length(local.config.grafana_admin_password), 0) > 0
    error_message = "Grafana adminPassword must be explicitly provided in defaults.yaml."
  }

  assert {
    condition = ! local.config.grafana_enable_oauth_Login || (
      local.config.grafana_client_id != null &&
      local.config.grafana_client_secret != null &&
      local.config.grafana_oauth_provider_url != null
    )
    error_message = "enable_oauth_Login is true. client_id, client_secret, oauth_provider_url must be provided."
  }

}

data "google_client_config" "default" {}

data "google_project" "default" {
  project_id = local.config.project_id
}
