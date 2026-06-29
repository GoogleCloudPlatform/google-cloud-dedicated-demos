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
// Connection animation sequence
const steps = [
  {
    id: "step1",
    delay: 800,
    key: "connecting.msg.step1",
    message: "Authenticating credentials...",
  },
  {
    id: "step2",
    delay: 1600,
    key: "connecting.msg.step2",
    message: "Establishing secure tunnel to Trusted Local Partner...",
  },
  {
    id: "step3",
    delay: 2400,
    key: "connecting.msg.step3",
    message: "Connecting to BigQuery instance...",
  },
  {
    id: "step4",
    delay: 3200,
    key: "connecting.msg.step4",
    message: "Connection established successfully!",
  },
];

const statusMessage = document.querySelector(".status-message");
const continueBtn = document.getElementById("continueBtn");
let dataPreloaded = false;

// Preload predictions data asynchronously in background
fetch("/api/predictions")
  .then((response) => response.json())
  .then((data) => {
    // Store data in sessionStorage for instant dashboard load
    sessionStorage.setItem("preloadedPredictions", JSON.stringify(data));
    dataPreloaded = true;
    console.log("Predictions data preloaded successfully");
  })
  .catch((error) => {
    console.error("Error preloading predictions:", error);
    dataPreloaded = false; // Dashboard will fetch fresh data
  });

steps.forEach((step, index) => {
  setTimeout(() => {
    // Mark current step as active and completed
    const stepElement = document.getElementById(step.id);
    stepElement.classList.add("active", "completed");

    // Update status message
    statusMessage.textContent = window.i18n
      ? window.i18n.t(step.key)
      : step.message;
    statusMessage.setAttribute("data-i18n", step.key);

    // Show button after last step
    if (index === steps.length - 1) {
      setTimeout(() => {
        continueBtn.style.display = "flex";
        continueBtn.classList.add("show");
      }, 500);
    }
  }, step.delay);
});

// Animate connection path
const path = document.getElementById("connectionPath");
setTimeout(() => {
  path.style.strokeDashoffset = "0";
}, 300);

// Button click handler
continueBtn.addEventListener("click", () => {
  window.location.href = "/dashboard";
});
