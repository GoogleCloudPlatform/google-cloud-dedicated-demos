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
"""Unit tests for EmbeddingService."""

import unittest
from unittest import mock
import numpy as np
from . import embedding_service as embbed


class EmbeddingServiceTest(unittest.TestCase):
  """Tests for EmbeddingService class."""

  @mock.patch.object(embbed, 'TextEmbedding', autospec=True)
  def test_init_success(self, mock_text_embedding):
    """Test successful initialization of EmbeddingService."""
    # Act
    service = embbed.EmbeddingService()
    # Assert
    self.assertIsNotNone(service.model)
    mock_text_embedding.assert_called_once_with(
      model_name='sentence-transformers/all-MiniLM-L6-v2'
    )
    self.assertEqual(service.embedding_dim, 384)

  @mock.patch.object(embbed, 'TextEmbedding', autospec=True)
  def test_init_failure(self, mock_text_embedding):
    """Test initialization failure of EmbeddingService."""
    # Arrange
    mock_text_embedding.side_effect = Exception('Model not found')
    # Act & Assert
    with self.assertRaisesRegex(RuntimeError, 'Failed to initialize embedding model'):
      embbed.EmbeddingService()

  def test_chunk_text_short(self):
    """Test chunking text shorter than chunk_size."""
    # Arrange
    service = mock.MagicMock(spec=embbed.EmbeddingService)
    text = ['Short text']
    service.chunk_text.return_value = text
    # Act
    chunks = service.chunk_text(text, chunk_size=50)
    # Assert
    self.assertEqual(chunks, ['Short text'])

  def test_chunk_text_long(self):
    """Test chunking text longer than chunk_size with overlap."""
    # Arrange
    service = mock.MagicMock(spec=embbed.EmbeddingService)
    service.chunk_text.return_value = ['abcdefghij', 'fghijklmno', 'klmno']
    # Act
    text = 'abcdefghijklmno'
    chunks = service.chunk_text(text, chunk_size=10, overlap=5)
    # Assert
    self.assertEqual(chunks, ['abcdefghij', 'fghijklmno', 'klmno'])

  def test_chunk_text_empty(self):
    """Test chunking empty text."""
    # Arrange
    service = mock.MagicMock(spec=embbed.EmbeddingService)
    # Act
    chunks = embbed.EmbeddingService.chunk_text(service, '', chunk_size=10)
    # Assert
    self.assertEqual(chunks, [])

  @mock.patch.object(embbed, 'TextEmbedding', autospec=True, spec_set=True)
  def test_generate_embeddings(self, mock_text_embedding):
    """Test generating embeddings."""
    # Arrange
    mock_model_instance = mock_text_embedding.return_value
    mock_model_instance.embed.return_value = iter([np.zeros(384), np.ones(384)])
    # Act
    service = embbed.EmbeddingService()
    texts = ['text1', 'text2']
    embeddings = service.generate_embeddings(texts)
    # Assert
    self.assertIsInstance(embeddings, np.ndarray)
    self.assertEqual(embeddings.shape, (2, 384))
    np.testing.assert_array_equal(embeddings[0], np.zeros(384))
    np.testing.assert_array_equal(embeddings[1], np.ones(384))
    mock_model_instance.embed.assert_called_once_with(texts)

  @mock.patch.object(embbed, 'TextEmbedding', autospec=True, spec_set=True)
  @mock.patch.object(
    embbed.EmbeddingService,
    'chunk_text',
    return_value=['Sample document content.'],
    autospec=True,
  )
  def test_process_document(self, mock_chunk_text, mock_text_embedding):
    """Test processing a document."""
    # Arrange
    mock_model = mock_text_embedding.return_value
    mock_model.embed.return_value = iter([np.zeros(384)])
    # Act
    service = embbed.EmbeddingService()
    text = 'Sample document content.'
    chunks, embeddings = service.process_document(text)
    # Assert
    mock_chunk_text.assert_called_once_with(service, text)
    self.assertEqual(chunks, ['Sample document content.'])
    self.assertIsInstance(embeddings, np.ndarray)
    self.assertEqual(embeddings.shape, (1, 384))
    mock_model.embed.assert_called_once_with(['Sample document content.'])

  @mock.patch.object(embbed, 'TextEmbedding', autospec=True, spec_set=True)
  def test_get_embedding_service_singleton(self, mock_text_embedding):
    """Test that get_embedding_service returns a singleton."""
    # Arrange
    # Reset global instance for test
    embbed._embedding_service = None
    # Act
    service1 = embbed.get_embedding_service()
    service2 = embbed.get_embedding_service()
    # Assert
    self.assertIs(service1, service2)
    mock_text_embedding.assert_called_once()
