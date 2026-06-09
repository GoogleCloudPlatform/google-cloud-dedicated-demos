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
import io
import os
# Set environment variables for testing before importing app
os.environ['DEMO_USERNAME'] = 'test_demo_user'
os.environ['DEMO_PASSWORD'] = 'test_demo_password'
os.environ['FLASK_SECRET_KEY'] = 'test_flask_secret_key'
import unittest
from unittest import mock
import app


class AppTest(unittest.TestCase):
  """Tests for the app."""

  def setUp(self):
    super().setUp()
    app.app.config.update(
      {
        'TESTING': True,
      }
    )

  def test_basic_routes(self):
    # Arrange
    client = app.app.test_client()
    # Act
    response_root = client.get('/')
    response_home = client.get('/home')
    response_health = client.get('/health')
    # Assert
    self.assertEqual(response_root.status_code, 200)
    self.assertEqual(response_home.status_code, 200)
    self.assertIn(b'healthy', response_health.data)

  def test_login_scenarios(self):
    # Arrange
    client = app.app.test_client()
    # Act
    response_invalid_credentials = client.post(
      '/login', data={'username': 'x', 'password': 'y'}
    )
    response_valid_credentials = client.post(
      '/login',
      data={'username': app.DEMO_USERNAME, 'password': app.DEMO_PASSWORD},
    )
    # Assert
    self.assertIn(b'Invalid credentials', response_invalid_credentials.data)
    self.assertEqual(response_valid_credentials.status_code, 302)

  def test_auth_redirection(self):
    # Arrange
    client = app.app.test_client()
    # Act & Assert
    for path in ['/dashboard', '/connecting', '/policies', '/detail/tp1/dec1']:
      self.assertEqual(client.get(path).status_code, 302)

  def test_logout(self):
    # Arrange
    client = app.app.test_client()
    with client.session_transaction() as sess:
      sess['authenticated'] = True
    # Act
    client.get('/logout')
    # Assert
    with client.session_transaction() as sess:
      self.assertNotIn('authenticated', sess)

  @mock.patch('app.bq_client', autospec=True)
  def test_api_data_endpoints(self, mock_bq):
    # Arrange
    client = app.app.test_client()
    with client.session_transaction() as sess:
      sess['authenticated'] = True
    # Setup mock data instead of calling the API circularly
    mock_bq.get_predictions.return_value = [{'id': 1}]
    mock_bq.get_stats.return_value = {'total': 1}
    mock_bq.get_detailed_data.side_effect = (
      lambda t, d: {'info': 'sample'} if t == 'tp1' else None
    )

    # Act
    response = client.get('/api/predictions')
    data = response.get_json()

    # Assert
    self.assertEqual(response.status_code, 200)
    self.assertEqual(data['predictions'], [{'id': 1}])
    self.assertEqual(data['stats'], {'total': 1})

    # Test api_detailed_data success
    response = client.get('/api/detail/tp1/dec1')
    self.assertEqual(response.status_code, 200)
    self.assertEqual(response.get_json()['data'], {'info': 'sample'})

    # Test api_detailed_data 404
    response = client.get('/api/detail/x/y')
    self.assertEqual(response.status_code, 404)

  @mock.patch('app.bq_client', autospec=True)
  def test_policy_management(self, mock_bq):
    # Arrange
    client = app.app.test_client()
    with client.session_transaction() as sess:
      sess['authenticated'] = True
    mock_bq.get_policies.return_value = []
    mock_bq.delete_policy.return_value = True
    # Act
    response_policies = client.get('/api/policies')
    response_delete = client.post('/api/policies/pol1/delete')
    # Assert
    self.assertEqual(response_policies.status_code, 200)
    # The response is now a JSON with success: True
    self.assertTrue(response_delete.get_json()['success'])

  @mock.patch('app.bq_client', autospec=True)
  @mock.patch('app.get_embedding_service_instance')
  def test_upload_and_similarity(self, mock_emb_inst, mock_bq):
    # Arrange
    client = app.app.test_client()
    with client.session_transaction() as sess:
      sess['authenticated'] = True

    mock_emb = mock.Mock()
    mock_emb.process_document.return_value = (
      ['chunk'],
      [mock.Mock(tolist=lambda: [0.1])],
    )
    mock_emb_inst.return_value = mock_emb
    mock_bq.save_policy.return_value = 'pol1'
    mock_bq.get_detailed_data.return_value = {'has_crypto_account': True}
    mock_bq.get_prediction_for_taxpayer.return_value = {'predicted_is_anomaly': True}
    mock_emb.generate_embeddings.return_value = [mock.Mock(tolist=lambda: [0.1])]
    mock_bq.vector_search_similar_policy.return_value = {
      'similarity_score': 0.9,
      'text_chunk': 'r',
      'full_policy': 'p',
      'filename': 'f',
      'chunk_index': 0,
    }
    # Act
    response_upload = client.post(
      '/api/policies/upload', data={'file': (io.BytesIO(b'p'), 't.txt')}
    )
    response_similarity = client.get('/api/similarity/tp1/dec1')
    # Assert
    self.assertEqual(response_upload.status_code, 200)
    self.assertEqual(response_similarity.status_code, 200)

  @mock.patch('app.requests.post', autospec=True)
  def test_llm_chat(self, mock_post):
    # Arrange
    client = app.app.test_client()
    with client.session_transaction() as sess:
      sess['authenticated'] = True
    mock_response = mock.MagicMock()
    mock_response.ok = True
    mock_response.status_code = 200
    mock_response.json.return_value = {
      'choices': [{'text': '  AI response from Fake API  \n'}]
    }
    mock_post.return_value = mock_response

    # Act
    resp = client.post('/api/llm/chat', json={'message': 'hello'})
    resp_data = resp.get_json()

    # Assert
    self.assertIn('AI response from Fake API', resp_data['response'])
