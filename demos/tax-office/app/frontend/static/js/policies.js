/*
 * Copyright 2026 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     https://www.apache.org/licenses/LICENSE-2.0
 *
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
// Initialize the policies page
document.addEventListener("DOMContentLoaded", function () {
  setupPolicyUpload();
  loadPolicies();
});

// Setup policy upload functionality
function setupPolicyUpload() {
  const uploadBtn = document.getElementById("upload-policy-btn");
  const fileInput = document.getElementById("policy-file-input");

  uploadBtn.addEventListener("click", function () {
    fileInput.click();
  });

  fileInput.addEventListener("change", async function (e) {
    const files = Array.from(e.target.files);
    if (files.length === 0) return;

    // Validate all files
    const invalidFiles = [];
    const validFiles = [];

    for (const file of files) {
      if (!file.name.endsWith(".txt")) {
        invalidFiles.push(`${file.name} (not a .txt file)`);
      } else if (file.size > 10 * 1024 * 1024) {
        invalidFiles.push(`${file.name} (exceeds 10MB)`);
      } else {
        validFiles.push(file);
      }
    }

    // Show validation errors if any
    if (invalidFiles.length > 0) {
      showUploadStatus(
        `Skipped ${invalidFiles.length} file(s): ${invalidFiles.join(", ")}`,
        "error",
      );

      // If no valid files, stop here
      if (validFiles.length === 0) {
        fileInput.value = ""; // Reset input
        return;
      }
    }

    // Upload all valid files
    await uploadMultiplePolicies(validFiles);
    fileInput.value = ""; // Reset input
  });
}

async function uploadMultiplePolicies(files) {
  const totalFiles = files.length;
  let successCount = 0;
  let failCount = 0;
  const failedFiles = [];

  showLoadingOverlay(
    "Uploading Policies",
    `Preparing to upload ${totalFiles} file(s)...`,
  );

  // Upload files sequentially to avoid overwhelming the server
  for (let i = 0; i < files.length; i++) {
    const file = files[i];
    updateLoadingProgress(`Uploading ${i + 1}/${totalFiles}: ${file.name}`);

    try {
      const formData = new FormData();
      formData.append("file", file);

      const response = await fetch("/api/policies/upload", {
        method: "POST",
        body: formData,
      });

      if (!response.ok) {
        const error = await response.json();
        throw new Error(error.error || "Upload failed");
      }

      successCount++;
    } catch (error) {
      console.error(`Upload error for ${file.name}:`, error);
      failCount++;
      failedFiles.push(file.name);
    }
  }

  // Show completion message
  if (failCount === 0) {
    updateLoadingProgress(`Successfully uploaded ${successCount} file(s)!`);
  } else if (successCount === 0) {
    updateLoadingProgress(`Failed to upload all ${failCount} file(s)`);
  } else {
    updateLoadingProgress(
      `Uploaded ${successCount} file(s), ${failCount} failed`,
    );
  }

  // Reload policies list
  await new Promise((resolve) => setTimeout(resolve, 1000));
  await loadPolicies();
  hideLoadingOverlay();
}

async function loadPolicies() {
  const container = document.getElementById("policies-container");
  container.innerHTML =
    '<div class="loading-policies">Loading policies...</div>';

  try {
    const response = await fetch("/api/policies");
    if (!response.ok) {
      throw new Error("Failed to load policies");
    }

    const policies = await response.json();

    if (policies.length === 0) {
      container.innerHTML =
        '<div class="loading-policies">No policies uploaded yet. Upload your first policy document to get started!</div>';
      return;
    }

    container.innerHTML = "";
    policies.forEach((policy) => {
      const policyCard = document.createElement("div");
      policyCard.className = "policy-card";
      policyCard.innerHTML = `
                <div class="policy-card-header">
                    <div class="policy-card-icon">
                        <span class="material-icons">description</span>
                        <div class="policy-card-title">${escapeHtml(policy.filename)}</div>
                    </div>
                    <button class="policy-card-delete" onclick="deletePolicy('${escapeHtml(policy.id)}', '${escapeHtml(policy.filename)}')">
                        <span class="material-icons">delete</span>
                    </button>
                </div>
                <div class="policy-card-meta">
                    <div class="policy-meta-item">
                        <span class="policy-meta-label">File Size:</span>
                        <span class="policy-meta-value">${formatFileSize(policy.file_size)}</span>
                    </div>
                    <div class="policy-meta-item">
                        <span class="policy-meta-label">Embeddings:</span>
                        <span class="policy-meta-value">${policy.embedding_count}</span>
                    </div>
                </div>
                <div class="policy-card-footer">
                    Uploaded: ${policy.uploaded_at}
                </div>
            `;
      container.appendChild(policyCard);
    });
  } catch (error) {
    console.error("Error loading policies:", error);
    container.innerHTML =
      '<div class="loading-policies">Failed to load policies. Please try again.</div>';
  }
}

function showDeleteModal(policyId, filename) {
  const modal = document.getElementById("delete-modal");
  const filenameElement = document.getElementById("delete-filename");
  const confirmButton = document.getElementById("confirm-delete-btn");

  filenameElement.textContent = filename;
  modal.style.display = "flex";

  // Remove old event listeners and add new one
  const newConfirmButton = confirmButton.cloneNode(true);
  confirmButton.parentNode.replaceChild(newConfirmButton, confirmButton);

  newConfirmButton.addEventListener("click", async () => {
    hideDeleteModal();
    await executePolicyDelete(policyId);
  });

  // Close modal when clicking overlay
  const overlay = modal.querySelector(".modal-overlay");
  overlay.onclick = hideDeleteModal;
}

function hideDeleteModal() {
  const modal = document.getElementById("delete-modal");
  modal.style.display = "none";
}

async function deletePolicy(policyId, filename) {
  showDeleteModal(policyId, filename);
}

async function executePolicyDelete(policyId) {
  showLoadingOverlay("Deleting Policy", "Removing policy and embeddings...");

  try {
    const response = await fetch(`/api/policies/${policyId}`, {
      method: "DELETE",
    });

    const result = await response.json();

    if (!response.ok) {
      throw new Error(result.error || "Failed to delete policy");
    }

    updateLoadingProgress("Policy deleted successfully!");
    await new Promise((resolve) => setTimeout(resolve, 1000));

    // Reload policies list
    await loadPolicies();
    hideLoadingOverlay();
  } catch (error) {
    console.error("Error deleting policy:", error);
    updateLoadingProgress("Error: " + error.message);
    await new Promise((resolve) => setTimeout(resolve, 3000));
    hideLoadingOverlay();
  }
}

function formatFileSize(bytes) {
  if (bytes < 1024) return bytes + " B";
  if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + " KB";
  return (bytes / (1024 * 1024)).toFixed(1) + " MB";
}

// Escape HTML to prevent XSS
function escapeHtml(text) {
  const div = document.createElement("div");
  div.textContent = text;
  return div.innerHTML;
}

// Loading overlay functions
function showLoadingOverlay(message, progress) {
  const overlay = document.getElementById("loading-overlay");
  const messageElement = document.getElementById("loading-message");
  const progressElement = document.getElementById("loading-progress");

  messageElement.textContent = message;
  progressElement.textContent = progress || "";
  overlay.style.display = "flex";
}

function updateLoadingProgress(progress) {
  const progressElement = document.getElementById("loading-progress");
  progressElement.textContent = progress;
}

function hideLoadingOverlay() {
  const overlay = document.getElementById("loading-overlay");
  overlay.style.display = "none";
}
