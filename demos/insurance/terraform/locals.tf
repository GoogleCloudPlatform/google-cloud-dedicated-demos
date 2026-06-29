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
  # Split project_id (e.g., "eu0:abc-test-env") into parts for wif name: abc-test-env.eu0
  project_id_parts      = split(":", var.project_id)
  project_prefix        = element(local.project_id_parts, 0)
  project_name_id       = element(local.project_id_parts, 1)
  wif_name_for_universe = "${local.project_name_id}.${local.project_prefix}"

  # Base derivations for Shell Scripts & Helm deployment configuration
  registry_host       = "docker.${replace(var.universe_domain, "apis-", "pkg-")}"
  docker_project_path = replace(var.project_id, ":", "/")
  docker_repo_prefix  = "${local.registry_host}/${local.docker_project_path}/${var.artifact_repository_id}"
  model_host          = "https://llm.${var.universe_domain}"
}
