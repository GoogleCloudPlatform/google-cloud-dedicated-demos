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
import { fileURLToPath } from "url";
import { dirname } from "path";
import { router as apiRouter } from "./api.js";

import { connect } from "./database.js";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const app = express();
const port = process.env.PORT ?? 3000;
const instanceConnectionName = `${process.env.PROJECT}:${process.env.REGION}:${process.env.SQL_INSTANCE_NAME}`;
const databaseName = process.env.CLAIMS_DATABASE_NAME ?? "";
const databaseUserName = process.env.DATABASE_USER_NAME ?? "";
const databasePassword = process.env.DATABASE_PASSWORD ?? "";
const universeDomain = process.env.GOOGLE_CLOUD_UNIVERSE_DOMAIN ?? "";
const databasePort = process.env.DATABASE_PORT ?? "";

await connect({
  instanceConnectionName,
  databaseName,
  databaseUserName,
  databasePassword,
  universeDomain,
  databasePort,
});

app.get("/", (req, res) => {
  res.sendFile(__dirname + "/index.html");
});

app.get("/service.js", (req, res) => {
  res.sendFile(__dirname + "/service.js");
});

app.get("/i18n.js", (req, res) => {
  res.sendFile(__dirname + "/i18n.js");
});

app.get("/style.css", (req, res) => {
  res.sendFile(__dirname + "/style.css");
});

app.use("/i18n", express.static(__dirname + "/i18n"));

app.use(express.json());
app.use("/api", apiRouter);

app.listen(port, () => {
  console.log(`Example app listening on port ${port}`);
});
