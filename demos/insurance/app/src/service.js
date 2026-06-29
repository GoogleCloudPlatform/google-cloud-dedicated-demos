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
import { currentLangText, TEXT_MAPS } from "./translations.js";

const RECOMMENDATION_CUT_OFF_SCORE = 40;

const GREEN_CHECK_ICON = `
<svg class="verification-icon" xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="var(--secondary)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
    <path d="M20 6L9 17l-5-5"></path>
</svg>
`;

const RED_CROSS_ICON = `
<svg class="verification-icon" xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="var(--danger)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
    <circle cx="12" cy="12" r="10"></circle>
    <line x1="12" y1="8" x2="12" y2="12"></line>
    <line x1="12" y1="16" x2="12" y2="16"></line>
</svg>
`;

const YELLOW_WARNING_ICON = `
<svg class="verification-icon" xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#b58900" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
    <path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"></path>
    <line x1="12" y1="9" x2="12" y2="13"></line>
    <line x1="12" y1="17" x2="12" y2="17"></line>
</svg>
`;

function getToken() {
  return localStorage.getItem("showroom_token");
}

function showLoginModal() {
  const overlay = document.getElementById("login-overlay");
  const logoutBtn = document.getElementById("btn-logout");
  if (overlay) overlay.classList.remove("hidden");
  if (logoutBtn) logoutBtn.classList.add("hidden");
}

function hideLoginModal() {
  const overlay = document.getElementById("login-overlay");
  const logoutBtn = document.getElementById("btn-logout");
  if (overlay) overlay.classList.add("hidden");
  if (logoutBtn) logoutBtn.classList.remove("hidden");
}

export async function handleLogin(event) {
  event.preventDefault();
  const usernameInput = document.getElementById("login-username");
  const passwordInput = document.getElementById("login-password");
  const errorDiv = document.getElementById("login-error");

  try {
    const res = await fetch("/api/login", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        username: usernameInput?.value,
        password: passwordInput?.value,
      }),
    });

    const data = await res.json();
    if (res.ok && data.success && data.token) {
      localStorage.setItem("showroom_token", data.token);
      if (errorDiv) errorDiv.classList.add("hidden");
      hideLoginModal();
      await loadClaims();
    } else {
      if (errorDiv) errorDiv.classList.remove("hidden");
    }
  } catch (e) {
    console.error(e);
    if (errorDiv) errorDiv.classList.remove("hidden");
  }
}

export function handleLogout() {
  localStorage.removeItem("showroom_token");
  showLoginModal();
}

async function authenticatedFetch(url, options = {}) {
  const token = getToken();
  const headers = { ...options.headers };
  if (token) {
    headers["Authorization"] = `Bearer ${token}`;
  }

  const res = await fetch(url, { ...options, headers });
  if (res.status === 401) {
    showLoginModal();
    throw new Error("Unauthorized");
  }
  return res;
}

async function loadClaims() {
  const claimsContainer = document.querySelector("#claims-container");
  if (!claimsContainer) return;
  claimsContainer.innerHTML = "";
  try {
    const response = await authenticatedFetch("/api/claims");
    const claims = await response.json();
    hideLoginModal();

    for (let i = 0; i < claims.length; i++) {
      const el = document.createElement("div");
      el.innerHTML = claimsCard(claims[i], i);
      claimsContainer.appendChild(el);
    }
  } catch (e) {
    console.log("Not logged in or error loading claims", e);
  }
}

(async () => {
  window.analyzeClaim = analyzeClaim;
  window.sendOption = sendOption;
  window.handleLogin = handleLogin;
  window.handleLogout = handleLogout;

  const token = getToken();
  if (!token) {
    showLoginModal();
  } else {
    await loadClaims();
  }
})();

async function delay(milis) {
  return new Promise((resolve) => setTimeout(resolve, milis));
}

function getCardElements(index) {
  const card = document.querySelector(`.card-${index}`);
  const analysis = card.querySelector(".ai-analysis");

  return {
    card,
    button: card.querySelector(".btn-analyze"),
    analysis,
    actions: card.querySelector(".action-buttons"),
    verificationList: analysis.querySelector(".verification-list"),
  };
}

export async function analyzeClaim(claimId, index) {
  const { button, analysis, actions, verificationList } =
    getCardElements(index);

  button.classList.add("loading");
  analysis.classList.add("show");

  try {
    const isRiskSafe = await analyzeRiskScore(claimId, verificationList);
    const llmStatus = await analyzeClaimAndAppend(claimId, verificationList);

    const isLlmSafe = llmStatus === "success";
    const isOverallSafe = isRiskSafe && isLlmSafe;

    actions.innerHTML = isOverallSafe ? successButtons() : errorButtons();

    button.style.display = "none";
    actions.classList.add("show");
  } catch (e) {
    console.error(e);
  }
}

async function analyzeClaimAndAppend(claimId, verificationList) {
  const claimAnalysisRes = await authenticatedFetch(
    `/api/claims/${claimId}/analyze`,
  );
  const responseData = await claimAnalysisRes.json();
  const fullText = responseData.text || "";
  const hasDocs = responseData.hasDocs;

  const isSuccess = fullText.includes("DECISION: APPROVE");

  const cleanedText = fullText
    .replace(/DECISION:\s*APPROVE\s*$/, "")
    .replace(/DECISION:\s*REJECT\s*$/, "")
    .trim();

  const lastPara = extractLastPara(cleanedText);

  console.table({ ...responseData, lastPara });

  let status = "success";
  if (!isSuccess) {
    status = hasDocs ? "mismatch" : "missing";
  }

  verificationList.appendChild(analysisItem(lastPara, status, "show"));

  return status;
}

async function analyzeRiskScore(claimId, verificationList) {
  const res = await authenticatedFetch(
    `/api/claims/${claimId}/riskscore/analyze`,
  );
  const responseData = await res.json();

  if (
    responseData.predicted_risk_score === undefined ||
    responseData.predicted_risk_score === null
  ) {
    console.log("No predicted score in", responseData);
    return false;
  }

  const score = Math.round(responseData.predicted_risk_score);

  const isSafe = score <= RECOMMENDATION_CUT_OFF_SCORE;
  const thresholdText = ` (${currentLangText(TEXT_MAPS.THRESHOLD)}: ${RECOMMENDATION_CUT_OFF_SCORE})`;
  const text =
    (isSafe
      ? currentLangText(TEXT_MAPS.RISK_SCORE_BELOW_CUT_OFF, { SCORE: score })
      : currentLangText(TEXT_MAPS.RISK_SCORE_ABOVE_CUT_OFF, { SCORE: score })) +
    thresholdText;

  console.table({ ...responseData });

  verificationList.appendChild(
    analysisItem(text, isSafe ? "success" : "error", "show"),
  );
  return isSafe;
}

function extractLastPara(text) {
  if (!text) return "No response from AI.";
  const paras = text
    .split("\n\n")
    .map((p) => p.trim())
    .filter((p) => p.length > 0);
  if (paras.length === 0) return "No response from AI.";
  const lastPara = paras[paras.length - 1]
    .replace(/^Therefore,/, "")
    .replace(/^Therefore/, "")
    .trim();

  if (lastPara.length === 0) return "No response from AI.";
  return lastPara[0].toUpperCase() + lastPara.substring(1);
}

function claimsCard(claim, index) {
  const statusClassName = claim.status.replaceAll(" ", "-").toLowerCase();
  const indexOddEven = index % 2;
  return `
        <div class="card card-${index}">
            <div class="card-header">
                <h3 class="card-title">${currentLangText(TEXT_MAPS.CLAIM)} #${claim.claim_id}</h3>
                <span class="card-status status-under-review">${currentLangText(TEXT_MAPS.UNDER_REVIEW)}</span>
            </div>

            <div class="card-patient">
                <div class="patient-avatar">${claim.Customer.first_name.charAt(0)}${claim.Customer.last_name.charAt(0)}</div>
                <div class="patient-info">
                    <h4 class="patient-name">${claim.Customer.first_name} ${claim.Customer.last_name}</h4>
                    <p class="patient-details">ID: ${claim.Customer.customer_id} • DOB: ${claim.Customer.date_of_birth} • Plan: ${currentLangText(TEXT_MAPS.BALANCED_FORMULA)}</p>
                </div>
            </div>

            <div class="claim-details">
                <div class="claim-item">
                    <span class="claim-label">${currentLangText(TEXT_MAPS.DATE_OF_SERVICE)}:</span>
                    <span class="claim-value">${claim.date_of_service}</span>
                </div>
                <div class="claim-item">
                    <span class="claim-label">${currentLangText(TEXT_MAPS.SERIVCE_TYPE)}:</span>
                    <span class="claim-value">${claim.ServiceType.service_name}</span>
                </div>
                <div class="claim-item">
                    <span class="claim-label">${currentLangText(TEXT_MAPS.PROVIDER)}:</span>
                    <span class="claim-value">${claim.Provider.provider_name}</span>
                </div>
                <div class="claim-item">
                    <span class="claim-label">${currentLangText(TEXT_MAPS.AMOUNT_BILLED)}:</span>
                    <span class="claim-value">${claim.amount_billed} €</span>
                </div>
                <div class="claim-item">
                    <span class="claim-label">${currentLangText(TEXT_MAPS.PUBLIC_INSURANCE_BASE)}:</span>
                    <span class="claim-value">${claim.public_insurance_base} €</span>
                </div>
                <div class="claim-item">
                    <span class="claim-label">${currentLangText(TEXT_MAPS.MUTUAL_COVERAGE)}:</span>
                    <span class="claim-value">${claim.mutuelle_coverage} €</span>
                </div>
            </div>

            <button class="btn btn-analyze" onclick="analyzeClaim('${claim.claim_id}', ${index})">
                <div class="spinner"></div>
                <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                    <circle cx="12" cy="12" r="10"></circle>
                    <line x1="12" y1="16" x2="12" y2="12"></line>
                    <line x1="12" y1="8" x2="12" y2="8"></line>
                </svg>
                <span class="btn-text">${currentLangText(TEXT_MAPS.ANALYZE_CLAIM)}</span>
            </button>

            <div class="ai-analysis">
                <div class="ai-header">
                    <svg class="ai-icon" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                        <circle cx="12" cy="12" r="10"></circle>
                        <line x1="12" y1="16" x2="12" y2="12"></line>
                        <line x1="12" y1="8" x2="12" y2="8"></line>
                    </svg>
                    <h4 class="ai-title">${currentLangText(TEXT_MAPS.AI_POWERED_RISK_AANALYSIS)}</h4>
                </div>
                <ul class="verification-list"></ul>
            </div>

            <div class="action-buttons">
                ${indexOddEven == 0 ? successButtons() : errorButtons()}
            </div>
        </div>
    `;
}

function successButtons() {
  return `
        <button class="btn btn-outline" disabled>${currentLangText(TEXT_MAPS.REQUEST_MORE_INFO)}</button>
        <button class="btn btn-primary" disabled>${currentLangText(TEXT_MAPS.APPROVE)}</button>
    `;
}

function errorButtons() {
  return `
        <button class="btn btn-outline" disabled>${currentLangText(TEXT_MAPS.REQUEST_DOCUMENTATION)}</button>
        <button class="btn btn-outline" disabled>${currentLangText(TEXT_MAPS.ESCALATE_TO_INVESTIGATOR)}</button>
        <button class="btn btn-primary" disabled>${currentLangText(TEXT_MAPS.OVERRIDE_AND_APPROVE)}</button>
    `;
}

function replaceFinalAnalysisPrefix(text) {
  return text
    .replace("**Final Analysis:**", "**LLM Analysis:**")
    .replace("**Analyse finale :**", "**Analyse LLM :**")
    .replace("**Analyse finale:**", "**Analyse LLM:**");
}

function formatMarkdown(text) {
  return text.replace(/\*\*(.*?)\*\*/g, "<strong>$1</strong>");
}

function analysisItem(text, status, clazz = "") {
  const listItem = document.createElement("li");
  listItem.classList.add("verification-item");

  if (clazz) {
    listItem.classList.add(clazz);
  }

  if (status === "success") {
    listItem.innerHTML = GREEN_CHECK_ICON;
  } else if (status === "missing") {
    listItem.innerHTML = YELLOW_WARNING_ICON;
    listItem.style.color = "#b58900"; // Dark yellow/gold for readability
  } else {
    // mismatch or general fail
    listItem.innerHTML = RED_CROSS_ICON;
    listItem.style.color = "var(--danger)";
  }

  const formattedText = formatMarkdown(replaceFinalAnalysisPrefix(text));
  listItem.innerHTML += `<span class="verification-text">${formattedText}</span>`;

  return listItem;
}

// Chat Widget Functionality
document.addEventListener("DOMContentLoaded", function () {
  const chatBubble = document.getElementById("chat-bubble");
  const chatPopup = document.getElementById("chat-popup");
  const chatClose = document.getElementById("chat-close");
  const chatInput = document.getElementById("chat-input");
  const chatSend = document.getElementById("chat-send");
  const chatBody = document.getElementById("chat-body");

  // Show chat popup on bubble click
  chatBubble.addEventListener("click", function () {
    chatPopup.classList.add("show");
    chatBubble.querySelector(".chat-notification").style.display = "none";
  });

  // Close chat popup
  chatClose.addEventListener("click", function () {
    chatPopup.classList.remove("show");
  });

  // Send button functionality
  chatSend.addEventListener("click", function () {
    sendMessage();
  });

  // Enter key to send message
  chatInput.addEventListener("keypress", function (e) {
    if (e.key === "Enter") {
      sendMessage();
    }
  });

  // Function to send message
  async function sendMessage() {
    const message = chatInput.value.trim();
    if (message) {
      // Add user message
      addMessage(message, "user");
      chatInput.value = "";

      // Add temporary typing bubble
      addMessage("...", "bot");
      const botBubbles = chatBody.querySelectorAll(".message-bot");
      const lastBotBubble = botBubbles[botBubbles.length - 1];

      const reply = await askBackendChat(message);
      lastBotBubble.querySelector(".message-content").innerText = reply;
      chatBody.scrollTop = chatBody.scrollHeight;
    }
  }

  // Function to add message to chat
  function addMessage(text, sender) {
    const messageDiv = document.createElement("div");
    messageDiv.classList.add(
      "chat-message",
      `message-${sender}`,
      "chat-message-appear",
    );

    if (sender === "bot") {
      messageDiv.innerHTML = `
                <div class="message-bubble">
                    <div class="message-avatar">
                        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                            <circle cx="12" cy="12" r="10"></circle>
                            <line x1="12" y1="16" x2="12" y2="12"></line>
                            <line x1="12" y1="8" x2="12" y2="8"></line>
                        </svg>
                    </div>
                    <div class="message-content">${text}</div>
                </div>
            `;
    } else {
      messageDiv.innerHTML = `<div class="message-content">${text}</div>`;
    }

    chatBody.appendChild(messageDiv);
    chatBody.scrollTop = chatBody.scrollHeight;
  }
});

async function askBackendChat(message) {
  try {
    const res = await authenticatedFetch("/api/chat", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ message }),
    });
    if (!res.ok) {
      throw new Error(await res.text());
    }
    const data = await res.json();
    return data.reply || "Sorry, an error occurred / Une erreur est survenue.";
  } catch (e) {
    console.error(e);
    return "Sorry, unable to reach AI Assistant / Impossible de joindre l'assistant IA.";
  }
}

// Function to send preset options
export async function sendOption(text) {
  const chatBody = document.getElementById("chat-body");

  // Add user message
  const messageDiv = document.createElement("div");
  messageDiv.classList.add(
    "chat-message",
    "message-user",
    "chat-message-appear",
  );
  messageDiv.innerHTML = `<div class="message-content">${text}</div>`;
  chatBody.appendChild(messageDiv);

  // Remove options
  const options = document.querySelector(".chat-options");
  if (options) {
    options.remove();
  }

  // Add typing bot bubble
  const botMessageDiv = document.createElement("div");
  botMessageDiv.classList.add(
    "chat-message",
    "message-bot",
    "chat-message-appear",
  );
  botMessageDiv.innerHTML = `
            <div class="message-bubble">
                <div class="message-avatar">
                    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                        <circle cx="12" cy="12" r="10"></circle>
                        <line x1="12" y1="16" x2="12" y2="12"></line>
                        <line x1="12" y1="8" x2="12" y2="8"></line>
                    </svg>
                </div>
                <div class="message-content">...</div>
            </div>
        `;
  chatBody.appendChild(botMessageDiv);
  chatBody.scrollTop = chatBody.scrollHeight;

  const reply = await askBackendChat(text);
  botMessageDiv.querySelector(".message-content").innerText = reply;
  chatBody.scrollTop = chatBody.scrollHeight;
}
