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
resource "google_sql_database_instance" "sql" {
  name             = var.sql_instance_name
  project          = data.google_project.this.project_id
  region           = var.region
  database_version = var.database_version_sql

  deletion_protection = false

  settings {
    tier              = var.sql_instance_resources
    availability_type = "ZONAL"

    ip_configuration {
      ipv4_enabled = false

      psc_config {
        psc_enabled               = true
        allowed_consumer_projects = [data.google_project.this.project_id]
      }
    }
    database_flags {
      name  = "cloudsql.iam_authentication"
      value = "on"
    }
  }

  depends_on = [time_sleep.wait_for_service_enablement]
}

resource "google_sql_database" "sql_db" {
  name       = var.database_name
  instance   = google_sql_database_instance.sql.name
  project    = data.google_project.this.project_id
  depends_on = [google_sql_database_instance.sql]
}

resource "google_sql_user" "iam_service_account_user" {
  name     = trimsuffix(google_service_account.jupyter_sa.email, ".gserviceaccount.com")
  instance = google_sql_database_instance.sql.name
  type     = "CLOUD_IAM_SERVICE_ACCOUNT"
  project  = data.google_project.this.project_id
}

resource "google_sql_user" "postgres" {
  name     = "postgres"
  instance = google_sql_database_instance.sql.name
  password = random_password.db_password.result
  project  = data.google_project.this.project_id
}

resource "google_compute_address" "psc_ip" {
  name         = var.psc_endpoint_name
  project      = data.google_project.this.project_id
  subnetwork   = google_compute_subnetwork.subnet_u_france_east1.id
  address_type = "INTERNAL"
  region       = var.region
}

resource "google_compute_forwarding_rule" "psc_link" {
  name                  = var.psc_endpoint_name
  project               = data.google_project.this.project_id
  region                = var.region
  network               = google_compute_network.vpc_default.id
  subnetwork            = google_compute_subnetwork.subnet_u_france_east1.id
  ip_address            = google_compute_address.psc_ip.self_link
  target                = google_sql_database_instance.sql.psc_service_attachment_link
  load_balancing_scheme = ""
}

resource "google_dns_managed_zone" "dns" {
  name     = var.dns_managed_zone_name
  dns_name = var.psc_dns_name
  project  = data.google_project.this.project_id

  visibility = "private"

  private_visibility_config {
    networks {
      network_url = google_compute_network.vpc_default.id
    }
  }
}

resource "google_dns_record_set" "record" {
  name         = google_sql_database_instance.sql.dns_name
  managed_zone = google_dns_managed_zone.dns.name
  type         = "A"
  ttl          = "0"
  project      = data.google_project.this.project_id

  rrdatas = [google_compute_address.psc_ip.address]
}
