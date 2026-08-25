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
# Standalone GCE Virtual Machine for Fluent Bit & OpenTelemetry Collector Logging Demo
resource "google_compute_instance" "logging_demo_vm" {
  count        = local.config.gce_enabled ? 1 : 0
  name         = local.config.gce_instance_name
  machine_type = local.config.gce_machine_type
  zone         = "${data.google_client_config.default.region}-a"
  project      = data.google_client_config.default.project

  boot_disk {
    initialize_params {
      image = local.config.gce_image
    }
  }

  network_interface {
    subnetwork = length(google_compute_subnetwork.monitoring_subnet) > 0 ? google_compute_subnetwork.monitoring_subnet[0].id : local.config.subnet_name
  }

  service_account {
    email  = google_service_account.logging_vm_sa[0].email
    scopes = ["cloud-platform"]
  }

  metadata = {
    startup-script            = file("${path.module}/../scripts/gce/install-vm-monitoring.sh")
    UNIVERSE_DOMAIN           = local.config.universe_api_domain
    ENABLE_DEMO_LOG_GENERATOR = local.config.gce_enable_demo_log_generator ? "true" : "false"
    fluent_bit_conf           = file("${path.module}/../scripts/gce/fluent-bit.conf")
    otelcol_config_yaml       = file("${path.module}/../scripts/gce/otelcol-config.yaml")
    vm_demo_app_py            = file("${path.module}/../apps/gce-demo-app/vm-demo-app.py")
    vm_demo_app_service       = file("${path.module}/../apps/gce-demo-app/vm-demo-app.service")
  }

  depends_on = [
    google_project_iam_member.logging_vm_sa_log_writer
  ]
}
