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
"""Embedding Service for Policy Documents.

Uses fastembed for ultra-fast embedding generation with ONNX runtime
"""

import logging
import os
from typing import List, Tuple
import fastembed
import numpy as np

TextEmbedding = fastembed.TextEmbedding
logger = logging.getLogger(__name__)

DEFAULT_MODEL = os.environ.get(
  'EMBEDDING_MODEL_NAME', 'sentence-transformers/all-MiniLM-L6-v2'
)


class EmbeddingService:
  """Service for generating embeddings using fastembed."""

  def __init__(self, model_name: str = DEFAULT_MODEL):
    """Initialize the embedding service.

    Args:
        model_name: Name of the fastembed model
          'sentence-transformers/all-MiniLM-L6-v2' is fast and efficient (384
          dimensions)
    """
    logger.info('Loading embedding model: %s', model_name)

    try:
      # Model is pre-downloaded during Docker build
      # No need for custom cache directory handling
      self.model = TextEmbedding(model_name=model_name)
      self.embedding_dim = 384  # Standard dimension for these models
      logger.info(
        'Model loaded successfully. Embedding dimension: %s',
        self.embedding_dim,
      )
    except Exception as e:
      logger.error('Failed to load model: %s', e)
      raise RuntimeError(f'Failed to initialize embedding model: {e}') from e

  def chunk_text(
    self, text: str, chunk_size: int = 500, overlap: int = 50
  ) -> List[str]:
    """Split text into overlapping chunks.

    Args:
        text: Input text to chunk
        chunk_size: Maximum characters per chunk
        overlap: Number of characters to overlap between chunks

    Returns:
        List of text chunks
    """
    chunks = []
    start = 0
    text_len = len(text)

    while start < text_len:
      end = start + chunk_size
      chunk = text[start:end].strip()

      if chunk:
        chunks.append(chunk)

      start += chunk_size - overlap

    return chunks

  def generate_embeddings(self, texts: List[str]) -> np.ndarray:
    """Generate embeddings for a list of texts.

    Args:
        texts: List of text strings

    Returns:
        numpy array of embeddings (shape: [len(texts), embedding_dim])
    """
    # fastembed returns a generator, convert to list then numpy array
    embeddings_generator = self.model.embed(texts)
    embeddings_list = list(embeddings_generator)
    embeddings = np.array(embeddings_list)
    return embeddings

  def process_document(self, text: str) -> Tuple[List[str], np.ndarray]:
    """Process a document by chunking and generating embeddings.

    Args:
        text: Document text

    Returns:
        Tuple of (chunks, embeddings)
    """
    chunks = self.chunk_text(text)
    embeddings = self.generate_embeddings(chunks)
    return chunks, embeddings


# Global instance
_embedding_service = None


def get_embedding_service() -> EmbeddingService:
  """Get or create the global embedding service instance."""
  global _embedding_service
  if _embedding_service is None:
    _embedding_service = EmbeddingService()
  return _embedding_service
