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
import { Sequelize, DataTypes } from "sequelize";
import { models } from "./models.js";

export async function connect({
  databaseUserName,
  databaseName,
  databaseHost = "127.0.0.1", // Le proxy écoute sur localhost
  databasePort = 5432, // Le port exposé par le proxy
}) {
  console.log("Connexion à la base de données via le Cloud SQL Auth Proxy...");
  console.table({
    databaseHost,
    databasePort,
    databaseUserName,
    databaseName,
  });

  const sequelizeOptions = {
    dialect: "postgres",
    host: databaseHost,
    port: databasePort,
    // Pas de mot de passe, l'authentification est gérée par le proxy
    password: null,
    logging: false,
  };

  const database = new Sequelize(
    databaseName,
    databaseUserName,
    null,
    sequelizeOptions,
  );

  try {
    await database.authenticate();
    console.log("✅ Connexion à la base de données via le proxy réussie !");
  } catch (error) {
    console.error("❌ Échec de la connexion à la base de données.", error);
    throw error;
  }

  // Initialisation des modèles
  for (const model of models) {
    model.init(database, DataTypes);
    model.sync();
  }

  await database.sync();

  return {
    sequelize: database,
    async close() {
      await database.close();
    },
  };
}
