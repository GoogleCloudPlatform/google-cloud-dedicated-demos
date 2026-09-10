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
let refreshInterval;
let isRefreshing = false;

// Re-render table when language switches
window.addEventListener("languageChanged", function () {
  if (window.cachedPredictions) {
    updateTable(window.cachedPredictions);
  }
  const refreshBtn = document.getElementById("refresh-btn");
  if (refreshBtn && !isRefreshing) {
    refreshBtn.innerHTML = `<span class="material-icons">refresh</span> ${window.i18n ? window.i18n.t("dashboard.refresh") : "Refresh Now"}`;
  }
});

// Initialize the dashboard
document.addEventListener("DOMContentLoaded", function () {
  refreshData();
  setupAutoRefresh();
});

// Setup auto-refresh functionality
function setupAutoRefresh() {
  const autoRefreshCheckbox = document.getElementById("auto-refresh");

  autoRefreshCheckbox.addEventListener("change", function () {
    if (this.checked) {
      startAutoRefresh();
    } else {
      stopAutoRefresh();
    }
  });

  // Start auto-refresh by default
  if (autoRefreshCheckbox.checked) {
    startAutoRefresh();
  }
}

function startAutoRefresh() {
  refreshInterval = setInterval(refreshData, 30000); // 30 seconds
}

function stopAutoRefresh() {
  if (refreshInterval) {
    clearInterval(refreshInterval);
  }
}

// Refresh data from API
async function refreshData() {
  if (isRefreshing) return;

  isRefreshing = true;
  const refreshBtn = document.getElementById("refresh-btn");
  refreshBtn.disabled = true;
  const refreshingTxt = window.i18n
    ? window.i18n.t("dashboard.refreshing")
    : "Refreshing...";
  refreshBtn.innerHTML = `<span class="material-icons">refresh</span> ${refreshingTxt}`;

  try {
    // Check for preloaded data from connecting page
    const preloadedData = sessionStorage.getItem("preloadedPredictions");
    let data;

    if (preloadedData) {
      // Use preloaded data for instant load
      data = JSON.parse(preloadedData);
      sessionStorage.removeItem("preloadedPredictions"); // Clear after use
      console.log("Using preloaded predictions data");
    } else {
      // Fetch fresh data from API
      const response = await fetch("/api/predictions");
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }
      data = await response.json();
    }

    updateStats(data.stats);
    updateTable(data.predictions);
    updateLastUpdated(data.timestamp);
    hideError();
  } catch (error) {
    console.error("Error fetching predictions:", error);
    showError(`Failed to fetch predictions: ${error.message}`);
  } finally {
    isRefreshing = false;
    refreshBtn.disabled = false;
    const refreshTxt = window.i18n
      ? window.i18n.t("dashboard.refresh")
      : "Refresh Now";
    refreshBtn.innerHTML = `<span class="material-icons">refresh</span> ${refreshTxt}`;
  }
}

// Update statistics cards
function updateStats(stats) {
  document.getElementById("total-predictions").textContent =
    stats.total_predictions || 0;
  document.getElementById("predicted-anomalies").textContent =
    stats.predicted_anomalies || 0;
  document.getElementById("avg-probability").textContent = (
    stats.avg_probability || 0
  ).toFixed(3);
  document.getElementById("max-probability").textContent = (
    stats.max_probability || 0
  ).toFixed(3);
}

// Update predictions table
function updateTable(predictions) {
  window.cachedPredictions = predictions;
  const tbody = document.getElementById("predictions-tbody");
  const table = document.getElementById("predictions-table");
  const loading = document.getElementById("loading");

  if (predictions.length === 0) {
    loading.textContent = window.i18n
      ? window.i18n.t("dashboard.table.no_data")
      : "No predictions available";
    loading.style.display = "block";
    table.style.display = "none";
    return;
  }

  tbody.innerHTML = "";

  const yesTxt = window.i18n ? window.i18n.t("common.yes") : "Yes";
  const noTxt = window.i18n ? window.i18n.t("common.no") : "No";

  predictions.forEach((prediction) => {
    const row = document.createElement("tr");
    const probability = prediction.anomaly_probability;
    const percentageValue = (probability * 100).toFixed(1);

    row.innerHTML = `
            <td>${escapeHtml(prediction.taxpayer_id)}</td>
            <td>${escapeHtml(prediction.declaration_id)}</td>
            <td>
                <span class="anomaly-badge ${prediction.predicted_is_anomaly ? "anomaly-true" : "anomaly-false"}">
                    ${prediction.predicted_is_anomaly ? yesTxt : noTxt}
                </span>
            </td>
            <td>
                <div class="probability-container">
                    <div class="probability-bar">
                        <div class="probability-fill" style="width: ${percentageValue}%"></div>
                    </div>
                    <span class="probability-text">${percentageValue}%</span>
                </div>
            </td>
            <td>${prediction.last_updated || "Unknown"}</td>
        `;

    // Add click event listener to navigate to detail page
    row.addEventListener("click", function () {
      window.location.href = `/detail/${encodeURIComponent(prediction.taxpayer_id)}/${encodeURIComponent(prediction.declaration_id)}`;
    });

    tbody.appendChild(row);
  });

  loading.style.display = "none";
  table.style.display = "table";
}

// Update last updated timestamp
function updateLastUpdated(timestamp) {
  document.getElementById("last-updated").textContent = timestamp || "Unknown";
}

// Show error message
function showError(message) {
  const errorDiv = document.getElementById("error");
  errorDiv.textContent = message;
  errorDiv.style.display = "block";

  const loading = document.getElementById("loading");
  const table = document.getElementById("predictions-table");
  loading.style.display = "none";
  table.style.display = "none";
}

// Hide error message
function hideError() {
  document.getElementById("error").style.display = "none";
}

// Escape HTML to prevent XSS
function escapeHtml(text) {
  const div = document.createElement("div");
  div.textContent = text;
  return div.innerHTML;
}

// Clean up on page unload
window.addEventListener("beforeunload", function () {
  stopAutoRefresh();
});
