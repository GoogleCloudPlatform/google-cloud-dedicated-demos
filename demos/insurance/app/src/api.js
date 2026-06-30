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
import express from "express";
import crypto from "node:crypto";
import {
  Claim,
  Provider,
  ServiceType,
  Customer,
  InsurancePlan,
} from "./models.js";
import { analyzeClaim, chatWithAssistant } from "./analyze.js";
import { analyzeUsingBigQuery } from "./bigquery-analyze.js";
import { findTopLanguage } from "./utils.js";

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

export const SESSION_TOKEN = crypto.randomUUID();
const LOGIN_USER = process.env.APP_LOGIN_USER;
const LOGIN_PASSWORD = process.env.APP_LOGIN_PASSWORD;

export const router = express.Router();

router.route("/i18n/languages").get((req, res) => {
  const i18nDir = path.join(__dirname, "i18n");
  const languages = [];
  if (fs.existsSync(i18nDir)) {
    const files = fs.readdirSync(i18nDir).sort();
    for (const filename of files) {
      if (filename.endsWith(".json")) {
        try {
          const content = fs.readFileSync(path.join(i18nDir, filename), "utf-8");
          const data = JSON.parse(content);
          if (data._meta) {
            languages.push(data._meta);
          }
        } catch (e) {
          console.error("Failed to read i18n file", filename, e);
        }
      }
    }
  }
  return res.json(languages);
});

router.route("/login").post((req, res) => {
  const { username, password } = req.body ?? {};
  if (username === LOGIN_USER && password === LOGIN_PASSWORD) {
    return res.json({ success: true, token: SESSION_TOKEN });
  }
  return res.status(401).json({ success: false, error: "Invalid credentials" });
});

const authMiddleware = (req, res, next) => {
  if (req.path === "/login" || req.path === "/i18n/languages") return next();
  const authHeader = req.headers.authorization;
  if (authHeader === `Bearer ${SESSION_TOKEN}`) {
    return next();
  }
  return res.status(401).json({ error: "Unauthorized" });
};

router.use(authMiddleware);

// middleware that is specific to this router
const timeLog = (req, res, next) => {
  console.log("Time: ", Date.now());
  next();
};

router.route("/claims").get(async (req, res) => {
  const claims = await Claim.findAll({
    include: [Provider, ServiceType, Customer],
  });
  res.send(claims.map((c) => c.toJSON()));
});

router.route("/claims/:claimId/analyze").get(async (req, res) => {
  try {
    res.json(
      await analyzeClaim(req.params.claimId, {
        language: findTopLanguage(req),
      }),
    );
  } catch (e) {
    console.error(e);
    res.send(e);
  }
});

router.route("/claims/:claimId/riskscore/analyze").get(async (req, res) => {
  try {
    res.json(await analyzeUsingBigQuery(req.params.claimId));
  } catch (e) {
    console.error(e);
    res.send(e);
  }
});

router.route("/chat").post(async (req, res) => {
  try {
    const lang = req.body.lang || findTopLanguage(req);
    res.json(await chatWithAssistant(req.body.message, { language: lang }));
  } catch (e) {
    console.error(e);
    res.status(500).send(e.message || "Error");
  }
});

router.use(timeLog);
