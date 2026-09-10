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
// Chat Widget functionality
(function () {
  const chatToggle = document.getElementById("chat-toggle");
  const chatContainer = document.getElementById("chat-container");
  const chatClose = document.getElementById("chat-close");
  const chatMessages = document.getElementById("chat-messages");
  const chatInput = document.getElementById("chat-input");
  const chatSend = document.getElementById("chat-send");

  let isOpen = false;
  let conversationHistory = [];

  // Toggle chat window
  chatToggle.addEventListener("click", () => {
    isOpen = !isOpen;
    chatContainer.style.display = isOpen ? "flex" : "none";
    if (isOpen) {
      chatInput.focus();
    }
  });

  // Close chat window
  chatClose.addEventListener("click", () => {
    isOpen = false;
    chatContainer.style.display = "none";
  });

  // Auto-resize textarea
  chatInput.addEventListener("input", function () {
    this.style.height = "auto";
    this.style.height = Math.min(this.scrollHeight, 100) + "px";
  });

  // Send message on Enter (Shift+Enter for new line)
  chatInput.addEventListener("keydown", (e) => {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      sendMessage();
    }
  });

  // Send button click
  chatSend.addEventListener("click", sendMessage);

  // Quick question buttons click handlers
  document.addEventListener("click", (e) => {
    if (e.target.closest(".quick-question-btn")) {
      const button = e.target.closest(".quick-question-btn");
      const i18nKey = button.getAttribute("data-i18n");
      const question =
        window.i18n && i18nKey
          ? window.i18n.t(i18nKey)
          : button.getAttribute("data-question");
      if (question) {
        chatInput.value = question;
        sendMessage();
      }
    }
  });

  // Send message function
  async function sendMessage() {
    const message = chatInput.value.trim();
    if (!message) return;

    // Clear input
    chatInput.value = "";
    chatInput.style.height = "auto";

    // Add user message to chat
    addMessage(message, "user");

    // Disable input while processing
    chatInput.disabled = true;
    chatSend.disabled = true;

    // Show typing indicator
    const typingIndicator = showTypingIndicator();

    try {
      // Get policy context from the page (if available)
      const context = getPolicyContext();

      // Add to conversation history
      conversationHistory.push({
        role: "user",
        content: message,
      });

      const currentLang = window.i18n ? window.i18n.currentLang : "en";

      // Send request to LLM service
      const response = await fetch("/api/llm/chat", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          message: message,
          policy_context: context,
          history: conversationHistory,
          language: currentLang,
        }),
      });

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }

      const data = await response.json();

      // Remove typing indicator
      removeTypingIndicator(typingIndicator);

      // Add assistant response
      if (data.response) {
        addMessage(data.response, "bot");
        conversationHistory.push({
          role: "assistant",
          content: data.response,
        });
      } else {
        throw new Error("No response received from AI");
      }
    } catch (error) {
      console.error("Error sending message:", error);
      removeTypingIndicator(typingIndicator);
      addMessage(
        "Sorry, I encountered an error processing your request. Please try again.",
        "bot",
        true,
      );
    } finally {
      // Re-enable input
      chatInput.disabled = false;
      chatSend.disabled = false;
      chatInput.focus();
    }
  }

  // Add message to chat
  function addMessage(text, sender, isError = false) {
    const messageDiv = document.createElement("div");
    messageDiv.className = `chat-message ${sender}-message`;

    const contentDiv = document.createElement("div");
    contentDiv.className = "message-content";

    if (isError) {
      const p = document.createElement("p");
      p.textContent = text;
      p.className = "error-message";
      contentDiv.appendChild(p);
    } else if (sender === "bot") {
      // Render markdown for bot messages
      contentDiv.innerHTML = marked.parse(text);
    } else {
      // Plain text for user messages
      const p = document.createElement("p");
      p.textContent = text;
      contentDiv.appendChild(p);
    }

    messageDiv.appendChild(contentDiv);
    chatMessages.appendChild(messageDiv);

    // Scroll to bottom
    chatMessages.scrollTop = chatMessages.scrollHeight;
  }

  // Show typing indicator
  function showTypingIndicator() {
    const indicatorDiv = document.createElement("div");
    indicatorDiv.className = "chat-message bot-message";
    indicatorDiv.id = "typing-indicator";

    const typingDiv = document.createElement("div");
    typingDiv.className = "typing-indicator";

    for (let i = 0; i < 3; i++) {
      const dot = document.createElement("div");
      dot.className = "typing-dot";
      typingDiv.appendChild(dot);
    }

    indicatorDiv.appendChild(typingDiv);
    chatMessages.appendChild(indicatorDiv);

    // Scroll to bottom
    chatMessages.scrollTop = chatMessages.scrollHeight;

    return indicatorDiv;
  }

  // Remove typing indicator
  function removeTypingIndicator(indicator) {
    if (indicator && indicator.parentNode) {
      indicator.parentNode.removeChild(indicator);
    }
  }

  // Get policy context from the page
  function getPolicyContext() {
    // Try to get the full policy text from the violation section
    const policyTextElement = document.getElementById("violated-policy-text");
    const policyFilenameElement = document.getElementById("policy-filename");

    if (!policyTextElement || !policyTextElement.textContent.trim()) {
      // No policy available
      return null;
    }

    const policyText = policyTextElement.textContent.trim();
    const policyFilename = policyFilenameElement
      ? policyFilenameElement.textContent.trim()
      : "Unknown Policy";

    return {
      filename: policyFilename,
      content: policyText,
    };
  }
})();
