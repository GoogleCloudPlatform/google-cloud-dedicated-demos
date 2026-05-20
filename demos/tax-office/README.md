# **🇪🇺 Tax Anomaly Detection Platform (Sovereign Cloud)**

This project provides an end-to-end solution for detecting potential anomalies
in tax declarations using Google Cloud services, focusing on a **Sovereign
Cloud** architecture.

The solution encompasses data generation, infrastructure provisioning
(Terraform), model training (BigQuery ML), application deployment (Flask
dashboard and Jupyter notebook on GKE), and Gemma LLM model integration with RAG
database.

## **🚀 Core Components**

| Component | Tech | Purpose |
| :--- | :--- | :--- |
| **Data** | Python | Generate tax data (TRAINING/NEW\_FILING). |
| **Infra** | Terraform | Provision VPC, GKE, BQ, GCS, Registry. |
| **Model** | BQ ML | Logistic Regression for anomaly detection. |
| **LLM** | Gemma | Gemma for enhancing Tax policy info. |
| **RAG** | Vector DB | BigQuery Vector Search feature. |
| **APP** | Flask | Web app for prediction visualization. |
| **Analysis** | Jupyter | Notebook for ML analysis/validation. |

## 📂 **Project Structure Overview**

This table outlines the main directories within the project repository and
their primary responsibilities.

| Folder | Description |
| :--- | :--- |
| **scripts** | Scripts for deployment and destruction. |
| **app** | **Frontend**, **backend**, and **generator**. |
| **policies** | Policy docs for creating embeddings. |
| **k8s** | **Kubernetes manifest files** (Helm charts). |
| **terraform** | Infrastructure-related **Terraform code**. |
| **docs** | Readme specific files. |

## **👷‍♀️ Architecture diagram**

![Tax Office](docs/tax_office.png)

## **🛠️ Prerequisites**

1. **Google Cloud Project:** A GCD project with billing enabled.
2. **gcloud CLI:** The Google Cloud SDK installed and authenticated.
3. **Terraform:** Terraform CLI installed.
4. **Docker:** Docker daemon running for image building and pushing. The user
   account executing these operations must have the necessary permissions to
   communicate with the Docker daemon. On Linux systems, this typically means
   the user needs to be a member of the `docker` group.
5. **Python 3:** Python 3.9+ with pip and venv enabled.
6. **kubectl**, **helm** binaries installed.

## **⚙️ Deployment Pre-configuration Checklist**

The entire pipeline is orchestrated by a set of shell scripts located in the
./scripts directory.

Before initiating the deployment process, you must complete the following
critical configurations to ensure proper authentication and resource linking
within your Google Cloud Project.

### **Configuration reference**

| Variable | GCD In France (GA) | GCD In Germany (Preview) |
| --- | --- | --- |
| `UNIVERSE_WEB_DOMAIN` | `cloud.s3nscloud.fr` | `cloud.berlin-build0.goog` |
| `UNIVERSE_API_DOMAIN` | `s3nsapis.fr` | `apis-berlin-build0.goog` |
| `UNIVERSE_NAME` | `s3ns` | `berlin` |
| `UNIVERSE_PREFIX` | `s3ns` | `eu0` |
| `UNIVERSE_REGION` | `u-france-east1` | `u-germany-northeast1` |

### 1. **Authentication and API Setup**

1. Login in to GCD.

   Initialize the gcloud CLI for your GCD universe. Use the values from the
   Configuration Reference table to replace the `<PLACEHOLDERS>` in the commands
   below.

   First, create a Workforce Identity Federation (WIF) login configuration:

   ```bash
   AUDIENCE=locations/global/workforcePools/<WORKFORCE_POOL_ID>/providers/<WIF_PROVIDER_ID>
   # Replace with values from the Configuration Reference table
   UNIVERSE_WEB_DOMAIN="<UNIVERSE_WEB_DOMAIN>"
   UNIVERSE_API_DOMAIN="<UNIVERSE_API_DOMAIN>"
   UNIVERSE_NAME="<UNIVERSE_NAME>"
   WF_POOL_FILE_PATH="/tmp"

   gcloud config configurations create $UNIVERSE_NAME
   gcloud config configurations activate $UNIVERSE_NAME
   gcloud config set universe_domain $UNIVERSE_API_DOMAIN

   gcloud iam workforce-pools create-login-config $AUDIENCE \
     --universe-cloud-web-domain="$UNIVERSE_WEB_DOMAIN" \
     --universe-domain="$UNIVERSE_API_DOMAIN" \
     --output-file="$WF_POOL_FILE_PATH/wif-login-config-$UNIVERSE_NAME.json" \
     --activate
   ```

   Once the above file has been created and the gcloud profile configured,
   run the following command to login to the organization with gcloud.
   This will prompt a web browser that will allow login to the organization
   with the configured IdP.

   ```bash
   gcloud auth login \
     --login-config=$WF_POOL_FILE_PATH/wif-login-config-$UNIVERSE_NAME.json \
     --no-launch-browser

   gcloud auth application-default login \
     --login-config=$WF_POOL_FILE_PATH/wif-login-config-$UNIVERSE_NAME.json
   ```

2. Enable Cloud Resource Manager API. Ensure the Cloud Resource Manager API is
   explicitly enabled within your GCD Project's console. This is necessary for
   managing project resources.

3. Get and provide Hugging Face token:

   The Gemma LLM model is hosted on [Hugging Face](https://huggingface.co/), a
   community platform for sharing machine learning models, datasets, and
   applications. To download the model during deployment, you need an access
   token.

   * **Where to get a token:** Create a free account at
     [huggingface.co](https://huggingface.co/) and generate a **Read** access
     token in your [Settings > Tokens](https://huggingface.co/settings/tokens)
     page.
   * **Model Access:** Before deploying, make sure you have requested and been
     granted access to the [Gemma model](https://huggingface.co/google/gemma-3-27b-it)
     on Hugging Face (this typically requires accepting Google's license terms).

   Once you have the token, update the `hugging_face_token` parameter value in 
   `terraform.tfvars` file with your newly created token in next step.

4. Before deployment, navigate to `terraform` and update the `terraform.tfvars`
   file with your **mandatory** project-specific values.

   | Variable | Status | Description |
   | :--- | :--- | :--- |
   | `project_id` | **Mandatory** | Your GCD Project ID. |
   | `region` | **Mandatory** | Resource region (e.g., `u-germany-northeast1`). |
   | `universe_api_domain` | **Mandatory** | Sovereign Universe API domain. |
   | `data_bucket_name ` | **Mandatory** | Unique backet name. |
   | `hugging_face_token` | **Mandatory** | Your hugging face token. |
   | `demo_password` | **Mandatory** | Password for demologin to dashboard and Jupyter Notebook. |
   

### **2. Full Deployment**

The `full_deploy.sh` script handles the entire workflow: data generation,
infrastructure, image build/push, and application deployment.

```bash
# Navigate to the scripts directory
cd scripts
# Run the full deployment script
./full_deploy.sh
```

Upon completion, the script will output the external IP addresses for the **Tax
Office Dashboard** and the **Jupyter Notebook**.

> IMPORTANT:
>
> **Wait for Deployment:** It may take **~15 minutes** for all pods to be fully
> deployed and ready. The Gemma LLM model deployment, in particular, requires
> significant time to pull and initialize.

### **3. Log in to the Jupyter Notebook**

1. Click the provided **IP address** to open the deployed Jupyter Notebook.
2. Use the credentials (see [Access Credentials](#5-access-credentials)
   below) to log in.
3. Once logged in, open `anomaly_detector.ipynb`.
4. From the **Run** menu, select **Run All Cells**.

This script will automatically create the **Machine Learning model** and all
related **views**.

### **4. Log in to the Main Dashboard**

1. Click the provided **IP address** to open the Main Dashboard.
2. Use the credentials (see [Access Credentials](#5-access-credentials)
   below) to log in.

### **5. Access Credentials**

The web applications and Jupyter Notebook are configured with static `demo` login 
by default. Password you should take from `demo_password` in `terraform.tfvars`.

## **6. Standalone deployments**

We have scripts under `scripts/standalone` in case you want to deploy each component separately. Make sure you run first:

```bash
source standalone/deploy_infra.sh
```


## **🔥 Cleanup**

To destroy all cloud resources created by Terraform (GKE, VPC, BigQuery, GCS,
Artifact Registry) and clean up local data artifacts, run the destroy
script. **This action is irreversible.**

```bash
# Navigate to the scripts directory
cd scripts
# Run the full destruction script (requires confirmation)
./full_destroy.sh
```

## **❓ Troubleshooting**

### **Terraform Destroy Failures**

Occasionally, the `full_destroy.sh` script may fail during the Terraform
destruction phase with an error similar to:

```none
Error: Error waiting for Deleting Network: The network resource '...' is
already being used by '.../networkEndpointGroups/...'
```

This happens when GKE Network Endpoint Groups (NEGs) or VPC routes created
by Kubernetes Ingress resources are not fully deprovisioned by the Google
Cloud controller before Terraform attempts to delete the network.

**Solution:**

1. Manually delete the offending Network Endpoint Groups (NEGs) in the Google
Cloud Console or using the `gcloud` CLI.
2. Once the NEGs are removed, re-run the `full_destroy.sh` script to complete
 the cleanup.

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
