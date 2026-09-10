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
resource "google_iam_workforce_pool" "federation_pool" {
  workforce_pool_id = "${var.prefix}${var.pool_id}"
  parent            = "organizations/${var.org_id}"
  location          = "global"
  display_name      = "Federation Demo Pool"
  description       = "Workforce Identity Pool for the ${var.universe_domain} universe."
}

resource "google_iam_workforce_pool_provider" "keycloak_provider" {
  workforce_pool_id = google_iam_workforce_pool.federation_pool.workforce_pool_id
  location          = google_iam_workforce_pool.federation_pool.location
  provider_id       = "${var.prefix}${var.provider_id}"
  display_name      = "Keycloak Identity Provider"

  attribute_mapping = {
    "google.subject"      = "assertion.subject"
    "google.display_name" = "assertion.name"
  }

  # ----------------------------------------------------------------------
  # SAML Configuration
  # ----------------------------------------------------------------------
  saml {
    idp_metadata_xml = file("${path.module}/${var.idp_metadata_xml_file}")
  }
}

# Assign Project Creator role at the Organization level to the federated user.
resource "google_organization_iam_member" "federated_user_project_creator" {
  org_id = var.org_id
  role   = "roles/resourcemanager.projectCreator"

  member = "principal://iam.googleapis.com/locations/global/workforcePools/${google_iam_workforce_pool.federation_pool.workforce_pool_id}/subject/${var.federated_user_email}"
}
