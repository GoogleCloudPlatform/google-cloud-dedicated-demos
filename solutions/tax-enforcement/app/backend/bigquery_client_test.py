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
import datetime
import unittest
from unittest import mock
import uuid

from google.cloud import bigquery

from . import bigquery_client as bq

Datetime = datetime.datetime


class BqClientTest(unittest.TestCase):
  def test_get_predictions(self):
    # Arrange
    mock_bq_client = mock.create_autospec(bigquery.Client, instance=True)
    # Create mock row data
    mock_row_attrs = {
      'taxpayer_id': 'taxpayer1',
      'declaration_id': 'declaration1',
      'predicted_is_anomaly': True,
      'anomaly_probability': 0.99,
      'last_updated': Datetime(2023, 10, 1, 10, 0, 0),
    }
    # Create the mock row and set attributes
    mock_row = mock.MagicMock(**mock_row_attrs)
    mock_bq_client.query.return_value.result.return_value = [mock_row]
    # Act
    client = bq.BigQueryClient(client=mock_bq_client)
    predictions = client.get_predictions(limit=1)
    # Assert
    self.assertEqual(len(predictions), 1)
    self.assertEqual(predictions[0]['taxpayer_id'], 'taxpayer1')
    self.assertEqual(predictions[0]['anomaly_probability'], 0.99)
    mock_bq_client.query.assert_called_once()

  def test_get_prediction_for_taxpayer(self):
    # Arrange
    mock_bq_client = mock.create_autospec(bigquery.Client, instance=True)
    # Create mock row data
    mock_row_attrs = {
      'taxpayer_id': 'tp1',
      'declaration_id': 'dec1',
      'predicted_is_anomaly': False,
      'anomaly_probability': 0.123,
    }
    # Create the mock row and set attributes
    mock_row = mock.MagicMock(**mock_row_attrs)
    mock_bq_client.query.return_value.result.return_value = [mock_row]
    # Act
    client = bq.BigQueryClient(client=mock_bq_client)
    predictions = client.get_prediction_for_taxpayer('tp1', 'dec1')
    # Assert
    self.assertIsNotNone(predictions)
    self.assertEqual(predictions['taxpayer_id'], 'tp1')
    self.assertEqual(predictions['anomaly_probability'], 0.123)
    mock_bq_client.query.assert_called_once()

  def test_get_stats(self):
    # Arrange
    mock_bq_client = mock.create_autospec(bigquery.Client, instance=True)
    # Create mock row data
    mock_row_attrs = {
      'total_predictions': 1000,
      'predicted_anomalies': 100,
      'avg_probability': 0.12345,
      'max_probability': 0.98765,
    }
    # Create the mock row and set attributes
    mock_row = mock.MagicMock(**mock_row_attrs)
    mock_bq_client.query.return_value.result.return_value = [mock_row]
    # Act
    client = bq.BigQueryClient(client=mock_bq_client)
    stats = client.get_stats()
    # Assert
    self.assertEqual(stats['total_predictions'], 1000)
    self.assertEqual(stats['avg_probability'], 0.1235)
    mock_bq_client.query.assert_called_once()

  def test_get_detailed_data(self):
    # Arrange
    mock_bq_client = mock.create_autospec(bigquery.Client, instance=True)
    # Define all attributes for the mock row
    mock_row_attrs = {
      'taxpayer_id': 'tp1',
      'declaration_id': 'dec1',
      'tax_year': 2023,
      'taxpayer_type': 'INDIVIDUAL',
      'industry_code': '123',
      'address_state': 'CA',
      'first_name': 'John',
      'last_name': 'Doe',
      'company_name': None,
      'date_of_birth': Datetime(1990, 1, 1, 0, 0, 0).date(),
      'gross_income': 100000.0,
      'taxable_income': 80000.0,
      'total_deductions': 20000.0,
      'calculated_tax': 10000.0,
      'has_crypto_account': True,
      'crypto_exchange_name': 'Coinbase',
      'crypto_account_verified_date': Datetime(2022, 1, 1, 0, 0, 0).date(),
      'declared_crypto_income': 5000.0,
      'crypto_transaction_count': 50,
      'has_declared_crypto_previously': False,
      'deduction_ratio': 0.2,
      'tax_ratio': 0.125,
      'crypto_income_ratio': 0.05,
      'is_crypto_non_declarant': False,
      'crypto_risk_score': 0.5,
      'filing_date': Datetime(2024, 4, 1, 0, 0, 0).date(),
      'is_late_filing': False,
      'has_amendments': False,
      'days_filing_delay': 0,
      'is_late_payment': False,
      'days_payment_delay': 0,
      'payment_date': Datetime(2024, 4, 1, 0, 0, 0).date(),
      'late_filing_rate': 0.0,
      'late_payment_rate': 0.0,
      'amendment_rate': 0.0,
      'income_volatility': 0.1,
      'avg_deduction_ratio': 0.2,
      'is_anomaly': False,
      'anomaly_type': None,
      'anomaly_confidence': 0.1,
      'data_source': 'TestSource',
      'created_at': Datetime(2024, 1, 1, 0, 0, 0),
      'updated_at': Datetime(2024, 1, 1, 0, 0, 0),
    }
    # Create the mock row and set attributes
    mock_row = mock.MagicMock(**mock_row_attrs)
    mock_bq_client.query.return_value.result.return_value = [mock_row]
    # Act
    client = bq.BigQueryClient(client=mock_bq_client)
    data = client.get_detailed_data('tp1', 'dec1')
    # Assert
    self.assertIsNotNone(data)
    self.assertEqual(data['taxpayer_id'], 'tp1')
    self.assertEqual(data['date_of_birth'], '1990-01-01')
    self.assertEqual(data['gross_income'], 100000.0)
    mock_bq_client.query.assert_called_once()

  def test_vector_search_similar_policy(self):
    # Arrange
    mock_bq_client = mock.create_autospec(bigquery.Client, instance=True)
    # Create mock row data
    mock_row_attrs = {
      'distance': 0.1,
      'text_chunk': 'chunk1',
      'full_policy': 'policy content',
      'policy_id': 'pol1',
      'filename': 'policy.txt',
      'chunk_index': 0,
    }
    # Create the mock row and set attributes
    mock_row = mock.MagicMock(**mock_row_attrs)
    mock_bq_client.query.return_value.result.return_value = [mock_row]
    # Act
    client = bq.BigQueryClient(client=mock_bq_client)
    result = client.vector_search_similar_policy([0.1, 0.2], top_k=1)
    # Assert
    self.assertIsNotNone(result)
    self.assertEqual(result['policy_id'], 'pol1')
    self.assertAlmostEqual(result['similarity_score'], 1 - (0.1 / 2))
    mock_bq_client.query.assert_called_once()

  @mock.patch.object(
    uuid, 'uuid4', return_value=uuid.UUID('12345678123456781234567812345678')
  )
  def test_save_policy(self, mock_uuid):
    # Arrange
    mock_bq_client = mock.create_autospec(bigquery.Client, instance=True)
    # Create mock row data
    mock_bq_client.query.return_value.result.return_value = []
    # Act
    client = bq.BigQueryClient(client=mock_bq_client)
    policy_id = client.save_policy('policy.txt', 'content', 100)
    # Assert
    self.assertEqual(policy_id, '12345678-1234-5678-1234-567812345678')
    mock_bq_client.query.assert_called_once()
    _, kwargs = mock_bq_client.query.call_args
    params = {p.name: p.value for p in kwargs['job_config'].query_parameters}
    self.assertEqual(params['id'], '12345678-1234-5678-1234-567812345678')
    mock_uuid.assert_called_once()

  @mock.patch.object(bq, 'DATASET', 'test_dataset')
  @mock.patch.object(
    uuid, 'uuid4', return_value=uuid.UUID('12345678123456781234567812345678')
  )
  @mock.patch.object(bq, 'Datetime')
  def test_save_policy_embeddings(self, mock_datetime, mock_uuid):
    # Arrange
    mock_bq_client = mock.create_autospec(bigquery.Client, instance=True)
    mock_datetime.utcnow.return_value.isoformat.return_value = '2023-01-01T12:00:00'
    mock_bq_client.insert_rows_json.return_value = []  # Success
    mock_bq_client.query.return_value.result.return_value = []
    # Act
    client = bq.BigQueryClient(client=mock_bq_client)
    client.save_policy_embeddings('pol1', ['chunk1'], [[0.1, 0.2]])
    # Assert
    mock_bq_client.insert_rows_json.assert_called_once_with(
      'test_dataset.policy_embeddings',
      [
        {
          'id': '12345678-1234-5678-1234-567812345678',
          'policy_id': 'pol1',
          'text_chunk': 'chunk1',
          'embedding': [0.1, 0.2],
          'chunk_index': 0,
          'created_at': '2023-01-01T12:00:00',
        }
      ],
    )
    mock_bq_client.query.assert_called_once()
    mock_uuid.assert_called_once()

  def test_get_policies(self):
    # Arrange
    mock_bq_client = mock.create_autospec(bigquery.Client, instance=True)
    # Create mock row data
    mock_row_attrs = {
      'id': 'pol1',
      'filename': 'policy.txt',
      'file_size': 123,
      'uploaded_at': Datetime(2023, 1, 1, 12, 0, 0),
      'embedding_count': 10,
    }
    # Create the mock row and set attributes
    mock_row = mock.MagicMock(**mock_row_attrs)
    mock_bq_client.query.return_value.result.return_value = [mock_row]
    # Act
    client = bq.BigQueryClient(client=mock_bq_client)
    policies = client.get_policies()
    # Assert
    self.assertEqual(len(policies), 1)
    self.assertEqual(policies[0]['id'], 'pol1')
    self.assertEqual(policies[0]['embedding_count'], 10)
    mock_bq_client.query.assert_called_once()

  def test_delete_policy(self):
    # Arrange
    mock_bq_client = mock.create_autospec(bigquery.Client, instance=True)
    # Mock row data
    mock_bq_client.query.return_value.result.return_value = []
    # Act
    client = bq.BigQueryClient(client=mock_bq_client)
    result = client.delete_policy('pol1')
    # Assert
    self.assertTrue(result)
    # DELETE_POLICY_EMBEDDINGS_QUERY and DELETE_POLICY_QUERY
    self.assertEqual(mock_bq_client.query.call_count, 2)

  def test_delete_policy_streaming_buffer(self):
    # Arrange
    mock_bq_client = mock.create_autospec(bigquery.Client, instance=True)
    # First query to delete embeddings fails with streaming buffer error
    mock_bq_client.query.side_effect = [
      bigquery.exceptions.BigQueryError('streaming buffer'),
      mock.MagicMock(result=lambda: []),
    ]
    # Delete
    client = bq.BigQueryClient(client=mock_bq_client)
    result = client.delete_policy('pol1')
    # Assert
    self.assertTrue(result)
    # DELETE_POLICY_EMBEDDINGS_QUERY fails, MARK_POLICY_DELETED_QUERY is called
    self.assertEqual(mock_bq_client.query.call_count, 2)
