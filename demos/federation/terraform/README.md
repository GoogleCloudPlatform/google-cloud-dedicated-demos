# Terraform Configuration Reference (`defaults.yaml`)

This document details the configuration schema for `defaults.yaml` (located in
`terraform/envs/gcp/` and `terraform/envs/gcd/`). It outlines all parameters
passed to Terraform for provisioning cross-universe infrastructure.

## Overview

The `defaults.yaml` file is loaded by Terraform using the native `yamldecode()`
function in `terraform/envs/gcp/main.tf` and `terraform/envs/gcd/main.tf`, and
passed directly to the core orchestration module
([`modules/core`](modules/core)).

It configures feature flags, project identity, cross-universe network
topologies, database replication parameters, federated identity settings, and
background storage transfer configurations.

A template configuration file is available at
[`envs/defaults.yaml.example`](envs/defaults.yaml.example).

--------------------------------------------------------------------------------

## 1. Feature Toggles

Feature toggles enable or disable specific Terraform infrastructure modules
depending on the deployment scenario.

Attribute             | Type      | Default | Description & Federation Rationale
:-------------------- | :-------- | :------ | :---------------------------------
`enable_auth`         | `boolean` | `false` | Controls Workforce Identity Federation deployment ([`modules/auth`](modules/auth)). Provisions Workforce Pool, IdP, and IAM bindings for federated single sign-on across universes.
`enable_network`      | `boolean` | `true`  | Controls dual-universe VPC network deployment ([`modules/network`](modules/network)). Provisions subnets, HA VPN gateways, Cloud Routers, Cloud NAT, PSC endpoints, and Private DNS.
`enable_sts`          | `boolean` | `false` | Controls Storage Transfer Service deployment ([`modules/sts`](modules/sts)). Deploys a private agent VM in GCD and transfer jobs in GCP for cross-universe GCS object replication.
`enable_cloudsql`     | `boolean` | `true`  | Controls PostgreSQL database provisioning ([`modules/postgresql`](modules/postgresql)). Provisions Cloud SQL with `pglogical` replication flags for Option 1 DB synchronization.
`enable_app`          | `boolean` | `true`  | Controls GKE cluster provisioning ([`modules/gke`](modules/gke)). Deploys a GKE cluster to host Bank of Anthos banking microservices.
`enable_monitoring`   | `boolean` | `false` | Controls Cloud Monitoring dashboard ([`modules/monitoring`](modules/monitoring)). Provisions a dashboard tracking cross-universe VPN and ingress LoadBalancer telemetry (GCP only).
`enable_psc_outbound` | `boolean` | `false` | Toggles Network Attachment linking to the database PSC outbound endpoint. Set to `true` during **Step 2** of deployment to enable cross-universe database replication.

--------------------------------------------------------------------------------

## 2. General Environment Settings (`general`)

Configures target cloud universe metadata, project boundaries, and environment
execution flags.

Attribute                 | Type      | Example / Expected Value                                      | Description & Federation Rationale
:------------------------ | :-------- | :------------------------------------------------------------ | :---------------------------------
`general.universe_domain` | `string`  | `"googleapis.com"` (GCP)<br>`"apis-berlin-build0.goog"` (GCD) | Target cloud domain endpoint. Directs Terraform API calls to standard GCP or regional sovereign GCD API domains.
`general.org_id`          | `string`  | `"123456789012"`                                              | Numeric Google Cloud Organization ID. Required for Workforce Identity Pool parent binding and org-level IAM policies.
`general.project_id`      | `string`  | `"my-project"`                                                | Target project ID where Terraform resources are created for the respective cloud universe.
`general.prefix`          | `string`  | `"fed-demo"`                                                  | Short resource naming prefix prepended to provisioned resource names to avoid collisions across environments.
`general.is_gcp`          | `boolean` | `true` (GCP) / `false` (GCD)                                  | Environment indicator flag. Adjusts universe-specific logic for Private DNS resolution, STS control plane vs data plane roles, and IAM permissions.

--------------------------------------------------------------------------------

## 3. Network Infrastructure Settings (`network`)

Configures cross-universe VPC networking, IPsec HA VPN tunnels, BGP routing, and
PSC endpoints.

Attribute                           | Type      | Example / Expected Value                           | Description & Federation Rationale
:---------------------------------- | :-------- | :------------------------------------------------- | :---------------------------------
`network.region`                    | `string`  | `"europe-west1"`                                   | Deployment region for VPC subnets, GKE cluster, VPN gateways, and database instances.
`network.zone`                      | `string`  | `"europe-west1-b"`                                 | Availability zone for Compute Engine instances (test VM and STS agent VM).
`network.local_subnet_cidr`         | `string`  | `"10.0.1.0/24"`                                    | Primary IPv4 CIDR block for the local universe VPC subnet. Must not overlap with the remote universe CIDR.
`network.remote_subnet_cidr`        | `string`  | `"10.0.2.0/24"`                                    | IPv4 CIDR block of the remote universe subnet. Used to configure cross-universe firewall ingress rules and BGP routes.
`network.local_asn`                 | `integer` | `64514`                                            | Autonomous System Number (ASN) for the local Cloud Router BGP session. Must differ from the remote ASN.
`network.remote_asn`                | `integer` | `64515`                                            | Autonomous System Number (ASN) of the remote universe Cloud Router.
`network.shared_ike_key`            | `string`  | `"SecretKey123!"`                                  | Pre-Shared Key (IKE PSK) used to encrypt IPsec HA VPN tunnels between GCP and GCD. Must be identical in both universe configurations.
`network.create_test_vm`            | `boolean` | `false`                                            | Optionally provisions a Compute Engine test VM in the local subnet for network diagnostic checks and SSH verification.
`network.vm_machine_type`           | `string`  | `"n1-standard-1"`                                  | Machine type for the test VM and STS agent VM.
`network.vm_image`                  | `string`  | `"debian-cloud/debian-12"`                         | Disk image used for Compute Engine VM instances.
`network.allowed_ssh_source_ip`     | `string`  | `"203.0.113.5/32"`                                 | Admin external IPv4 address/CIDR permitted by firewall rules to SSH into local VM instances.
`network.google_apis_psc_ip`        | `string`  | `"10.100.100.1"`                                   | Reserved internal IP address for Private Service Connect (PSC) targeting Google APIs (GCP) or Private DNS resolution (GCD).
`network.bgp_cr_interface_0_ip`     | `string`  | `"169.254.1.1"`                                    | Link-local IPv4 address of local Cloud Router interface 0 for VPN Tunnel 0.
`network.bgp_peer_interface_0_ip`   | `string`  | `"169.254.1.2"`                                    | Link-local IPv4 address of remote BGP peer interface for VPN Tunnel 0.
`network.bgp_cr_interface_1_ip`     | `string`  | `"169.254.2.1"`                                    | Link-local IPv4 address of local Cloud Router interface 1 for VPN Tunnel 1.
`network.bgp_peer_interface_1_ip`   | `string`  | `"169.254.2.2"`                                    | Link-local IPv4 address of remote BGP peer interface for VPN Tunnel 1.
`network.remote_vpn_interface_0_ip` | `string`  | `"34.x.x.x"` (Step 2)                              | External IPv4 address of interface 0 on the remote HA VPN gateway. Left blank during initial baseline apply (**Step 1**).
`network.remote_vpn_interface_1_ip` | `string`  | `"34.y.y.y"` (Step 2)                              | External IPv4 address of interface 1 on the remote HA VPN gateway. Left blank during initial baseline apply (**Step 1**).
`network.secondary_ip_ranges`       | `list`    | `pods: 10.101.0.0/16`<br>`services: 10.102.0.0/20` | Secondary CIDR blocks allocated for GKE Autopilot pod and service IP networking.

--------------------------------------------------------------------------------

## 4. Workforce Identity Federation Settings (`auth`)

Configures SAML-based external Identity Provider (IdP) integration via Workforce
Identity Federation (WIF).

Attribute                    | Type     | Example / Expected Value | Description & Federation Rationale
:--------------------------- | :------- | :----------------------- | :---------------------------------
`auth.pool_id`               | `string` | `"federation-demo-pool"` | Identifier for the Workforce Identity Pool created in Google Cloud IAM.
`auth.provider_id`           | `string` | `"keycloak-provider"`    | Identifier for the SAML provider created within the Workforce Identity Pool.
`auth.federated_user_email`  | `string` | `"user@domain.com"`      | Email address of the federated user mapped to Project Creator IAM roles (`roles/resourcemanager.projectCreator`).
`auth.idp_metadata_xml_file` | `string` | `"descriptor.xml"`       | Filename of the SAML IdP XML metadata file containing identity provider certificates and endpoints.

--------------------------------------------------------------------------------

## 5. Storage Transfer Service Settings (`gcs`)

Configures object storage buckets and automated background file transfer agents
for cross-universe asset replication.

Attribute                  | Type     | Example / Expected Value | Description & Federation Rationale
:------------------------- | :------- | :----------------------- | :---------------------------------
`gcs.source_bucket_name`   | `string` | `"gcp-source-bucket"`    | Source GCS bucket name in GCP containing files to replicate.
`gcs.dest_bucket_name`     | `string` | `"gcd-dest-bucket"`      | Destination GCS bucket name in GCD receiving replicated assets.
`gcs.dest_bucket_location` | `string` | `"u-germany-northeast1"` | Regional location of the sovereign destination GCS bucket in GCD.
`gcs.gcp_project_id`       | `string` | `"my-gcp-project"`       | Project ID of the GCP Control Plane where the central STS transfer job and agent pool are managed.
`gcs.agent_pool_name`      | `string` | `"sts-agent-pool"`       | Logical name of the Storage Transfer Service Agent Pool.
`gcs.transfer_job_name`    | `string` | `"gcs-to-gcs-transfer"`  | Identifier for the scheduled on-demand STS transfer job configured in GCP.
`gcs.sts_agent_vm_name`    | `string` | `"sts-agent-vm"`         | Instance name of the Compute Engine VM running the containerized STS agent in GCD.

--------------------------------------------------------------------------------

## 6. Database Settings (`cloudsql_db`)

Configures Cloud SQL PostgreSQL instances and `pglogical` external replication
parameters.

Attribute                    | Type     | Example / Expected Value              | Description & Federation Rationale
:--------------------------- | :------- | :------------------------------------ | :---------------------------------
`cloudsql_db.admin_password` | `string` | `"AdminSecret123!"`                   | Superuser password for the `postgres` admin database account.
`cloudsql_db.db_name`        | `string` | `"bankofanthos"`                      | Name of the relational database instance (e.g., `"bankofanthos"`).
`cloudsql_db.db_role`        | `string` | `"primary"` (GCP) / `"replica"` (GCD) | Database replication role. Defines database as active upstream primary (GCP) or downstream read-only replica (GCD).
`cloudsql_db.db_tier`        | `string` | `"db-custom-2-7680"`                  | Machine configuration tier specifying vCPU and memory allocation for Cloud SQL.
`cloudsql_db.db_user`        | `string` | `"bankuser"`                          | Application database username used by Bank of Anthos microservices.
`cloudsql_db.psc_ip`         | `string` | `"10.0.1.100"`                        | Reserved internal IP address for the Private Service Connect (PSC) database endpoint.
`cloudsql_db.repl_password`  | `string` | `"ReplSecret123!"`                    | Password for the `pglogical` replication user account.

--------------------------------------------------------------------------------

## 7. GKE Cluster Settings (`gke`)

Configures the Kubernetes engine cluster hosting containerized application
microservices.

Attribute          | Type     | Example / Expected Value   | Description & Federation Rationale
:----------------- | :------- | :------------------------- | :---------------------------------
`gke.cluster_name` | `string` | `"federation-gke-cluster"` | Name of the GKE Autopilot cluster provisioned in each universe to host Bank of Anthos microservices.

---

```
Copyright 2026 Google LLC

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    https://www.apache.org/licenses/LICENSE-2.0


Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
