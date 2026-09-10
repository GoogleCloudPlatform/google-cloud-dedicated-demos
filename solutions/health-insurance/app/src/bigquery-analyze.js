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
import { BigQuery } from "@google-cloud/bigquery";
import {
  Claim,
  Provider,
  ServiceType,
  Customer,
  RiskAnalysis,
} from "./models.js";

const DATASET_ID = "next_demo_health_insurance_ds";
const PROJECT_ID = process.env.PROJECT ?? "";
const BQML_MODEL_NAME = "claim_risk_linear_reg_model";
const CLAIMS_TABLE = "historical_claims";

const MODEL_ID = `${PROJECT_ID}.${DATASET_ID}.${BQML_MODEL_NAME}`;
const CLAIMS_TABLE_ID = `${PROJECT_ID}.${DATASET_ID}.${CLAIMS_TABLE}`;

export async function analyzeUsingBigQuery(claimId) {
  const claim = await Claim.findByPk(claimId, {
    include: [Provider, ServiceType, Customer, RiskAnalysis],
  });

  const bigqueryClient = new BigQuery({
    universeDomain: process.env.GOOGLE_CLOUD_UNIVERSE_DOMAIN,
  });
  const query = claimPredictQuery(claim);
  console.log(query);

  const queryResponse = await bigqueryClient.query(query);

  return queryResponse[0][0];
}

function claimPredictQuery(claim) {
  console.log(claim.toJSON());

  return `
SELECT
  claim_id,
  GREATEST(0.0, LEAST(100.0, predicted_risk_score)) as predicted_risk_score
FROM
  ML.PREDICT(MODEL \`${MODEL_ID}\`, (
    SELECT
        '${claim.claim_id}' as claim_id,
        COALESCE(SAFE_CAST(COALESCE(CAST(${claim.amount_billed} AS STRING), '0') AS NUMERIC), CAST(0 AS NUMERIC)) as amount_billed,
        COALESCE(SAFE_CAST(COALESCE(CAST(${claim.public_insurance_base} AS STRING), '0') AS NUMERIC), CAST(0 AS NUMERIC)) as public_insurance_base,
        COALESCE(SAFE_CAST(COALESCE(CAST(${claim.mutuelle_coverage} AS STRING), '0') AS NUMERIC), CAST(0 AS NUMERIC)) as mutuelle_coverage,
        '${claim.Provider.provider_type}' as provider_type,
        '${claim.ServiceType.service_category}' as service_category,
        COALESCE(SAFE_CAST(COALESCE(CAST(${calculateProcessingTimeDays(claim)} AS STRING), '0') AS INT64), 0) as processing_time_days,

        'Unknown' as patient_gender,
        ${patientAge(claim)} as patient_age,

        COALESCE(${claim.RiskAnalysis?.is_documentation_complete ?? false}, FALSE) as is_documentation_complete,
        COALESCE(${claim.RiskAnalysis?.is_provider_flagged ?? false}, FALSE) as is_provider_flagged,
        COALESCE(${claim.RiskAnalysis?.is_amount_unusual ?? false}, FALSE) as is_amount_unusual,
        COALESCE(${claim.RiskAnalysis?.is_service_unusual ?? false}, FALSE) as is_service_unusual,

        COALESCE(SAFE_CAST(COALESCE(CAST(${null} AS STRING), '0') AS NUMERIC), CAST(0 AS NUMERIC)) as customer_responsibility,
        COALESCE(SAFE_CAST(COALESCE(CAST(${null} AS STRING), '0') AS INT64), 0) as documentation_count,
        COALESCE(${null}, 'Unknown') as provider_specialty,
        COALESCE(${null}, 'Unknown') as plan_tier
    )
  )
`;
}

function patientAge(claim) {
  return Math.round(
    new Date().getFullYear() -
      new Date(claim.Customer.date_of_birth).getFullYear(),
  );
}

function calculateProcessingTimeDays(claim) {
  const MILIS_IN_ONE_DAY = 1000 * 60 * 60 * 24;

  if (!claim.processed_at) return null;
  if (!claim.date_of_service) return null;

  return Math.round(
    (claim.processed_at.getTime() - new Date(claim.date_of_service).getTime()) /
      MILIS_IN_ONE_DAY,
  );
}
