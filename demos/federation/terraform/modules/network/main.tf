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
# 0. API Services
resource "google_project_service" "compute_api" {
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "dns_api" {
  service            = "dns.googleapis.com"
  disable_on_destroy = false
}
# Wait for API Services to fully propagate in GCP backend (prevents 403 errors during resource creation)
resource "time_sleep" "wait_for_apis" {
  depends_on = [
    google_project_service.compute_api,
    google_project_service.dns_api
  ]
  create_duration = "60s"
}

# 1. VPC & Subnet
resource "google_compute_network" "vpc_network" {
  name                    = "${var.prefix}federation-demo-vpc"
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"

  depends_on = [
    time_sleep.wait_for_apis
  ]
}

resource "google_compute_subnetwork" "subnet" {
  project                  = var.project_id
  name                     = "${var.prefix}federation-demo-subnet"
  ip_cidr_range            = var.local_subnet_cidr
  region                   = var.region
  network                  = google_compute_network.vpc_network.id
  private_ip_google_access = true

  dynamic "secondary_ip_range" {
    for_each = var.secondary_ip_ranges
    content {
      range_name    = secondary_ip_range.value.range_name
      ip_cidr_range = secondary_ip_range.value.ip_cidr_range
    }
  }
}

# 2. Firewall Rules (ALL Traffic from remote subnet)
resource "google_compute_firewall" "allow_all_from_remote" {
  name    = "${var.prefix}allow-all-from-remote"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "all"
  }

  # Allow all traffic from the other universe's subnet range and pod ranges
  source_ranges = [var.remote_subnet_cidr, "10.0.0.0/8"]
}

resource "google_compute_firewall" "allow_ssh" {
  count   = var.allowed_ssh_source_ip != "" ? 1 : 0
  name    = "${var.prefix}allow-ssh"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["${var.allowed_ssh_source_ip}/32"]
}



# 3. Compute Engine Instance for testing (Ping)
resource "google_compute_instance" "test_vm" {
  count        = var.create_test_vm ? 1 : 0
  name         = "${var.prefix}federation-demo-vm"
  machine_type = var.vm_machine_type
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = var.vm_image
    }
  }

  network_interface {
    network    = google_compute_network.vpc_network.id
    subnetwork = google_compute_subnetwork.subnet.id

    # Enable public IP for direct SSH
    access_config {
      // Ephemeral public IP
    }
  }
}

# 4. Local Cloud Router & HA VPN Gateway
resource "google_compute_router" "router" {
  name    = "${var.prefix}federation-router"
  region  = var.region
  network = google_compute_network.vpc_network.name
  bgp {
    asn               = var.local_asn
    advertise_mode    = "CUSTOM"
    advertised_groups = ["ALL_SUBNETWORKS"]

    advertised_ip_ranges {
      range       = var.local_subnet_cidr
      description = "Local Subnet CIDR"
    }

    dynamic "advertised_ip_ranges" {
      for_each = var.secondary_ip_ranges
      content {
        range       = advertised_ip_ranges.value.ip_cidr_range
        description = "Secondary Range ${advertised_ip_ranges.value.range_name}"
      }
    }

    dynamic "advertised_ip_ranges" {
      for_each = var.is_gcp ? [1] : []
      content {
        range       = "${var.google_apis_psc_ip}/32"
        description = "Google APIs PSC Endpoint"
      }
    }
  }
}

resource "google_compute_ha_vpn_gateway" "ha_gateway" {
  name       = "${var.prefix}federation-ha-vpn"
  region     = var.region
  network    = google_compute_network.vpc_network.id
  stack_type = "IPV4_ONLY"
}

# =========================================================================
# STEP 2 RESOURCES: Only deployed when remote VPN IPs are added to YAML
# =========================================================================

# 5. Peer VPN Gateway (Points to the other universe's HA VPN IPs)
resource "google_compute_external_vpn_gateway" "peer_gateway" {
  count           = var.remote_vpn_interface_0_ip != "" ? 1 : 0
  name            = "${var.prefix}federation-peer-gateway"
  redundancy_type = "TWO_IPS_REDUNDANCY"
  description     = "Peer VPN pointing to the other universe"

  interface {
    id         = 0
    ip_address = var.remote_vpn_interface_0_ip
  }
  interface {
    id         = 1
    ip_address = var.remote_vpn_interface_1_ip
  }
}

# 6. VPN Tunnels
resource "google_compute_vpn_tunnel" "tunnel_0" {
  count                           = var.remote_vpn_interface_0_ip != "" ? 1 : 0
  name                            = "${var.prefix}federation-tunnel-0"
  region                          = var.region
  vpn_gateway                     = google_compute_ha_vpn_gateway.ha_gateway.id
  peer_external_gateway           = google_compute_external_vpn_gateway.peer_gateway[0].id
  peer_external_gateway_interface = 0
  shared_secret                   = var.shared_ike_key
  router                          = google_compute_router.router.id
  vpn_gateway_interface           = 0
}

resource "google_compute_vpn_tunnel" "tunnel_1" {
  count                           = var.remote_vpn_interface_0_ip != "" ? 1 : 0
  name                            = "${var.prefix}federation-tunnel-1"
  region                          = var.region
  vpn_gateway                     = google_compute_ha_vpn_gateway.ha_gateway.id
  peer_external_gateway           = google_compute_external_vpn_gateway.peer_gateway[0].id
  peer_external_gateway_interface = 1
  shared_secret                   = var.shared_ike_key
  router                          = google_compute_router.router.id
  vpn_gateway_interface           = 1
}

# 7. Cloud Router BGP Interfaces and Peers
resource "google_compute_router_interface" "router_interface_0" {
  count      = var.remote_vpn_interface_0_ip != "" ? 1 : 0
  name       = "${var.prefix}router-interface-0"
  router     = google_compute_router.router.name
  region     = var.region
  ip_range   = "${var.bgp_cr_interface_0_ip}/30"
  vpn_tunnel = google_compute_vpn_tunnel.tunnel_0[0].name
}

resource "google_compute_router_peer" "router_peer_0" {
  count                     = var.remote_vpn_interface_0_ip != "" ? 1 : 0
  name                      = "${var.prefix}router-peer-0"
  router                    = google_compute_router.router.name
  region                    = var.region
  peer_ip_address           = var.bgp_peer_interface_0_ip
  peer_asn                  = var.remote_asn
  advertised_route_priority = 100
  interface                 = google_compute_router_interface.router_interface_0[0].name
}

resource "google_compute_router_interface" "router_interface_1" {
  count      = var.remote_vpn_interface_0_ip != "" ? 1 : 0
  name       = "${var.prefix}router-interface-1"
  router     = google_compute_router.router.name
  region     = var.region
  ip_range   = "${var.bgp_cr_interface_1_ip}/30"
  vpn_tunnel = google_compute_vpn_tunnel.tunnel_1[0].name
}

resource "google_compute_router_peer" "router_peer_1" {
  count                     = var.remote_vpn_interface_0_ip != "" ? 1 : 0
  name                      = "${var.prefix}router-peer-1"
  router                    = google_compute_router.router.name
  region                    = var.region
  peer_ip_address           = var.bgp_peer_interface_1_ip
  peer_asn                  = var.remote_asn
  advertised_route_priority = 100
  interface                 = google_compute_router_interface.router_interface_1[0].name
}

resource "google_compute_router_nat" "nat" {
  name                               = "${var.prefix}federation-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# =========================================================================
# STEP 3 RESOURCES: Private Service Connect (PSC) for Google APIs & DNS
# =========================================================================

# Deployed in GCP (Universe A) only: PSC global endpoint for Google APIs
resource "google_compute_global_address" "gcp_apis_psc_ip" {
  count        = var.is_gcp ? 1 : 0
  name         = "${var.prefix}gcp-apis-psc-ip"
  address_type = "INTERNAL"
  purpose      = "PRIVATE_SERVICE_CONNECT"
  network      = google_compute_network.vpc_network.id
  address      = var.google_apis_psc_ip
}

resource "google_compute_global_forwarding_rule" "gcp_apis_psc" {
  count                 = var.is_gcp ? 1 : 0
  name                  = "gcp${substr(replace(replace(var.prefix, "-", ""), "_", ""), 0, 12)}psc"
  target                = "all-apis"
  network               = google_compute_network.vpc_network.id
  ip_address            = google_compute_global_address.gcp_apis_psc_ip[0].id
  load_balancing_scheme = ""
}

# Deployed in GCD (Universe B) only: Private DNS Zones for GCS routing
resource "google_dns_managed_zone" "googleapis_private_zone" {
  count       = !var.is_gcp ? 1 : 0
  name        = "${var.prefix}googleapis-private-zone"
  dns_name    = "googleapis.com."
  description = "Private DNS zone for Google APIs to route via PSC"
  visibility  = "private"

  private_visibility_config {
    networks {
      network_url = google_compute_network.vpc_network.id
    }
  }

  depends_on = [
    time_sleep.wait_for_apis
  ]
}

resource "google_dns_record_set" "gcp_apis_psc_a" {
  count        = !var.is_gcp ? 1 : 0
  name         = "gcp-apis-psc.googleapis.com."
  type         = "A"
  ttl          = 300
  managed_zone = google_dns_managed_zone.googleapis_private_zone[0].name
  rrdatas      = [var.google_apis_psc_ip]
}

resource "google_dns_record_set" "googleapis_cname" {
  count        = !var.is_gcp ? 1 : 0
  name         = "*.googleapis.com."
  type         = "CNAME"
  ttl          = 300
  managed_zone = google_dns_managed_zone.googleapis_private_zone[0].name
  rrdatas      = ["gcp-apis-psc.googleapis.com."]
}

resource "google_dns_managed_zone" "gserviceaccount_private_zone" {
  count       = !var.is_gcp ? 1 : 0
  name        = "${var.prefix}gserviceaccount-private-zone"
  dns_name    = "gserviceaccount.com."
  description = "Private DNS zone for GServiceAccounts to route via PSC"
  visibility  = "private"

  private_visibility_config {
    networks {
      network_url = google_compute_network.vpc_network.id
    }
  }

  depends_on = [
    time_sleep.wait_for_apis
  ]
}

resource "google_dns_record_set" "gserviceaccount_cname" {
  count        = !var.is_gcp ? 1 : 0
  name         = "*.gserviceaccount.com."
  type         = "CNAME"
  ttl          = 300
  managed_zone = google_dns_managed_zone.gserviceaccount_private_zone[0].name
  rrdatas      = ["gcp-apis-psc.googleapis.com."]
}
