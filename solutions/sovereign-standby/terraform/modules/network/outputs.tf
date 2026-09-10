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
output "local_vpn_interface_0_ip" {
  description = "The first IP address of the newly created HA VPN Gateway. Put this in the 'remote_vpn_interface_0_ip' field in the OTHER environment's YAML."
  value       = google_compute_ha_vpn_gateway.ha_gateway.vpn_interfaces[0].ip_address
}

output "local_vpn_interface_1_ip" {
  description = "The second IP address of the newly created HA VPN Gateway. Put this in the 'remote_vpn_interface_1_ip' field in the OTHER environment's YAML."
  value       = google_compute_ha_vpn_gateway.ha_gateway.vpn_interfaces[1].ip_address
}

output "network_name" {
  description = "The name of the VPC network"
  value       = google_compute_network.vpc_network.name
}

output "subnet_name" {
  description = "The name of the subnet"
  value       = google_compute_subnetwork.subnet.name
}

output "subnet_id" {
  description = "The ID of the subnetwork"
  value       = google_compute_subnetwork.subnet.id
}

output "test_vm_internal_ip" {
  description = "The internal IP address of the testing VM"
  value       = one(google_compute_instance.test_vm[*].network_interface[0].network_ip)
}
