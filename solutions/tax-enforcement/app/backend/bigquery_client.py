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
#!/usr/bin/env python3
"""BigQuery Client for Tax Office Predictions.

Handles all BigQuery database operations.
"""

import datetime
import logging
import os
from typing import Any, Dict, List, Optional
import uuid

from google.api_core import client_options
import google.auth
from google.cloud import bigquery

from .queries import DATASET, EMBEDDINGS_TABLE
from .queries import DELETE_POLICY_EMBEDDINGS_QUERY
from .queries import DELETE_POLICY_QUERY
from .queries import DETAILED_DATA_QUERY
from .queries import GET_POLICIES_QUERY
from .queries import MARK_POLICY_DELETED_QUERY
from .queries import PREDICTION_FOR_TAXPAYER_QUERY
from .queries import PREDICTIONS_QUERY
from .queries import SAVE_POLICY_QUERY
from .queries import STATS_QUERY
from .queries import UPDATE_POLICY_EMBEDDING_COUNT_QUERY
from .queries import VECTOR_SEARCH_SIMILAR_POLICY_QUERY

Datetime = datetime.datetime
ClientOptions = client_options.ClientOptions

# Use environment variables or fallback to defaults
PROJECT_ID = os.environ.get('PROJECT_ID', 'eu0:svr-bigquery-demo')
UNIVERSE_DOMAIN = os.environ.get('UNIVERSE_DOMAIN', 'apis-berlin-build0.goog')

# Get credentials and set the API endpoint based on the universe domain
credentials, default_project = google.auth.default()
api_endpoint = f'https://bigquery.{UNIVERSE_DOMAIN}'
client_opts = ClientOptions(api_endpoint=api_endpoint)

logger = logging.getLogger(__name__)


class BigQueryClient:
  """Client for interacting with BigQuery for Tax Office Predictions.

  Handles initialization and provides methods for querying and managing
  prediction data and policy documents in BigQuery.
  """

  client: Optional[bigquery.Client]

  def __init__(self, client: Optional[bigquery.Client] = None):
    """Initializes the BigQuery client.

    Args:
        client: Optional BigQuery client to use. If None, initialize a new
          client.
    """
    if client:
      self.client = client
    else:
      # Initialize BigQuery client
      try:
        self.client = bigquery.Client(
          project=PROJECT_ID,
          credentials=credentials,
          client_options=client_opts,
        )
        logger.info('BigQuery client initialized successfully')
      except bigquery.exceptions.BigQueryError as e:
        logger.error('Failed to initialize BigQuery client: %s', e)
        self.client = None

  def get_predictions(self, limit=100):
    """Fetch predictions from the predictions view."""
    if not self.client:
      return []

    query = PREDICTIONS_QUERY.format(limit=limit)

    try:
      query_job = self.client.query(query)
      results = query_job.result()

      predictions = []
      for row in results:
        predictions.append(
          {
            'taxpayer_id': row.taxpayer_id,
            'declaration_id': row.declaration_id,
            'predicted_is_anomaly': row.predicted_is_anomaly,
            'anomaly_probability': round(float(row.anomaly_probability), 4),
            'last_updated': (
              row.last_updated.strftime('%Y-%m-%d %H:%M:%S')
              if row.last_updated
              else None
            ),
          }
        )

      logger.info('Retrieved %d predictions from BigQuery', len(predictions))
      return predictions

    except bigquery.exceptions.BigQueryError as e:
      logger.error('Error querying predictions: %s', e)
      return []

  def get_prediction_for_taxpayer(self, taxpayer_id, declaration_id):
    """Get prediction for a specific taxpayer."""
    if not self.client:
      return None

    try:
      job_config = bigquery.QueryJobConfig(
        query_parameters=[
          bigquery.ScalarQueryParameter('taxpayer_id', 'STRING', taxpayer_id),
          bigquery.ScalarQueryParameter('declaration_id', 'STRING', declaration_id),
        ]
      )

      query_job = self.client.query(
        PREDICTION_FOR_TAXPAYER_QUERY, job_config=job_config
      )
      results = query_job.result()

      for row in results:
        return {
          'taxpayer_id': row.taxpayer_id,
          'declaration_id': row.declaration_id,
          'predicted_is_anomaly': row.predicted_is_anomaly,
          'anomaly_probability': float(row.anomaly_probability),
        }

      return None

    except bigquery.exceptions.BigQueryError as e:
      logger.error(
        'Error querying prediction for %s/%s: %s',
        taxpayer_id,
        declaration_id,
        e,
      )
      return None

  def get_stats(self):
    """Get summary statistics about predictions."""
    if not self.client:
      return {}

    query = STATS_QUERY

    try:
      query_job = self.client.query(query)
      results = query_job.result()

      for row in results:
        return {
          'total_predictions': int(row.total_predictions),
          'predicted_anomalies': int(row.predicted_anomalies),
          'avg_probability': (
            round(float(row.avg_probability), 4) if row.avg_probability else 0
          ),
          'max_probability': (
            round(float(row.max_probability), 4) if row.max_probability else 0
          ),
        }

    except bigquery.exceptions.BigQueryError as e:
      logger.error('Error querying stats: %s', e)
      return {}

  def get_detailed_data(self, taxpayer_id, declaration_id):
    """Fetch detailed data for a specific taxpayer and declaration."""
    if not self.client:
      return None

    query = DETAILED_DATA_QUERY

    try:
      job_config = bigquery.QueryJobConfig(
        query_parameters=[
          bigquery.ScalarQueryParameter('taxpayer_id', 'STRING', taxpayer_id),
          bigquery.ScalarQueryParameter('declaration_id', 'STRING', declaration_id),
        ]
      )

      query_job = self.client.query(query, job_config=job_config)
      results = query_job.result()

      for row in results:
        return {
          # Identifiers
          'taxpayer_id': row.taxpayer_id,
          'declaration_id': row.declaration_id,
          'tax_year': int(row.tax_year) if row.tax_year else None,
          # Taxpayer basic info
          'taxpayer_type': row.taxpayer_type,
          'industry_code': row.industry_code,
          'address_state': row.address_state,
          'first_name': row.first_name,
          'last_name': row.last_name,
          'company_name': row.company_name,
          'date_of_birth': (
            row.date_of_birth.strftime('%Y-%m-%d') if row.date_of_birth else None
          ),
          # Financial data
          'gross_income': float(row.gross_income) if row.gross_income else 0,
          'taxable_income': (float(row.taxable_income) if row.taxable_income else 0),
          'total_deductions': (
            float(row.total_deductions) if row.total_deductions else 0
          ),
          'calculated_tax': (float(row.calculated_tax) if row.calculated_tax else 0),
          # Cryptocurrency data
          'has_crypto_account': bool(row.has_crypto_account),
          'crypto_exchange_name': row.crypto_exchange_name,
          'crypto_account_verified_date': (
            row.crypto_account_verified_date.strftime('%Y-%m-%d')
            if row.crypto_account_verified_date
            else None
          ),
          'declared_crypto_income': (
            float(row.declared_crypto_income) if row.declared_crypto_income else 0
          ),
          'crypto_transaction_count': (
            int(row.crypto_transaction_count) if row.crypto_transaction_count else 0
          ),
          'has_declared_crypto_previously': bool(row.has_declared_crypto_previously),
          # Calculated ratios
          'deduction_ratio': (
            round(float(row.deduction_ratio), 4) if row.deduction_ratio else 0
          ),
          'tax_ratio': round(float(row.tax_ratio), 4) if row.tax_ratio else 0,
          'crypto_income_ratio': (
            round(float(row.crypto_income_ratio), 4) if row.crypto_income_ratio else 0
          ),
          # Crypto flags
          'is_crypto_non_declarant': bool(row.is_crypto_non_declarant),
          'crypto_risk_score': (
            round(float(row.crypto_risk_score), 4) if row.crypto_risk_score else 0
          ),
          # Filing behavior
          'filing_date': (
            row.filing_date.strftime('%Y-%m-%d') if row.filing_date else None
          ),
          'is_late_filing': bool(row.is_late_filing),
          'has_amendments': bool(row.has_amendments),
          'days_filing_delay': (
            int(row.days_filing_delay) if row.days_filing_delay else 0
          ),
          # Payment behavior
          'is_late_payment': bool(row.is_late_payment),
          'days_payment_delay': (
            int(row.days_payment_delay) if row.days_payment_delay else 0
          ),
          'payment_date': (
            row.payment_date.strftime('%Y-%m-%d') if row.payment_date else None
          ),
          # Historical patterns
          'late_filing_rate': (
            round(float(row.late_filing_rate), 4) if row.late_filing_rate else 0
          ),
          'late_payment_rate': (
            round(float(row.late_payment_rate), 4) if row.late_payment_rate else 0
          ),
          'amendment_rate': (
            round(float(row.amendment_rate), 4) if row.amendment_rate else 0
          ),
          'income_volatility': (
            round(float(row.income_volatility), 4) if row.income_volatility else 0
          ),
          'avg_deduction_ratio': (
            round(float(row.avg_deduction_ratio), 4) if row.avg_deduction_ratio else 0
          ),
          # Target variables
          'is_anomaly': (bool(row.is_anomaly) if row.is_anomaly is not None else None),
          'anomaly_type': row.anomaly_type,
          'anomaly_confidence': (
            round(float(row.anomaly_confidence), 4) if row.anomaly_confidence else 0
          ),
          # Metadata
          'data_source': row.data_source,
          'created_at': (
            row.created_at.strftime('%Y-%m-%d %H:%M:%S') if row.created_at else None
          ),
          'updated_at': (
            row.updated_at.strftime('%Y-%m-%d %H:%M:%S') if row.updated_at else None
          ),
        }

      return None

    except bigquery.exceptions.BigQueryError as e:
      logger.error(
        'Error querying detailed data for %s/%s: %s',
        taxpayer_id,
        declaration_id,
        e,
      )
      return None

  def vector_search_similar_policy(
    self, query_embedding: List[float], top_k: int = 1
  ) -> Optional[Dict[str, Any]]:
    """Use BigQuery VECTOR_SEARCH to find most similar policy.

    This is much faster than fetching all embeddings and computing similarity in
    Python
    Args:
        query_embedding: Query embedding vector
        top_k: Number of results to return (default 1)

    Returns:
          Dict with matched chunk, full policy content, and similarity score, or
          None
          {
              'text_chunk': str,          # The matched chunk (for highlighting)
              'full_policy': str,         # Complete policy document content
              'policy_id': str,
              'filename': str,            # Policy filename
              'chunk_index': int,         # Position of matched chunk
              'similarity_score': float,  # 0-1 score (1 = perfect match)
              'distance': float          # Raw cosine distance from BigQuery
          }
    """
    if not self.client:
      return None

    try:
      job_config = bigquery.QueryJobConfig(
        query_parameters=[
          bigquery.ArrayQueryParameter('query_embedding', 'FLOAT64', query_embedding),
          bigquery.ScalarQueryParameter('top_k', 'INT64', top_k),
        ]
      )

      query_job = self.client.query(
        VECTOR_SEARCH_SIMILAR_POLICY_QUERY, job_config=job_config
      )
      results = query_job.result()

      for row in results:
        # Convert cosine distance to similarity score
        # COSINE distance in BQ: 0 = identical, 2 = opposite
        # Convert to similarity: 1 - (distance / 2)
        similarity_score = 1 - (row.distance / 2)

        return {
          'text_chunk': row.text_chunk,  # Matched chunk
          'full_policy': row.full_policy,  # Complete policy document
          'policy_id': row.policy_id,
          'filename': row.filename,  # Policy filename
          'chunk_index': row.chunk_index,  # Chunk position
          'similarity_score': float(similarity_score),
          'distance': float(row.distance),
        }

      return None

    except bigquery.exceptions.BigQueryError as e:
      logger.error('Error in vector search: %s', e)
      logger.warning('Falling back to traditional similarity search')
      return None

  # Policy Management Methods
  def save_policy(self, filename: str, content: str, file_size: int) -> str:
    """Save a policy document to BigQuery.

    Args:
        filename: Name of the policy file
        content: Policy text content
        file_size: File size in bytes

    Returns:
        Policy ID

    Raises:
        Exception: If the BigQuery client is not initialized.
    """
    if not self.client:
      raise bigquery.exceptions.BigQueryError('BigQuery client not initialized')

    policy_id = str(uuid.uuid4())

    job_config = bigquery.QueryJobConfig(
      query_parameters=[
        bigquery.ScalarQueryParameter('id', 'STRING', policy_id),
        bigquery.ScalarQueryParameter('filename', 'STRING', filename),
        bigquery.ScalarQueryParameter('content', 'STRING', content),
        bigquery.ScalarQueryParameter('file_size', 'INT64', file_size),
      ]
    )

    try:
      query_job = self.client.query(SAVE_POLICY_QUERY, job_config=job_config)
      query_job.result()
      logger.info('Saved policy %s with ID %s', filename, policy_id)
      return policy_id
    except Exception as e:
      logger.error('Error saving policy: %s', e)
      raise

  def save_policy_embeddings(
    self, policy_id: str, chunks: List[str], embeddings: List[List[float]]
  ):
    """Save policy embeddings to BigQuery.

    Args:
        policy_id: Policy document ID
        chunks: List of text chunks
        embeddings: List of embedding vectors

    Raises:
        bigquery.exceptions.BigQueryError: If the BigQuery client is not
          initialized.
        ValueError: If the number of chunks does not match the number of
          embeddings.
        Exception: If there is an error during the BigQuery insert or update
          operations.
    """
    if not self.client:
      raise bigquery.exceptions.BigQueryError('BigQuery client not initialized')

    if len(chunks) != len(embeddings):
      raise ValueError('Number of chunks and embeddings must match')

    rows_to_insert = []
    for idx, (chunk, embedding) in enumerate(zip(chunks, embeddings)):
      rows_to_insert.append(
        {
          'id': str(uuid.uuid4()),
          'policy_id': policy_id,
          'text_chunk': chunk,
          'embedding': embedding,
          'chunk_index': idx,
          'created_at': Datetime.utcnow().isoformat(),
        }
      )

    try:
      table_id = f'{DATASET}.{EMBEDDINGS_TABLE}'
      errors = self.client.insert_rows_json(table_id, rows_to_insert)

      if errors:
        logger.error('Errors inserting embeddings: %s', errors)
        raise bigquery.exceptions.BigQueryError(
          f'Failed to insert embeddings: {errors}'
        )

      # Update embedding count
      job_config = bigquery.QueryJobConfig(
        query_parameters=[
          bigquery.ScalarQueryParameter('count', 'INT64', len(chunks)),
          bigquery.ScalarQueryParameter('policy_id', 'STRING', policy_id),
        ]
      )

      query_job = self.client.query(
        UPDATE_POLICY_EMBEDDING_COUNT_QUERY, job_config=job_config
      )
      query_job.result()

      logger.info('Saved %d embeddings for policy %s', len(chunks), policy_id)

    except Exception as e:
      logger.error('Error saving policy embeddings: %s', e)
      raise

  def get_policies(self) -> List[Dict[str, Any]]:
    """Get all policies."""
    if not self.client:
      return []

    try:
      query_job = self.client.query(GET_POLICIES_QUERY)
      results = query_job.result()

      policies = []
      for row in results:
        policies.append(
          {
            'id': row.id,
            'filename': row.filename,
            'file_size': int(row.file_size),
            'uploaded_at': row.uploaded_at.strftime('%Y-%m-%d %H:%M:%S'),
            'embedding_count': (int(row.embedding_count) if row.embedding_count else 0),
          }
        )

      return policies

    except bigquery.exceptions.BigQueryError as e:
      logger.error('Error fetching policies: %s', e)
      return []

  def delete_policy(self, policy_id: str) -> bool:
    """Delete a policy and its embeddings.

    Uses a soft-delete fallback if BigQuery prevents deletion (e.g. streaming buffer).
    """
    if not self.client:
      raise RuntimeError('BigQuery client not initialized')

    job_config = bigquery.QueryJobConfig(
      query_parameters=[
        bigquery.ScalarQueryParameter('policy_id', 'STRING', policy_id),
      ]
    )

    try:
      # 1. Try full deletion (preferred)
      try:
        # Delete embeddings
        self.client.query(DELETE_POLICY_EMBEDDINGS_QUERY, job_config=job_config).result()
        # Delete policy record
        self.client.query(DELETE_POLICY_QUERY, job_config=job_config).result()
        logger.info('Successfully performed full deletion for policy %s', policy_id)
        return True
      except Exception as e:
        # 2. Fallback to soft-delete if full deletion fails (e.g. due to streaming buffer)
        logger.warning(
          'Full deletion failed for %s (likely streaming buffer), falling back to soft-delete. Error: %s',
          policy_id, e
        )
        return self._mark_policy_deleted(policy_id, job_config)

    except Exception as e:
      logger.error('Critical error in delete_policy for %s: %s', policy_id, e)
      raise

  def _mark_policy_deleted(self, policy_id: str, job_config: bigquery.QueryJobConfig) -> bool:
    """Workaround for streaming buffer: mark policy as deleted instead of removing it."""
    if not self.client:
      return False

    query_job = self.client.query(
      MARK_POLICY_DELETED_QUERY, job_config=job_config
    )
    query_job.result()
    logger.info(
      'Marked policy %s as deleted (streaming buffer limitation)',
      policy_id,
    )
    return True
