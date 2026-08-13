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
variable "prefix" {
  type        = string
  default     = ""
  description = "Prefix for resource names"
}

variable "universe_domain" {
  type        = string
  description = "Domain to use (e.g. googleapis.com or apis-tpczero.goog)"
}

variable "org_id" {
  type        = string
  description = "The organization ID."
}

variable "pool_id" {
  type        = string
  description = "The WIF pool ID."
}

variable "provider_id" {
  type        = string
  description = "The WIF provider ID."
}

variable "federated_user_email" {
  type        = string
  description = "Federated user email to map"
}

variable "idp_metadata_xml_file" {
  type        = string
  description = "The IDP metadata XML file name. It is expected to be found at the root of the module."
}
