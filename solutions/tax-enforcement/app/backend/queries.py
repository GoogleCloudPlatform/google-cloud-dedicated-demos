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
"""SQL Queries for Tax Office Application."""

import os

# BigQuery Resources
DATASET = os.environ.get('DATASET_ID', 'tax_office_dataset')
TAX_TABLE = os.environ.get('TAX_TABLE_ID', 'tax_data_table')
PREDICTIONS_TABLE = os.environ.get('PREDICTIONS_TABLE_ID', 'predictions')
POLICIES_TABLE = os.environ.get('POLICY_TABLE_ID', 'policies')
EMBEDDINGS_TABLE = os.environ.get('POLICY_EMBEDDINGS_TABLE_ID', 'policy_embeddings')

TABLE_ALL_DATA = f'`{DATASET}.{TAX_TABLE}`'
TABLE_PREDICTIONS = f'`{DATASET}.{PREDICTIONS_TABLE}`'
TABLE_POLICIES = f'`{DATASET}.{POLICIES_TABLE}`'
TABLE_POLICY_EMBEDDINGS = f'`{DATASET}.{EMBEDDINGS_TABLE}`'

# Predictions query
PREDICTIONS_QUERY = f"""
SELECT
    taxpayer_id,
    declaration_id,
    predicted_is_anomaly,
    anomaly_probability,
    CURRENT_TIMESTAMP() as last_updated
FROM {TABLE_PREDICTIONS}
LIMIT {{limit}}
"""

# Statistics query
STATS_QUERY = f"""
SELECT
    COUNT(*) as total_predictions,
    SUM(CASE WHEN predicted_is_anomaly THEN 1 ELSE 0 END) as predicted_anomalies,
    AVG(anomaly_probability) as avg_probability,
    MAX(anomaly_probability) as max_probability
FROM {TABLE_PREDICTIONS}
"""

# Detailed data query
DETAILED_DATA_QUERY = f"""
SELECT
    -- Identifiers
    taxpayer_id,
    declaration_id,
    tax_year,

    -- Taxpayer basic info
    taxpayer_type,
    industry_code,
    address_state,
    first_name,
    last_name,
    company_name,
    date_of_birth,

    -- Financial data
    gross_income,
    taxable_income,
    total_deductions,
    calculated_tax,

    -- Cryptocurrency data
    has_crypto_account,
    crypto_exchange_name,
    crypto_account_verified_date,
    declared_crypto_income,
    crypto_transaction_count,
    has_declared_crypto_previously,

    -- Calculated ratios
    deduction_ratio,
    tax_ratio,
    crypto_income_ratio,

    -- Crypto flags
    is_crypto_non_declarant,
    crypto_risk_score,

    -- Filing behavior
    filing_date,
    is_late_filing,
    has_amendments,
    days_filing_delay,

    -- Payment behavior
    is_late_payment,
    days_payment_delay,
    payment_date,

    -- Historical patterns
    late_filing_rate,
    late_payment_rate,
    amendment_rate,
    income_volatility,
    avg_deduction_ratio,

    -- Target variables
    is_anomaly,
    anomaly_type,
    anomaly_confidence,

    -- Metadata
    data_source,
    created_at,
    updated_at
FROM {TABLE_ALL_DATA}
WHERE taxpayer_id = @taxpayer_id
AND declaration_id = @declaration_id
"""

# Get prediction for specific taxpayer
PREDICTION_FOR_TAXPAYER_QUERY = f"""
SELECT
    taxpayer_id,
    declaration_id,
    predicted_is_anomaly,
    anomaly_probability
FROM {TABLE_PREDICTIONS}
WHERE taxpayer_id = @taxpayer_id
AND declaration_id = @declaration_id
LIMIT 1
"""

# Policy Management Queries

# Save policy
SAVE_POLICY_QUERY = f"""
INSERT INTO {TABLE_POLICIES} (id, filename, content, file_size, uploaded_at, embedding_count)
VALUES (@id, @filename, @content, @file_size, CURRENT_TIMESTAMP(), 0)
"""

# Update policy embedding count
UPDATE_POLICY_EMBEDDING_COUNT_QUERY = f"""
UPDATE {TABLE_POLICIES}
SET embedding_count = @count
WHERE id = @policy_id
"""

# Get all policies
GET_POLICIES_QUERY = f"""
SELECT id, filename, file_size, uploaded_at, embedding_count
FROM {TABLE_POLICIES}
WHERE NOT STARTS_WITH(filename, '[DELETED]')
ORDER BY uploaded_at DESC
"""

# Delete policy embeddings
DELETE_POLICY_EMBEDDINGS_QUERY = f"""
DELETE FROM {TABLE_POLICY_EMBEDDINGS}
WHERE policy_id = @policy_id
"""

# Mark policy as deleted (streaming buffer workaround)
MARK_POLICY_DELETED_QUERY = f"""
UPDATE {TABLE_POLICIES}
SET filename = CONCAT('[DELETED] ', filename),
    embedding_count = 0
WHERE id = @policy_id
"""

# Delete policy
DELETE_POLICY_QUERY = f"""
DELETE FROM {TABLE_POLICIES}
WHERE id = @policy_id
"""

# Vector search for similar policy
VECTOR_SEARCH_SIMILAR_POLICY_QUERY = f"""
SELECT
    base.text_chunk,
    base.policy_id,
    base.chunk_index,
    p.content AS full_policy,
    p.filename,
    distance
FROM VECTOR_SEARCH(
    TABLE {TABLE_POLICY_EMBEDDINGS},
    'embedding',
    (SELECT @query_embedding AS embedding),
    top_k => @top_k,
    distance_type => 'COSINE'
)
JOIN {TABLE_POLICIES} p ON base.policy_id = p.id
WHERE NOT STARTS_WITH(p.filename, '[DELETED]')
ORDER BY distance ASC
LIMIT 1
"""
