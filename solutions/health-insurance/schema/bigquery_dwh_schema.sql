--
-- Copyright 2026 Google LLC
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     https://www.apache.org/licenses/LICENSE-2.0
--
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--
-- BigQuery Data Warehouse Schema for Claims Processing Analytics (Simplified)

-- Historical Customers Table (Flattened)
CREATE TABLE historical_customers (
    customer_id STRING NOT NULL,
    first_name STRING NOT NULL,
    last_name STRING NOT NULL,
    full_name STRING NOT NULL,
    date_of_birth DATE,
    age INTEGER,
    age_band STRING,
    gender STRING,
    email STRING,
    phone STRING,
    address STRING,
    city STRING,
    postal_code STRING,
    country STRING,
    region STRING,
    income_band STRING,
    occupation STRING,
    family_size INTEGER,
    marital_status STRING,
    has_children BOOLEAN,
    num_children INTEGER,
    primary_language STRING,
    customer_since DATE,
    customer_segment STRING,
    customer_status STRING,
    is_active BOOLEAN,
    last_contact_date DATE,
    preferred_contact_method STRING,
    max_plan_tier STRING,
    plan_count INTEGER,
    total_premium_paid NUMERIC,
    ltv_prediction NUMERIC,
    churn_risk_score NUMERIC,
    loyalty_points INTEGER,
    nps_score INTEGER,
    etl_batch_id STRING,
    load_timestamp TIMESTAMP NOT NULL,
    data_source STRING NOT NULL
) OPTIONS(
    description="Historical flattened customer data with demographics for analysis"
);

-- Historical Claims Table (Flattened)
CREATE TABLE historical_claims (
    claim_id STRING NOT NULL,
    claim_reference_number STRING,
    customer_id STRING NOT NULL,
    patient_name STRING NOT NULL,
    patient_dob DATE,
    patient_age INTEGER,
    patient_gender STRING,
    provider_id INTEGER NOT NULL,
    provider_name STRING NOT NULL,
    provider_type STRING NOT NULL,
    provider_specialty STRING,
    provider_city STRING,
    provider_postal_code STRING,
    provider_region STRING,
    provider_country STRING,
    service_type_id INTEGER NOT NULL,
    service_name STRING NOT NULL,
    service_category STRING,
    service_description STRING,
    treatment_description STRING,
    medical_code STRING,
    diagnosis_code STRING,
    plan_id INTEGER NOT NULL,
    plan_name STRING NOT NULL,
    plan_tier STRING,
    date_of_service DATE NOT NULL,
    date_submitted DATE NOT NULL,
    date_processed DATE,
    date_of_service_year INTEGER,
    date_of_service_quarter STRING,
    date_of_service_month STRING,
    processing_time_days INTEGER,
    status STRING NOT NULL,
    sub_status STRING,
    status_reason STRING,
    processed_by STRING,
    amount_billed NUMERIC NOT NULL,
    public_insurance_base NUMERIC NOT NULL,
    mutuelle_coverage NUMERIC NOT NULL,
    customer_responsibility NUMERIC,
    deductible_applied NUMERIC,
    copay_amount NUMERIC,
    coverage_percentage NUMERIC,
    discount_amount NUMERIC,
    risk_score NUMERIC,
    risk_category STRING,
    is_duplicate BOOLEAN,
    is_documentation_complete BOOLEAN,
    is_provider_flagged BOOLEAN,
    is_amount_unusual BOOLEAN,
    is_service_unusual BOOLEAN,
    documentation_count INTEGER,
    recommendation STRING,
    fraud_probability NUMERIC,
    was_appealed BOOLEAN,
    appeal_outcome STRING,
    analysis_notes STRING,
    analyzed_at TIMESTAMP,
    analysis_version STRING,
    model_id STRING,
    is_resubmission BOOLEAN,
    original_claim_id STRING,
    etl_batch_id STRING,
    load_timestamp TIMESTAMP NOT NULL,
    data_source STRING NOT NULL
) OPTIONS(
    description="Historical flattened claims data including risk analysis for comprehensive analytics"
);
