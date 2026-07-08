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
CREATE TABLE customers (
    customer_id VARCHAR(50) PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    date_of_birth DATE NOT NULL,
    email VARCHAR(100),
    phone VARCHAR(20),
    address VARCHAR(200),
    city VARCHAR(50),
    postal_code VARCHAR(50),
    country VARCHAR(50) DEFAULT 'France',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insurance Plans Table
CREATE SEQUENCE insurance_plans_plan_id_seq;

CREATE TABLE insurance_plans (
    plan_id INT DEFAULT nextval('insurance_plans_plan_id_seq') PRIMARY KEY,
    plan_name VARCHAR(100) NOT NULL,
    plan_description TEXT,
    coverage_details TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

ALTER SEQUENCE insurance_plans_plan_id_seq OWNED BY insurance_plans.plan_id;

-- Customer Plans Table (many-to-many relationship)
CREATE SEQUENCE customer_plans_customer_plan_id_seq;

CREATE TABLE customer_plans (
    customer_plan_id INT DEFAULT nextval('customer_plans_customer_plan_id_seq') PRIMARY KEY,
    customer_id VARCHAR(50) NOT NULL,
    plan_id INT NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE,
    status VARCHAR(50) DEFAULT 'Active' CHECK (status IN ('Active', 'Inactive', 'Pending', 'Expired')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    FOREIGN KEY (plan_id) REFERENCES insurance_plans(plan_id),
    UNIQUE (customer_id, plan_id, start_date)
);

ALTER SEQUENCE customer_plans_customer_plan_id_seq OWNED BY customer_plans.customer_plan_id;

-- Providers Table
CREATE SEQUENCE providers_provider_id_seq;

CREATE TABLE providers (
    provider_id INT DEFAULT nextval('providers_provider_id_seq') PRIMARY KEY,
    provider_name VARCHAR(100) NOT NULL,
    provider_type VARCHAR(20) CHECK (provider_type IN ('Doctor', 'Hospital', 'Clinic', 'Pharmacy', 'Laboratory', 'Imaging Center', 'Other')) NOT NULL,
    specialization VARCHAR(100),
    address VARCHAR(200),
    city VARCHAR(50),
    postal_code VARCHAR(50),
    country VARCHAR(50) DEFAULT 'France',
    contact_person VARCHAR(100),
    email VARCHAR(100),
    phone VARCHAR(20),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

ALTER SEQUENCE providers_provider_id_seq OWNED BY providers.provider_id;

-- Service Types Table
CREATE SEQUENCE service_types_service_type_id_seq;

CREATE TABLE service_types (
    service_type_id INT DEFAULT nextval('service_types_service_type_id_seq') PRIMARY KEY,
    service_name VARCHAR(100) NOT NULL,
    service_description TEXT,
    service_category VARCHAR(50),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

ALTER SEQUENCE service_types_service_type_id_seq OWNED BY service_types.service_type_id;

-- Claims Table
CREATE TABLE claims (
    claim_id VARCHAR(20) PRIMARY KEY,
    customer_id VARCHAR(50) NOT NULL,
    provider_id INT NOT NULL,
    service_type_id INT NOT NULL,
    date_of_service DATE NOT NULL,
    date_submitted DATE NOT NULL,
    amount_billed DECIMAL(10, 2) NOT NULL,
    public_insurance_base DECIMAL(10, 2) NOT NULL,
    mutuelle_coverage DECIMAL(10, 2) NOT NULL,
    status VARCHAR(15) DEFAULT 'Submitted' CHECK (status IN ('Submitted', 'Under Review', 'Approved', 'Flagged', 'Rejected', 'Paid')),
    status_reason TEXT,
    processed_by VARCHAR(50),
    processed_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    FOREIGN KEY (provider_id) REFERENCES providers(provider_id),
    FOREIGN KEY (service_type_id) REFERENCES service_types(service_type_id)
);

-- Claim Documents Table
CREATE SEQUENCE claim_documents_document_id_seq;

CREATE TABLE claim_documents (
    document_id INT DEFAULT nextval('claim_documents_document_id_seq') PRIMARY KEY,
    claim_id VARCHAR(20) NOT NULL,
    document_type VARCHAR(50) NOT NULL,
    document_path VARCHAR(255) NOT NULL,
    uploaded_by VARCHAR(50),
    uploaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (claim_id) REFERENCES claims(claim_id)
);

ALTER SEQUENCE claim_documents_document_id_seq OWNED BY claim_documents.document_id;

-- Risk Analysis Table
CREATE SEQUENCE risk_analysis_analysis_id_seq;

CREATE TABLE risk_analysis (
    analysis_id INT DEFAULT nextval('risk_analysis_analysis_id_seq') PRIMARY KEY,
    claim_id VARCHAR(20) NOT NULL,
    risk_score DECIMAL(5, 2),
    is_duplicate BOOLEAN DEFAULT FALSE,
    is_documentation_complete BOOLEAN DEFAULT TRUE,
    is_provider_flagged BOOLEAN DEFAULT FALSE,
    is_amount_unusual BOOLEAN DEFAULT FALSE,
    is_service_unusual BOOLEAN DEFAULT FALSE,
    recommendation VARCHAR(30) CHECK (recommendation IN ('Approve', 'Request Information', 'Request Documentation', 'Investigate', 'Reject')) NOT NULL,
    analysis_notes TEXT,
    analyzed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (claim_id) REFERENCES claims(claim_id)
);

ALTER SEQUENCE risk_analysis_analysis_id_seq OWNED BY risk_analysis.analysis_id;

-- Audit Logs Table
CREATE SEQUENCE audit_logs_log_id_seq;

CREATE TABLE audit_logs (
    log_id INT DEFAULT nextval('audit_logs_log_id_seq') PRIMARY KEY,
    entity_type VARCHAR(50) NOT NULL,
    entity_id VARCHAR(50) NOT NULL,
    action VARCHAR(50) NOT NULL,
    action_details TEXT,
    performed_by VARCHAR(50) NOT NULL,
    performed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

ALTER SEQUENCE audit_logs_log_id_seq OWNED BY audit_logs.log_id;
