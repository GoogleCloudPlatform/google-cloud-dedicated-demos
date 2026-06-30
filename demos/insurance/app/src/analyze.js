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
import fs from "node:fs";
import path from "node:path";

import { Claim, ServiceType, Customer, Provider } from "./models.js";
import { initializeStorage } from "./gcp-storage.js";

const MODEL_HOST = process.env.MODEL_HOST;
const MODEL_NAME = process.env.MODEL_NAME;
const BASE_DOWNLOAD_DIR = "./downloads";
const BASE_SRC_DIR = "./src/data";
const PROMPT_FILE_NAME = "prompt.txt";

const MAX_RETRY_COUNT = 10;

/**
 * Attempts
 */
export async function analyzeClaimWithRetry(claimId) {
  let retryCount = 1;

  while (retryCount <= MAX_RETRY_COUNT) {
    retryCount++;

    const response = (await analyzeClaim(claimId))
      .replaceAll(",'", ', "')
      .replaceAll(", '", ', "')
      .replaceAll("',", '", ')
      .replaceAll("' ,", '", ')
      .replaceAll("']", '"]');
    try {
      return JSON.parse(response);
    } catch (e) {
      console.error("Error occured while parsing", e);

      if (retryCount > MAX_RETRY_COUNT) {
        return response;
      }
    }
  }
}

function getTranslation(key, lang) {
  try {
    const filePath = path.join("./src/i18n", `${lang}.json`);
    if (fs.existsSync(filePath)) {
      const data = JSON.parse(fs.readFileSync(filePath, "utf-8"));
      if (data[key]) return data[key];
    }
  } catch (e) {
    console.error("Error loading translation", e);
  }
  return key;
}

export async function analyzeClaim(claimId, options = {}) {
  const claim = await Claim.findByPk(claimId, {
    include: [ServiceType, Customer, Provider],
  });
  const docsText = await readClaimDocuments(claimId);
  const hasDocs = docsText.trim().length > 0;

  if (!hasDocs) {
    const lang = options.language || "en";
    const msg = getTranslation("NO_DOCUMENTATION_PROVIDED", lang);
    return {
      text: `${msg}\n\nDECISION: REJECT`,
      prompt: "LLM call skipped: No documents in GCS.",
      hasDocs: false,
    };
  }

  const prompt = buildPrompt(claim.toJSON(), docsText, options);
  console.log(prompt);
  const response = await fetch(`${MODEL_HOST}/v1/chat/completions`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: MODEL_NAME,
      messages: [
        {
          role: "user",
          content: prompt,
        },
      ],
      temperature: 0,
      max_tokens: 1000,
    }),
  });

  if (response.status !== 200) {
    return {
      error: await response.text(),
    };
  }

  const data = await response.json();

  return {
    text: data.choices[0].message.content,
    prompt: prompt,
    hasDocs: hasDocs,
  };
}

function getFullLanguageName(code) {
  if (!code) return "English";
  try {
    const dn = new Intl.DisplayNames(["en"], { type: "language" });
    return dn.of(code) || code;
  } catch (e) {
    return code;
  }
}

function buildPrompt(claim, docsText, options) {
  const fullLanguage = getFullLanguageName(options.language);

  const promptPart1 = fs
    .readFileSync(path.join(BASE_SRC_DIR, PROMPT_FILE_NAME))
    .toString();

  return `
${promptPart1}

Name: ${claim.Customer.first_name} ${claim.Customer.last_name}
ID: ${claim.Customer.customer_id}
DOB: ${claim.Customer.date_of_birth}
Plan: Balanced Formula
Date of Service: ${claim.date_of_service}
Service Type: ${claim.ServiceType.service_name}
Provider: ${claim.Provider.provider_name}
Amount Billed: ${claim.amount_billed} €

${docsText}

CRITICAL INSTRUCTION: Write your analysis summary in ${fullLanguage}. However, on the final line, you MUST write strictly in English: 'DECISION: APPROVE' or 'DECISION: REJECT'. Do not translate DECISION, APPROVE, or REJECT.
`;
}

async function readClaimDocuments(actualClaimId) {
  const searchPrefix = actualClaimId.toLowerCase();
  console.log("Searching documents with prefix:", searchPrefix);

  const claimsBucketName = process.env.CLAIMS_DOCUMENTS_BUCKET ?? "";
  console.log("Claims bucket name:", claimsBucketName);

  const storage = await initializeStorage();
  const bucket = await storage.bucket(claimsBucketName).get();
  const filesResponse = await bucket[0].getFiles({
    prefix: searchPrefix,
  });

  fs.mkdirSync(BASE_DOWNLOAD_DIR, {
    recursive: true,
  });

  await Promise.all(
    filesResponse[0].map((file) =>
      file.download({
        destination: path.join(BASE_DOWNLOAD_DIR, file.name),
      }),
    ),
  );

  const fileNames = fs
    .readdirSync(BASE_DOWNLOAD_DIR)
    .filter((name) => name.toLocaleLowerCase().startsWith(searchPrefix));

  return fileNames
    .map((fileName) =>
      fs.readFileSync(path.join(BASE_DOWNLOAD_DIR, fileName)).toString(),
    )
    .map(addDocumentSeparators)
    .join("");
}

function addDocumentSeparators(fileContent, idx) {
  return `
Document ${idx + 1} starts here

${fileContent}

Document ${idx + 1} ends here
`;
}

export async function chatWithAssistant(userMessage, options = {}) {
  const claims = await Claim.findAll({
    include: [Provider, ServiceType, Customer],
  });

  const sysPrompt = fs
    .readFileSync(path.join(BASE_SRC_DIR, "chat_prompt.txt"))
    .toString();

  const compactClaims = claims.map((c) => ({
    id: c.claim_id,
    patient:
      `${c.Customer?.first_name || ""} ${c.Customer?.last_name || ""}`.trim(),
    service: c.ServiceType?.service_name || "",
    provider: c.Provider?.provider_name || "",
    amount: `${c.amount_billed} €`,
    status: c.status,
  }));

  const fullLanguage = getFullLanguageName(options.language);

  const prompt = `${sysPrompt}\n${JSON.stringify(
    compactClaims,
  )}\n\nCRITICAL INSTRUCTION: You MUST answer the user question entirely in ${fullLanguage}.\n\nUser Question:\n${userMessage}`;

  const response = await fetch(`${MODEL_HOST}/v1/chat/completions`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: MODEL_NAME,
      messages: [
        {
          role: "user",
          content: prompt,
        },
      ],
      temperature: 0.2,
      max_tokens: 500,
    }),
  });

  if (response.status !== 200) {
    throw new Error(await response.text());
  }

  const data = await response.json();
  return {
    reply: data.choices[0].message.content,
  };
}
