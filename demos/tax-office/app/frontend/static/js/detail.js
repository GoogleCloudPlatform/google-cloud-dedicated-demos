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
// Initialize the detail page
document.addEventListener("DOMContentLoaded", function () {
  loadDetailedData();
});

window.addEventListener("languageChanged", function () {
  if (window.currentDetailData) {
    populateDetailedData(window.currentDetailData);
  }
});

// Load detailed data from API
async function loadDetailedData() {
  const taxpayerId = document.getElementById("taxpayer-id").textContent;
  const declarationId = document.getElementById("declaration-id").textContent;

  try {
    const response = await fetch(
      `/api/detail/${encodeURIComponent(taxpayerId)}/${encodeURIComponent(declarationId)}`,
    );

    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }

    const result = await response.json();
    window.currentDetailData = result.data;
    populateDetailedData(result.data);
    hideLoading();
    if (window.i18n && window.i18n.applyTranslations) {
      window.i18n.applyTranslations();
    }
    checkPolicyViolation(taxpayerId, declarationId);
  } catch (error) {
    console.error("Error fetching detailed data:", error);
    showError(`Failed to fetch detailed data: ${error.message}`);
  }
}

// Populate the page with detailed data
function populateDetailedData(data) {
  const naTxt = window.i18n ? window.i18n.t("common.na") : "N/A";
  // Basic Information
  const indTxt = window.i18n
    ? window.i18n.t("detail.badge.individual")
    : "INDIVIDUAL";
  const busTxt = window.i18n
    ? window.i18n.t("detail.badge.business")
    : "BUSINESS";
  const typeTxt = data.taxpayer_type === "INDIVIDUAL" ? indTxt : busTxt;
  document.getElementById("taxpayer-type").innerHTML =
    `<span class="badge ${data.taxpayer_type === "INDIVIDUAL" ? "badge-individual" : "badge-business"}">${typeTxt}</span>`;
  document.getElementById("tax-year").textContent = data.tax_year || naTxt;
  document.getElementById("industry-code").textContent =
    data.industry_code || naTxt;
  document.getElementById("address-state").textContent =
    data.address_state || naTxt;

  // Show/hide type-specific information
  if (data.taxpayer_type === "INDIVIDUAL") {
    if (data.first_name || data.last_name) {
      document.getElementById("individual-info").style.display = "flex";
      document.getElementById("full-name").textContent =
        `${data.first_name || ""} ${data.last_name || ""}`.trim() || "N/A";
    }
    if (data.date_of_birth) {
      document.getElementById("birth-date-info").style.display = "flex";
      document.getElementById("date-of-birth").textContent = data.date_of_birth;
    }
  } else if (data.taxpayer_type === "BUSINESS" && data.company_name) {
    document.getElementById("business-info").style.display = "flex";
    document.getElementById("company-name").textContent = data.company_name;
  }

  // Financial Information
  document.getElementById("gross-income").textContent = formatCurrency(
    data.gross_income,
  );
  document.getElementById("taxable-income").textContent = formatCurrency(
    data.taxable_income,
  );
  document.getElementById("total-deductions").textContent = formatCurrency(
    data.total_deductions,
  );
  document.getElementById("calculated-tax").textContent = formatCurrency(
    data.calculated_tax,
  );
  document.getElementById("deduction-ratio").textContent =
    (data.deduction_ratio * 100).toFixed(2) + "%";
  document.getElementById("tax-ratio").textContent =
    (data.tax_ratio * 100).toFixed(2) + "%";

  // Set progress bars
  setProgressBar("deduction-ratio-bar", data.deduction_ratio * 100);
  setProgressBar("tax-ratio-bar", data.tax_ratio * 100);

  // Cryptocurrency Information
  document.getElementById("has-crypto-account").innerHTML = getBooleanBadge(
    data.has_crypto_account,
  );
  document.getElementById("declared-crypto-income").textContent =
    formatCurrency(data.declared_crypto_income);
  document.getElementById("crypto-transaction-count").textContent =
    data.crypto_transaction_count;
  document.getElementById("has-declared-crypto-previously").innerHTML =
    getBooleanBadge(data.has_declared_crypto_previously);
  document.getElementById("is-crypto-non-declarant").innerHTML =
    getBooleanBadge(data.is_crypto_non_declarant);
  document.getElementById("crypto-risk-score").textContent =
    (data.crypto_risk_score * 100).toFixed(2) + "%";
  setProgressBar("crypto-risk-bar", data.crypto_risk_score * 100);

  if (data.crypto_exchange_name) {
    document.getElementById("crypto-exchange-info").style.display = "flex";
    document.getElementById("crypto-exchange-name").textContent =
      data.crypto_exchange_name;
  }
  if (data.crypto_account_verified_date) {
    document.getElementById("crypto-verified-info").style.display = "flex";
    document.getElementById("crypto-account-verified-date").textContent =
      data.crypto_account_verified_date;
  }

  // Filing & Payment Behavior
  document.getElementById("filing-date").textContent =
    data.filing_date || naTxt;
  document.getElementById("is-late-filing").innerHTML = getBooleanBadge(
    data.is_late_filing,
  );
  document.getElementById("days-filing-delay").textContent =
    data.days_filing_delay;
  document.getElementById("has-amendments").innerHTML = getBooleanBadge(
    data.has_amendments,
  );
  document.getElementById("payment-date").textContent =
    data.payment_date || naTxt;
  document.getElementById("is-late-payment").innerHTML = getBooleanBadge(
    data.is_late_payment,
  );
  document.getElementById("days-payment-delay").textContent =
    data.days_payment_delay;

  // Historical Patterns
  document.getElementById("late-filing-rate").textContent = (
    data.late_filing_rate * 100
  ).toFixed(2);
  document.getElementById("late-payment-rate").textContent = (
    data.late_payment_rate * 100
  ).toFixed(2);
  document.getElementById("amendment-rate").textContent = (
    data.amendment_rate * 100
  ).toFixed(2);
  document.getElementById("income-volatility").textContent =
    data.income_volatility.toFixed(4);
  document.getElementById("avg-deduction-ratio").textContent =
    (data.avg_deduction_ratio * 100).toFixed(2) + "%";

  setProgressBar("late-filing-rate-bar", data.late_filing_rate * 100);
  setProgressBar("late-payment-rate-bar", data.late_payment_rate * 100);
  setProgressBar("amendment-rate-bar", data.amendment_rate * 100);

  // Anomaly Detection Results
  document.getElementById("is-anomaly").innerHTML =
    data.is_anomaly !== null ? getBooleanBadge(data.is_anomaly) : naTxt;
  document.getElementById("anomaly-confidence").textContent = (
    data.anomaly_confidence * 100
  ).toFixed(2);
  document.getElementById("data-source").textContent =
    data.data_source || naTxt;
  document.getElementById("created-at").textContent = data.created_at || naTxt;
  document.getElementById("updated-at").textContent = data.updated_at || naTxt;

  setProgressBar("anomaly-confidence-bar", data.anomaly_confidence * 100);

  if (data.anomaly_type) {
    document.getElementById("anomaly-type-info").style.display = "flex";
    document.getElementById("anomaly-type").textContent = data.anomaly_type;
  }
}

// Helper functions
function formatCurrency(amount) {
  return new Intl.NumberFormat("de-DE", {
    style: "currency",
    currency: "EUR",
  }).format(amount);
}

function getBooleanBadge(value) {
  if (value === null || value === undefined) {
    return window.i18n ? window.i18n.t("common.na") : "N/A";
  }
  const yesTxt = window.i18n ? window.i18n.t("common.yes") : "Yes";
  const noTxt = window.i18n ? window.i18n.t("common.no") : "No";
  return `<span class="badge ${value ? "badge-true" : "badge-false"}">${value ? yesTxt : noTxt}</span>`;
}

function setProgressBar(elementId, percentage) {
  const element = document.getElementById(elementId);
  if (element) {
    element.style.width = Math.min(100, Math.max(0, percentage)) + "%";
  }
}

function hideLoading() {
  document.getElementById("loading").style.display = "none";
  document.getElementById("detail-content").style.display = "block";
}

function showError(message) {
  const errorDiv = document.getElementById("error");
  errorDiv.textContent = message;
  errorDiv.style.display = "block";
  document.getElementById("loading").style.display = "none";
}

// Check for policy violations
async function checkPolicyViolation(taxpayerId, declarationId) {
  const section = document.getElementById("policy-violation-section");
  const loading = document.getElementById("policy-violation-loading");
  const content = document.getElementById("policy-violation-content");
  const message = document.getElementById("policy-violation-message");

  console.log("Checking policy violation for:", taxpayerId, declarationId);

  // Show loading immediately
  section.style.display = "block";
  loading.style.display = "flex";
  content.style.display = "none";
  message.style.display = "none";

  try {
    const response = await fetch(
      `/api/similarity/${encodeURIComponent(taxpayerId)}/${encodeURIComponent(declarationId)}`,
    );

    console.log("Similarity API response status:", response.status);

    if (!response.ok) {
      const errorData = await response.json();
      console.error("Similarity API error:", errorData);
      throw new Error(errorData.error || "Failed to check policy violations");
    }

    const result = await response.json();
    console.log("Similarity API result:", result);

    // Show section only for anomalies
    if (result.is_anomaly) {
      console.log("Is anomaly, showing violation section");
      section.style.display = "block";
      loading.style.display = "none";

      if (result.violated_policy) {
        // Show violation details
        console.log("Showing violation details");
        content.style.display = "block";
        message.style.display = "none";

        const similarityScore = (result.similarity_score * 100).toFixed(1);
        document.getElementById("similarity-score").textContent =
          similarityScore + "%";
        document.getElementById("query-description").textContent =
          result.query_description;

        // Display full policy (or chunk if full policy not available)
        const policyText = result.full_policy || result.violated_policy;
        document.getElementById("violated-policy-text").textContent =
          policyText;

        // Update policy filename if available
        if (result.policy_filename) {
          document.getElementById("policy-filename").textContent =
            result.policy_filename;
        }

        // Setup toggle button for showing/hiding policy
        setupPolicyToggle();

        // Color code similarity score
        const scoreElement = document.getElementById("similarity-score");
        if (result.similarity_score >= 0.7) {
          scoreElement.className = "similarity-value high";
        } else if (result.similarity_score >= 0.4) {
          scoreElement.className = "similarity-value medium";
        } else {
          scoreElement.className = "similarity-value low";
        }
      } else if (result.message) {
        // Show message (e.g., no policies uploaded)
        console.log("Showing message:", result.message);
        content.style.display = "none";
        message.style.display = "block";
        message.textContent = result.message;
      }
    } else {
      console.log("Not an anomaly, hiding violation section");
      console.log("Message:", result.message);
      // Hide section for non-anomalies
      section.style.display = "none";
    }
  } catch (error) {
    console.error("Error checking policy violation:", error);
    // Show error in the section
    loading.style.display = "none";
    content.style.display = "none";
    message.style.display = "block";
    message.className = "policy-message error";
    message.textContent = "Error checking policy violations: " + error.message;
  } finally {
    if (window.i18n && window.i18n.applyTranslations) {
      window.i18n.applyTranslations();
    }
  }
}

// Setup toggle functionality for policy display
function setupPolicyToggle() {
  const toggleBtn = document.getElementById("toggle-policy-btn");
  const policyContainer = document.getElementById("policy-text-container");

  // Remove existing listener by cloning
  const newToggleBtn = toggleBtn.cloneNode(true);
  toggleBtn.parentNode.replaceChild(newToggleBtn, toggleBtn);

  newToggleBtn.addEventListener("click", function () {
    const isVisible = policyContainer.style.display !== "none";
    const icon = newToggleBtn.querySelector(".material-icons");
    const text = newToggleBtn.querySelector("span:last-child");

    if (isVisible) {
      // Hide policy
      policyContainer.style.display = "none";
      icon.textContent = "visibility";
      text.textContent = window.i18n
        ? window.i18n.t("detail.view_full_policy")
        : "View Full Policy";
    } else {
      // Show policy
      policyContainer.style.display = "block";
      icon.textContent = "visibility_off";
      text.textContent = window.i18n
        ? window.i18n.t("detail.hide_full_policy")
        : "Hide Full Policy";
    }
  });
}
