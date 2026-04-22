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
| **k8s** | **Kubernetes manifest files** (Kustomize). |
| **terraform** | Infrastructure-related **Terraform code**. |
| **docs** | Readme specific files. |

## **👷‍♀️ Architecture diagram**

![Tax Office](docs/tax_office.png)

## **🛠️ Prerequisites**

1. **Google Cloud Project:** A GCP project with billing enabled.
2. **gcloud CLI:** The Google Cloud SDK installed and authenticated.
3. **Terraform:** Terraform CLI installed.
4. **Docker:** Docker daemon running for image building and pushing. The user
   account executing these operations must have the necessary permissions to
   communicate with the Docker daemon. On Linux systems, this typically means
   the user needs to be a member of the `docker` group.
5. **Python 3:** Python 3.9+ with pip and venv enabled.

## **⚙️ Deployment Pre-configuration Checklist**

The entire pipeline is orchestrated by a set of shell scripts located in the
./scripts directory.

Before initiating the deployment process, you must complete the following
critical configurations to ensure proper authentication and resource linking
within your Google Cloud Project.

### **Authentication and API Setup**

1. Log in to GCP.

   ```bash
   gcloud auth login --login-config=/your_path/wif-login-config.json
   gcloud auth application-default login
   ```

2. Enable Cloud Resource Manager API. Ensure the Cloud Resource Manager API is
   explicitly enabled within your GCP Project's console. This is necessary for
   managing project resources.

3. Update Docker Image Registry Path in Kubernetes Deployment

    ```none
     * File: k8s/tax-office-base/tax-app/tax-app-deployment.yaml
     * Change the image line to follow this pattern:
       image: "docker.pkg-berlin-build0.goog/eu0/<prj_name>/tax-office-app-registry/tax-office-app:latest"
   ```

4. Update Project ID in Jupyter Notebook

    ```none
     * File: k8s/tax-office-base/jupyter/notebooks/default/anomaly_detector.ipynb
     * Search for and update: PROJECT_ID = 'eu0:svr-bigquery-demo'
   ```

5. Update Project ID in BigQuery Python Client

    ```none
     * File: app/backend/bigquery_client.py
     * Search for and update:** PROJECT_ID = 'eu0:svr-bigquery-demo'
    ```

6. Before deployment, navigate to terraform and ensure the
   terraform.tfvars file contains the necessary cloud-specific variables
   (project_id, region, universe_domain, bucket_name, etc.). See
   default.auto.tfvars.example for reference. Pay special attention to the
   bucket_name variable, as Google Cloud Storage bucket names must be globally
   unique and follow the Bucket naming guidelines:
   <https://docs.cloud.google.com/storage/docs/buckets#naming>

7. Create assets foler:

```bash
mkdir -p terraform/assets
```

1. Provide Hugging Face token:

```bash
echo YOUR_HUGGING_FACE_TOKEN > k8s/tax-office-base/hugging-face-token.yaml
```

### **2. Full Deployment**

The full_deploy.sh script handles the entire workflow: data generation,
infrastructure, image build/push, and application deployment.

```bash
# Navigate to the scripts directory
cd scripts
# Run the full deployment script
./full_deploy.sh
```

Upon completion, the script will output the external IP addresses for the **Tax
Office Dashboard** and the **Jupyter Notebook**. _Note_: you might need to wait
~15 minutes until pods get fully deployed (deployment of Gemma model will take
some time).

### **3. Jupyter Notebook**

The **Jupyter Notebook service** will be ready once the full_deploy script has
finished running.

1. Click the provided **IP address** to open the deployed Jupyter Notebook.
2. Use the following for authentication:
    * **Password:** demobq
3. Once logged in, open **anomaly\_detector.ipynb**.
4. From the **Run** menu, select **Run All Cells**.

This script will automatically create the **Machine Learning model** and all
related **views**.

### **4. Access Credentials**

The web applications are configured with static demo credentials, will be also
available under ip address which you will get once full_deploy ends:

* **Username:** demo
* **Password:** demobq

### **5. Standalone deployments**

We have scripts under `04-Taxoffice/scripts/standalone` in case you want to
deploy each component separately. Make sure you run first:

```bash
source standalone/deploy_infra.sh
```

As it sets necessary environment variables for all other standalone scripts.

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
