# Sovereign Health Insurance Risk Analysis with BigQuery ML & Gemma

## Overview

This sample application demonstrates how to optimize health insurance risk
analysis and data sovereignty by leveraging BigQuery ML as a unified machine
learning platform, integrated with an AI verification pipeline utilizing
Google’s open-weight Gemma LLM.

**Please note that this is a proof-of-concept prototype built for demonstration
purposes, and the implementation is not audited or secured for production use
cases. All data used in this demonstration—including claims, patient names,
billing amounts, and insurance plans—is entirely fictional and generated
programmatically. Any resemblance to real persons, entities, or actual policies
is purely coincidental.**

### Business Use Case: Sovereign Health Insurance Risk Analysis

In highly regulated environments, such as the healthcare and insurance sectors,
the ability to analyze health risks and verify customer claims while keeping
data strictly in-country is a mission-critical requirement.

This application provides a blueprint for solving these challenges. Insurance
providers can deploy BigQuery ML on GCD to analyze health risk scores, model
plans, and claims databases in real time. Simultaneously, a local, open-weight
Gemma LLM system performs verification on claim documentation stored in GCS.
This ensures context-aware compliance and full auditability — all without ever
making external API calls or moving data outside the sovereign boundary.

### Target Audience

This solution is designed for national healthcare agencies or regulated
insurance providers. It serves the following stakeholders:

-   **Auditors & Claims Investigators**: Review showroom dashboards to verify
    submitted claim documents, audit flagged cases, and interact with the AI
    assistant.
-   **Data Scientists**: Securely access raw data via JupyterLab environments to
    build, validate, and run native health risk analysis models.

### Core Capabilities

-   **Sovereign Health Modeling**: Utilize native BigQuery ML to screen claims
    and customer datasets to identify health risk factors without moving data
    outside the sovereign boundary.
-   **AI Claim Verification**: Execute localized document checks using
    open-weight Gemma LLM to verify claim details against database records.
-   **Interactive Chatbot Widget**: Query active database claims and receive
    real-time, context-aware answers using the AI assistant chatbot.
-   **Seamless JupyterLab Analytics**: Access a dedicated Jupyter environment
    preloaded with direct database connection variables and Workload Identity
    bindings.

### Components

Component    | Tech       | Purpose
:----------- | :--------- | :------
**Infra**    | Terraform  | Provision VPC, GKE, Cloud SQL Postgres, BigQuery, GCS.
**Database** | Cloud SQL  | Storage for insurance claims, plans, and customers.
**DWH**      | BigQuery   | Data Warehouse analytical tables and big data storage.
**Model**    | BQML       | Machine learning analysis on health risk scores.
**LLM**      | Gemma      | Open-weight model (google/gemma-3-27b-it) for claim document verification and chatbot widget.
**Analysis** | JupyterLab | Dedicated notebooks preloaded with active data.
**App**      | Node.js    | Web app showroom dashboard.

### Project Structure Overview

This table outlines the main directories within the project repository and their
primary responsibilities.

Folder        | Description
:------------ | :---------------------------------------------------------
**scripts**   | Scripts for deployment and destruction.
**app**       | Frontend and backend Node.js web showroom source code.
**k8s**       | Kubernetes manifest files (Helm chart and Kustomize).
**samples**   | Sample datasets (CSVs) and claim documents.
**schema**    | Relational DDL tables and BigQuery Data Warehouse schemas.
**terraform** | Infrastructure-related Terraform configurations.

## Deploying Health Insurance Risk Analysis Sample Application

### Prerequisites

1.  **Google Cloud Project:** A Sovereign Dedicated Cloud project with billing
    enabled.
2.  **gcloud CLI:** The Google Cloud SDK installed and authenticated.
3.  **Terraform:** Terraform CLI (v1.5+) installed.
4.  **Docker:** Docker daemon running for internal Artifact Registry image
    mirroring.
5.  **Kubernetes Tools:** `kubectl` and `helm` binaries installed.

### Deployment Configuration

Before initiating the deployment process, you must complete the following
critical configurations to ensure proper authentication and resource linking
within your Google Cloud Project.

1.  Initialize the gcloud CLI for your GCD universe using Workforce Identity
    Federation by following the instructions
    [here](../../README.md#google-cloud-cli).

2.  Enable Cloud Resource Manager API. Ensure the Cloud Resource Manager API is
    explicitly enabled within your GCD Project's console. This is necessary for
    managing project resources.

3.  Provide Hugging Face token:

    -   The Gemma LLM model is hosted on
        [Hugging Face](https://huggingface.co/), a community platform for
        sharing machine learning models, datasets, and applications. To download
        the model during deployment, you need an access token.
    -   **Where to get a token:** Create a free account at
        [huggingface.co](https://huggingface.co/) and generate a **Read** access
        token in your
        [Settings > Tokens](https://huggingface.co/settings/tokens) page.
    -   **Model Access:** Before deploying, make sure you have requested and
        been granted access to the
        [Gemma model](https://huggingface.co/google/gemma-3-27b-it) on Hugging
        Face (this typically requires accepting Google's license terms).
    -   Once you have the token, update the `hugging_face_token` parameter value
        in the `terraform.tfvars` file with your newly created token in the next
        step.

4.  **Update `terraform.tfvars`:**

    Before deployment, navigate to `terraform` and update the `terraform.tfvars`
    file with your **mandatory** project-specific values.

    Variable                      | Status        | Description
    :---------------------------- | :------------ | :----------
    `project_id`                  | **Mandatory** | Your GCD Project ID.
    `region`                      | **Mandatory** | Resource region (e.g., `u-germany-northeast1`).
    `universe_domain`             | **Mandatory** | Sovereign Universe API domain.
    `claims_document_bucket_name` | **Mandatory** | Globally unique GCS bucket name.
    `hugging_face_token`          | **Mandatory** | Hugging Face User Access Token (Read) for gated model downloads.
    `jupyter_password`            | **Mandatory** | JupyterLab password.
    `app_login_user`              | **Mandatory** | Web Showroom Dashboard login username (default: `admin`).
    `app_login_password`          | **Mandatory** | Web Showroom Dashboard login password.

#### Gemma Model Usage & Deployment

The demo uses the open source [vLLM library](https://docs.vllm.ai/en/stable/) to
automatically download and deploy models via its native Hugging Face
[integration](https://docs.vllm.ai/en/v0.7.0/design/huggingface_integration.html).

##### Data Privacy & Localization:

Once the model weights are downloaded, all communication with Hugging Face
servers ceases. All subsequent LLM requests are processed entirely locally
within your environment — no data is ever sent back to external servers. This
setup is optimized for standard demo reliability and security.

##### Customizing for Strict Sovereignty:

If downloading directly from Hugging Face does not meet your specific data
sovereignty requirements, you can modify the vLLM Kubernetes deployment
configuration located at `k8s/helm/templates/vllm/`. For example, you can:

-   Pre-download the model to local storage from an approved provider.
-   Implement checksum verification to ensure model integrity.
-   Update the Helm templates to mount and point vLLM to your localized storage.

### Deployment Scripts

The entire pipeline is orchestrated by a set of shell scripts located in the
`scripts` directory.

#### Full Deployment

The `full_deploy.sh` script handles the entire workflow: infrastructure
provisioning, database creation, Artifact Registry creation, base image
mirroring, web application container building, database initial seeding, dynamic
secret generation, and Helm chart deployment.

```bash
# Run the full deployment script
./scripts/full_deploy.sh
```

Upon completion, the script will output the external IP addresses for the **Web
Showroom Dashboard** and the **JupyterLab Platform**.

> IMPORTANT:
>
> **Wait for Deployment:** It may take **~20 minutes** for all pods to be fully
> deployed and ready. The Gemma LLM model deployment, in particular, requires
> significant time to pull and initialize.

## Access and Usage

The JupyterLab platform is configured with the password set during deployment.
The Web Showroom Dashboard is secured behind an **Insurance App Login** modal
requiring credentials.

### Restricting Public Access

Once deployment is complete, the public IP addresses for JupyterLab and the Web
Showroom Dashboard will be displayed.

⚠️ **Critical Security Note**: By default, no firewall rules or access
restrictions are applied to these GKE endpoints, making them accessible to
anyone on the internet.

If you plan to leave this demo running long-term, please secure your environment
using one of the following methods:

-   **IP Restriction**: Limit incoming traffic exclusively to your internal IP
    subnets.
-   **Private Endpoints**: Reconfigure the GKE services to disable public IP
    exposure entirely.

### JupyterLab Platform

The JupyterLab platform will be ready once the `full_deploy.sh` script has
finished running:

1.  Click the provided **IP address** to open the deployed JupyterLab interface.
2.  Log in using the password provided in `terraform.tfvars`
3.  Once logged in, open the `health_insurance_risk_analysis.ipynb` notebook.
4.  From the **Run** menu, select **Run All Cells** to execute the validation.

The notebook environment is fully loaded with active database connection
variables and Workload Identity bindings!

### Web Showroom Dashboard

Once the deployment script completes successfully, you can access the
interactive dashboard using the provided external IP address. Follow this
step-by-step flow to navigate the application and simulate an auditor workflow:

1.  **Access the Dashboard**: Click the provided IP address to open the Web
    Showroom Dashboard. Authenticate in the **Insurance App Login** modal
    using your credentials provided in `terraform.tfvars` to unlock the platform.
2.  **Review Real-Time Claims**: The main dashboard displays claims data,
    customer records, and health risk scores.
3.  **Analyze Claim Verification**: Click on a specific claim row (e.g.,
    `9375-21` or `9381-04`) to trigger the AI Claim Verification engine. The
    system automatically pulls the document stored in GCS and uses the Gemma LLM
    to verify patient and service details.
4.  **Interact with the AI Assistant**: Click the Assistant IA chat window in
    the dashboard to interact with the Gemma LLM chatbot. You can ask it to
    filter claims, summarize flagged cases, explain vocabulary, or translate
    terms in real time.

## Testing with Sample Documents & AI Chatbot

The repository contains sample claims and documentation to simulate both active
database claims and claim document validation. **Please note that all datasets,
claim records, patient names, and document attachments provided in this
repository are entirely fictional.** Testing your deployment involves verifying
how these data sources interact.

### 1. AI Claim Verification & Sample Documents

The platform uses an LLM (`google/gemma-3-27b-it`) to verify if the submitted
claim documentation matches the claim details (such as Patient Name, Date of
Service, Provider, and Amount).

*   **Verification**: The LLM performs verification using documents stored in
    GCS. Sample documents are provided in the `samples/claims/` folder and
    uploaded to GCS during deployment.
*   **Seeded Claims**: Sample documents are provided for:
    *   **Passing Claims (Matching Docs)**:
    -   `9375-21` -> Matches cardiology consultation (accepted as Health
        specialist consultation).
    -   `CL-10001` -> Matches GP visit.
    -   `CL-10002` -> Matches orthopedic consultation.
    -   `CL-10003` -> Matches hospitalization.
    -   `CL-10004` -> Matches physiotherapy.
    -   `CL-10005` -> Matches GP visit.
    *   **Failing Claims (Mismatching/Missing Docs)**:
    -   `9381-04` -> Mismatch (Missing Cost Verification): Imaging Report does
        not list the billed amount (450€); BigQuery also flags due to high risk
        score.
    -   `CL-10006` -> Mismatch in Patient Name & Amount (claims Sophie Bernard,
        450€).
    -   `CL-10007` -> Mismatch in Provider & Service (claims Dr. Marie Exemple,
        Cardiology).
    -   `CL-10008` -> Mismatch in Date of Service (claims 2025-02-20 instead of
        2025-01-20).
*   **Missing Documentation**: Any other claim clicked in the dashboard will not
    have documents in GCS, and the LLM will correctly flag them as "Missing
    documentation" and recommend rejection.

### 2. Assistant IA Chatbot (Live RAG & LLM Examples)

The web dashboard embeds an intelligent chatbot widget (**Assistant IA**)
powered by `google/gemma-3-27b-it` on vLLM. It reads a live compact JSON
snapshot of active database claims (~2,500 tokens), providing real-time
contextual answers.

#### Usage Scenarios

Here are the 4 main ways to use your assistant on a daily basis:

1.  **Inspect a Specific Claim:** *"Can you give me the summary and billed
    amount for Jean Petit (claim 9375-21)?"*
2.  **Filter & Scan Claims in One Second:** *"List all visible claims where the
    billed amount exceeds 1,000 €."* or *"Which patients had a cardiology
    consultation?"*
3.  **Understand Flags & Warnings:** *"Why is claim CL-10020 marked as
    'Flagged'?"* or *"What do you recommend I check regarding Catherine Martin's
    submission?"*
4.  **Explain Vocabulary or Translate:** *"What is the exact difference between
    Régime Obligatoire (Base) and Mutuelle coverage?"* or *"Peux-tu traduire ta
    dernière réponse en français ?"*

#### Chat Prompts to Test

Here are 4 usage examples you can test directly in the chat popup:

1.  **Exact Claim & Patient Lookup:** > *"What is the billed amount and status
    for claim 9381-04 (Sophie Bernard)?"*
2.  **Threshold Aggregation & Filtering:** > *"List all visible reimbursement
    claims exceeding 1,000 €."*
3.  **Auditing Flagged Discrepancies:** > *"Can you explain why claim CL-10020
    is marked as flagged?"*
4.  **Bilingual Insurance Terminology:** > *"What is the difference between
    Régime Obligatoire and Mutuelle?"*

## Cleanup

To destroy all cloud resources created by Terraform (GKE Autopilot, Cloud SQL
Postgres, GCS Buckets, VPC, Artifact Registry) and delete active Helm charts,
run the destroy script.

⚠️ **This action is irreversible.**

```bash
# Run the full destruction script
./scripts/full_destroy.sh
```

---

```
Copyright 2026 Google LLC

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    https://www.apache.org/licenses/LICENSE-2.0


Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
