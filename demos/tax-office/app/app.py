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
"""Tax Office Predictions Dashboard.

Flask web application for monitoring tax anomaly predictions
"""

import datetime
import logging
import os
from backend.bigquery_client import BigQueryClient
from backend.embedding_service import get_embedding_service
from flask import Flask, jsonify, redirect, render_template, request, session, url_for
import requests
from werkzeug import utils

secure_filename = utils.secure_filename
Datetime = datetime.datetime

app = Flask(
  __name__,
  template_folder='frontend/templates',
  static_folder='frontend/static',
)
app.secret_key = os.environ.get('FLASK_SECRET_KEY', 'tax_office_demo_secret_key_2024')

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Static credentials from env or defaults
DEMO_USERNAME = os.environ.get('APP_USERNAME', 'demo')
DEMO_PASSWORD = os.environ.get('APP_PASSWORD', 'demobq')  # pragma: allowlist secret

LLM_SERVICE_URL = os.getenv('LLM_SERVICE_URL', 'http://llm-service:8000')
# LLM_SERVICE_URL = os.getenv('LLM_SERVICE_URL', 'http://localhost:8000')
LLM_MODEL_NAME = os.getenv('LLM_MODEL_NAME', 'google/gemma-3-27b-it')


# Initialize BigQuery client and embedding service
bq_client = BigQueryClient()
embedding_service = None  # Lazy load on first use


def get_embedding_service_instance():
  """Lazy load the embedding service."""
  global embedding_service
  if embedding_service is None:
    embedding_service = get_embedding_service()
  return embedding_service


@app.route('/')
def index():
  """Landing page."""
  if 'authenticated' in session and session['authenticated']:
    return redirect(url_for('dashboard'))
  return render_template('index.html')


@app.route('/home')
def home():
  """Home page - accessible by authenticated users."""
  is_authenticated = 'authenticated' in session and session['authenticated']
  return render_template('index.html', is_authenticated=is_authenticated)


@app.route('/login', methods=['GET', 'POST'])
def login():
  """Login page with static credentials."""
  if request.method == 'POST':
    username = request.form.get('username')
    password = request.form.get('password')

    if username == DEMO_USERNAME and password == DEMO_PASSWORD:
      session['authenticated'] = True
      session['username'] = username
      logger.info('User %s logged in successfully', username)
      return redirect(url_for('connecting'))
    else:
      logger.warning('Failed login attempt for username: %s', username)
      return render_template('login.html', error='Invalid credentials')

  return render_template('login.html')


@app.route('/connecting')
def connecting():
  """Connection animation page."""
  if 'authenticated' not in session or not session['authenticated']:
    return redirect(url_for('login'))

  return render_template('connecting.html', username=session.get('username'))


@app.route('/logout')
def logout():
  """Logout and clear session."""
  session.clear()
  logger.info('User logged out')
  return redirect(url_for('index'))


@app.route('/dashboard')
def dashboard():
  """Main dashboard showing predictions."""
  if 'authenticated' not in session or not session['authenticated']:
    return redirect(url_for('login'))

  return render_template('dashboard.html', username=session.get('username'))


@app.route('/api/predictions')
def api_predictions():
  """API endpoint to fetch predictions data."""
  if 'authenticated' not in session or not session['authenticated']:
    return jsonify({'error': 'Not authenticated'}), 401

  limit = request.args.get('limit', 100, type=int)
  predictions = bq_client.get_predictions(limit)
  stats = bq_client.get_stats()

  return jsonify(
    {
      'predictions': predictions,
      'stats': stats,
      'timestamp': Datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
    }
  )


@app.route('/api/detail/<taxpayer_id>/<declaration_id>')
def api_detailed_data(taxpayer_id, declaration_id):
  """API endpoint to fetch detailed data for a specific record."""
  if 'authenticated' not in session or not session['authenticated']:
    return jsonify({'error': 'Not authenticated'}), 401

  detailed_data = bq_client.get_detailed_data(taxpayer_id, declaration_id)

  if detailed_data is None:
    return jsonify({'error': 'Record not found'}), 404

  return jsonify(
    {
      'data': detailed_data,
      'timestamp': Datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
    }
  )


@app.route('/detail/<taxpayer_id>/<declaration_id>')
def detail_page(taxpayer_id, declaration_id):
  """Detailed view page for a specific taxpayer and declaration."""
  if 'authenticated' not in session or not session['authenticated']:
    return redirect(url_for('login'))

  return render_template(
    'detail.html',
    username=session.get('username'),
    taxpayer_id=taxpayer_id,
    declaration_id=declaration_id,
  )


@app.route('/policies')
def policies_page():
  """Policy management page."""
  if 'authenticated' not in session or not session['authenticated']:
    return redirect(url_for('login'))

  return render_template('policies.html', username=session.get('username'))


@app.route('/api/policies', methods=['GET'])
def api_get_policies():
  """Get all uploaded policies."""
  if 'authenticated' not in session or not session['authenticated']:
    return jsonify({'error': 'Not authenticated'}), 401

  policies = bq_client.get_policies()
  return jsonify(policies)


@app.route('/api/policies/upload', methods=['POST'])
def api_upload_policy():
  """Upload a policy file and generate embeddings."""
  if 'authenticated' not in session or not session['authenticated']:
    return jsonify({'error': 'Not authenticated'}), 401

  if 'file' not in request.files:
    return jsonify({'error': 'No file provided'}), 400

  file = request.files['file']

  if file.filename == '':
    return jsonify({'error': 'No file selected'}), 400

  if not file.filename.endswith('.txt'):
    return jsonify({'error': 'Only .txt files are supported'}), 400

  try:
    # Read file content
    filename = secure_filename(file.filename)
    content = file.read().decode('utf-8')
    file_size = len(content.encode('utf-8'))

    # Get embedding service
    emb_service = get_embedding_service_instance()

    # Process document and generate embeddings
    chunks, embeddings = emb_service.process_document(content)

    # Save to BigQuery
    policy_id = bq_client.save_policy(filename, content, file_size)

    # Convert embeddings to list format
    embeddings_list = [emb.tolist() for emb in embeddings]

    # Save embeddings
    bq_client.save_policy_embeddings(policy_id, chunks, embeddings_list)

    logger.info('Successfully uploaded policy %s with %d chunks', filename, len(chunks))

    return jsonify(
      {
        'success': True,
        'filename': filename,
        'policy_id': policy_id,
        'chunks': len(chunks),
      }
    )

  except Exception as e:
    logger.error('Error uploading policy: %s', e)
    return jsonify({'error': str(e)}), 500


@app.route('/api/policies/<policy_id>/delete', methods=['POST'])
def api_delete_policy(policy_id):
  """Delete a policy."""
  try:
    if 'authenticated' not in session or not session['authenticated']:
      return jsonify({'error': 'Not authenticated'}), 401

    bq_client.delete_policy(policy_id)
    return jsonify({'success': True, 'message': 'Policy deleted successfully'})
  except Exception as e:
    logger.error('Error in api_delete_policy: %s', e)
    return jsonify({'error': str(e)}), 500


@app.route('/api/similarity/<taxpayer_id>/<declaration_id>', methods=['GET'])
def api_check_similarity(taxpayer_id, declaration_id):
  """Check policy similarity for an anomaly."""
  if 'authenticated' not in session or not session['authenticated']:
    return jsonify({'error': 'Not authenticated'}), 401

  try:
    # Get detailed data to check if it's an anomaly
    detailed_data = bq_client.get_detailed_data(taxpayer_id, declaration_id)

    if not detailed_data:
      return jsonify({'error': 'Record not found'}), 404

    # Get prediction data to check predicted_is_anomaly
    prediction_data = bq_client.get_prediction_for_taxpayer(taxpayer_id, declaration_id)

    logger.info('Checking similarity for %s/%s', taxpayer_id, declaration_id)
    logger.info('Prediction data: %s', prediction_data)

    # Only check similarity if it's predicted as anomaly
    if not prediction_data or not prediction_data.get('predicted_is_anomaly'):
      logger.info('Not an anomaly, skipping similarity check')
      return jsonify(
        {
          'is_anomaly': False,
          'message': 'No policy violation check needed for normal transactions',
        }
      )

    # Get embedding service
    emb_service = get_embedding_service_instance()

    # Create query text from detailed data
    query_parts = []
    if (
      detailed_data.get('has_crypto_account')
      and detailed_data.get('declared_crypto_income', 0) == 0
    ):
      query_parts.append(
        'Taxpayer has cryptocurrency account on'
        f' {detailed_data.get("crypto_exchange_name", "unknown exchange")}'
        ' but declared zero crypto income'
      )
    if detailed_data.get('is_late_filing'):
      query_parts.append(
        f'Late filing by {detailed_data.get("days_filing_delay", 0)} days'
      )
    if detailed_data.get('is_late_payment'):
      query_parts.append(
        f'Late payment by {detailed_data.get("days_payment_delay", 0)} days'
      )
    if detailed_data.get('deduction_ratio', 0) > 0.5:
      query_parts.append(
        f'High deduction ratio of {detailed_data.get("deduction_ratio", 0):.2%}'
      )

    query_text = '. '.join(query_parts) if query_parts else 'Tax anomaly detected'

    # Get query embedding
    query_embedding = emb_service.generate_embeddings([query_text])[0]

    # Use BigQuery VECTOR_SEARCH for fast similarity search
    result = bq_client.vector_search_similar_policy(query_embedding.tolist(), top_k=10)

    if not result:
      return jsonify(
        {
          'is_anomaly': True,
          'similarity': None,
          'message': 'No policies found for similar to this violation',
        }
      )

    # Use VECTOR_SEARCH result with full policy
    # Return both the matched chunk (for display) and full policy (for context)
    return jsonify(
      {
        'is_anomaly': True,
        'similarity_score': result['similarity_score'],
        'violated_policy': result['text_chunk'],  # Matched chunk for display
        'full_policy': result['full_policy'],  # Complete policy document
        'policy_filename': result['filename'],  # Policy filename
        'matched_chunk_index': result['chunk_index'],  # Position of match
        'query_description': query_text,
      }
    )

  except Exception as e:
    logger.error('Error checking similarity: %s', e)
    return jsonify({'error': str(e)}), 500


@app.route('/api/llm/chat', methods=['POST'])
def api_llm_chat():
  """Chat endpoint that forwards requests to the LLM service."""
  if 'authenticated' not in session or not session['authenticated']:
    return jsonify({'error': 'Not authenticated'}), 401

  try:
    data = request.get_json()
    message = data.get('message', '')
    policy_context = data.get('policy_context')
    history = data.get('history', [])

    if not message:
      return jsonify({'error': 'No message provided'}), 400

    # Build the prompt with policy context
    system_prompt = """You are a knowledgeable tax policy assistant helping users understand tax regulations, filing requirements, deductions, penalties, and other tax-related topics.
When a policy document is provided, use it as your primary reference to answer questions accurately. You may also use your general knowledge about tax laws to provide additional context, explanations, or related information that helps users better understand the topic.
Your responses should be:
- Clear and educational
- Based on the policy document when available
- Enhanced with your knowledge to provide complete understanding
- Professional and helpful
- Concise but thorough"""

    # Build context section
    context_section = ''
    if policy_context and policy_context.get('content'):
      context_section = (
        '\n\nPolicy Document'
        f' ({policy_context.get("filename", "Unknown")}):\n{policy_context["content"]}\n'
      )

    # Build conversation history
    history_text = ''
    if history:
      for msg in history[-6:]:  # Include last 6 messages for context
        role = msg.get('role', 'user')
        content = msg.get('content', '')
        if role == 'user':
          history_text += f'\nUser: {content}'
        elif role == 'assistant':
          history_text += f'\nAssistant: {content}'

    # Construct the full prompt
    full_prompt = (
      f'{system_prompt}{context_section}{history_text}\n\nUser: {message}\n\nAssistant:'
    )

    # Prepare request to LLM service
    llm_request = {
      'model': LLM_MODEL_NAME,
      'prompt': full_prompt,
      'max_tokens': 10000,
      'temperature': 0.7,
      'top_p': 0.9,
      'stop': ['User:', '\n\nUser:'],
    }

    logger.info('Sending request to LLM service at %s', LLM_SERVICE_URL)

    # Send request to vLLM service
    response = requests.post(
      f'{LLM_SERVICE_URL}/v1/completions', json=llm_request, timeout=30
    )

    if not response.ok:
      logger.error(
        'LLM service returned error: %s - %s',
        response.status_code,
        response.text,
      )
      return (
        jsonify({'error': f'LLM service error: {response.status_code}'}),
        500,
      )

    llm_response = response.json()

    # Extract the generated text
    if 'choices' in llm_response and len(llm_response['choices']) > 0:
      assistant_response = llm_response['choices'][0]['text'].strip()

      return jsonify({'response': assistant_response, 'model': LLM_MODEL_NAME})
    else:
      logger.error('Unexpected LLM response format: %s', llm_response)
      return jsonify({'error': 'Invalid response from LLM service'}), 500

  except requests.exceptions.Timeout:
    logger.error('LLM service request timed out')
    return jsonify({'error': 'Request to LLM service timed out'}), 504
  except requests.exceptions.ConnectionError:
    logger.error('Could not connect to LLM service at %s', LLM_SERVICE_URL)
    return (
      jsonify(
        {'error': ('Could not connect to LLM service. Please ensure it is running.')}
      ),
      503,
    )
  except Exception as e:
    logger.error('Error in chat endpoint: %s', e)
    return jsonify({'error': str(e)}), 500


@app.route('/health')
def health():
  """Health check endpoint."""
  return jsonify(
    {
      'status': 'healthy',
      'bigquery_connected': bq_client.client is not None,
      'timestamp': Datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
    }
  )


if __name__ == '__main__':
  app.run(debug=True, host='0.0.0.0', port=5001)
