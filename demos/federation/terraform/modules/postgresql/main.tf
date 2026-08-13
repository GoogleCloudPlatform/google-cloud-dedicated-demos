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
# Database version to use
locals {
  db_version = "POSTGRES_15"
}

# Network Attachment for PSC Outbound
resource "google_compute_network_attachment" "psc_outbound_attachment" {
  name                  = "${var.prefix}federation-psc-outbound-attachment"
  region                = var.region
  project               = var.project_id
  connection_preference = "ACCEPT_AUTOMATIC"
  subnetworks           = [var.subnet_id]
}

# Reserve a static internal IP for the PSC Endpoint
resource "google_compute_address" "sql_psc_ip" {
  name         = "${var.prefix}federation-sql-psc-ip"
  subnetwork   = var.subnet_name
  address_type = "INTERNAL"
  address      = var.psc_ip
  region       = var.region
  project      = var.project_id
}

# Create the PSC Endpoint (Forwarding Rule)
resource "google_compute_forwarding_rule" "sql_psc_endpoint" {
  name                  = "${var.prefix}federation-sql-psc-endpoint"
  region                = var.region
  project               = var.project_id
  network               = var.network_name
  ip_address            = google_compute_address.sql_psc_ip.self_link
  target                = google_sql_database_instance.db.psc_service_attachment_link
  load_balancing_scheme = ""

  depends_on = [google_sql_database_instance.db]
}

# =========================================================================
# DATABASE INSTANCE (Cloud SQL)
# =========================================================================

resource "google_sql_database_instance" "db" {
  name             = "${var.prefix}federation-db"
  database_version = local.db_version
  region           = var.region
  project          = var.project_id

  settings {
    tier = var.db_tier

    ip_configuration {
      ipv4_enabled                                  = false
      enable_private_path_for_google_cloud_services = true

      psc_config {
        psc_enabled               = true
        allowed_consumer_projects = [var.project_id]

        network_attachment_uri = var.enable_psc_outbound ? google_compute_network_attachment.psc_outbound_attachment.id : null
      }
    }

    # Enable pglogical flags
    database_flags {
      name  = "cloudsql.enable_pglogical"
      value = "on"
    }
    database_flags {
      name  = "cloudsql.logical_decoding"
      value = "on"
    }
    database_flags {
      name  = "max_replication_slots"
      value = "10"
    }
    database_flags {
      name  = "max_worker_processes"
      value = "10"
    }
    database_flags {
      name  = "max_wal_senders"
      value = "10"
    }
    database_flags {
      name  = "wal_sender_timeout"
      value = "0"
    }
  }

  root_password       = var.admin_password
  deletion_protection = false

  depends_on = [google_compute_network_attachment.psc_outbound_attachment]
}
