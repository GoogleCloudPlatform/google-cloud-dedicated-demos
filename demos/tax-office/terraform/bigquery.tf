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
resource "google_bigquery_dataset" "tax_office_dataset" {
  dataset_id = var.dataset_id
  location   = var.region

  delete_contents_on_destroy = true
  depends_on                 = [google_project_service.apis_to_enable]
}

resource "google_bigquery_table" "tax_data_external_table" {
  dataset_id          = google_bigquery_dataset.tax_office_dataset.dataset_id
  table_id            = var.tax_table_id
  deletion_protection = false

  external_data_configuration {
    source_format = "CSV"
    autodetect    = true
    source_uris = [
      "gs://${google_storage_bucket.tax_data_bucket.name}/${google_storage_bucket_object.tax_data_object.name}"
    ]
  }
}

# Create the policies table
resource "google_bigquery_table" "policies" {
  dataset_id          = google_bigquery_dataset.tax_office_dataset.dataset_id
  table_id            = var.policy_table_id
  deletion_protection = false

  schema = jsonencode([
    {
      name        = "id"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "Unique identifier for the policy"
    },
    {
      name        = "filename"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "Name of the uploaded file"
    },
    {
      name        = "content"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "Content of the policy document"
    },
    {
      name        = "file_size"
      type        = "INTEGER"
      mode        = "REQUIRED"
      description = "Size of the file in bytes"
    },
    {
      name                   = "uploaded_at"
      type                   = "TIMESTAMP"
      mode                   = "NULLABLE"
      description            = "Timestamp when the policy was uploaded"
      defaultValueExpression = "CURRENT_TIMESTAMP()"
    },
    {
      name                   = "embedding_count"
      type                   = "INTEGER"
      mode                   = "NULLABLE"
      description            = "Number of embeddings created for this policy"
      defaultValueExpression = "0"
    }
  ])
}

# Create the policy_embeddings table
resource "google_bigquery_table" "policy_embeddings" {
  dataset_id          = google_bigquery_dataset.tax_office_dataset.dataset_id
  table_id            = var.policy_embeddings_table_id
  deletion_protection = false

  schema = jsonencode([
    {
      name        = "id"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "Unique identifier for the embedding"
    },
    {
      name        = "policy_id"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "Reference to the parent policy"
    },
    {
      name        = "text_chunk"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "Text chunk from the policy"
    },
    {
      name        = "embedding"
      type        = "FLOAT"
      mode        = "REPEATED"
      description = "Vector embedding of the text chunk"
    },
    {
      name        = "chunk_index"
      type        = "INTEGER"
      mode        = "REQUIRED"
      description = "Index of the chunk within the policy"
    },
    {
      name                   = "created_at"
      type                   = "TIMESTAMP"
      mode                   = "NULLABLE"
      description            = "Timestamp when the embedding was created"
      defaultValueExpression = "CURRENT_TIMESTAMP()"
    }
  ])
}
