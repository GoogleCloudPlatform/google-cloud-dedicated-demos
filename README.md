# Sovereign AI Reference Architectures for Google Cloud Dedicated

## What is Google Cloud Dedicated?

[Google Cloud Dedicated](http://goo.gle/sovereign-cloud) (GCD) creates a
separate, standalone 'universe' of Google Cloud services, based on dedicated
hardware, with sales, support, and operations by a local partner. It is
engineered specifically for regulated industries like the public sector and
healthcare with strict sovereignty requirements. While it is built on the same
industry-leading technologies that power Google's public cloud, the Google Cloud
Dedicated instances in France and Germany are operated exclusively by fully
independent local providers (such as [S3NS](https://www.s3ns.io/en) in France).

This hybrid approach offers the best of both worlds by wrapping hyperscale
innovation in local control. Google Cloud Dedicated translates this sovereignty
from a policy objective into a reality. A key benefit of this architecture is
that customers can receive the latest in cloud features, while knowing that all
updates are strictly monitored, reviewed, inspected, and approved by the local
partner. Further, given the exclusively local and independent operations, Google
does not have any access to customer data nor can it disrupt service
availability to customers.

## Sovereign AI in Practice: A Reference Implementation

Google Cloud Dedicated brings Google’s advanced, optimized AI stack directly
into the dedicated sovereign infrastructure. Because your data lifecycle is
entirely contained within the local region, model training and inference happen
locally. Your proprietary datasets and strategic insights never leave the
platform boundary, ensuring you can lead with cutting-edge AI agents while
remaining perfectly compliant with regional mandates.

This repository is intended to get you started with Google Cloud Dedicated by
providing practical examples of AI solutions and more broadly, acquainting you
with the product. The demonstration contained herein is the first of many that
show how Google Cloud Dedicated can meet stringent sovereign needs, answering
key questions such as: how can I innovate with my data?

**Please note that these examples are provided as educational demos; they are
not audited, optimized, or intended for production deployment.**

We are actively working to expand this repository with additional examples over
the next couple of months. Stay tuned.

### Sovereign Tax Anomaly Detection with BigQuery ML & Gemma

This [Tax Anomaly Detection](./demos/tax-office) sample application leverages
BigQuery ML and a RAG pipeline with Google’s open-weight Gemma LLM to optimize
tax enforcement while ensuring data sovereignty. Built for regulated industries
and the public financial sector, the architecture guarantees local data
residency by running all operations within Google Cloud Dedicated
infrastructure.

As the first in a series of reference architectures for regulated public
sectors, this application provides a blueprint for secure, localized AI
innovation.

Follow the [Tax Anomaly Detection - User Guide](./demos/tax-office/README.md)
for a step-by-step walkthrough to deploy the infrastructure and workflow.

### Sovereign Health Insurance Risk Analysis with BigQuery ML & Gemma

This [Health Insurance Risk Analysis](./demos/insurance) sample application
demonstrates how to optimize health insurance risk analysis and claims
verification while ensuring data sovereignty. By leveraging BigQuery ML for
health risk modeling and a regional open-weight Gemma LLM for claims document
verification, the architecture guarantees local data residency within Google
Cloud Dedicated infrastructure.

As another key reference architecture for highly regulated sectors, this
application provides a blueprint for secure, localized data modeling and
automated claim checks.

Follow the
[Health Insurance Risk Analysis - User Guide](./demos/insurance/README.md) for a
step-by-step walkthrough to deploy the infrastructure and verification workflow.

## General Prerequisites & Setup

Before starting, you must be onboarded on Google Cloud Dedicated (GCD) by your
partner of choice and have your identity provider and permissions configured.
Note that this is a prerequisite for all other steps. You can refer to the
[S3NS documentation](https://documentation.s3ns.fr/docs/get-started-tpc/set-up-identity-provider)
as an example of the organisation setup process.

### Configuration Reference

The following table provides a detailed Configuration Reference across various
GCD environments, as compared to GCP. Please replace the placeholders in the
commands and configurations given in each demo README with the values
corresponding to your target universe.

Variable | GCP | GCD France (GA) | GCD Germany (Preview)
--- | --- | --- | ---
`UNIVERSE_WEB_DOMAIN` | `cloud.google.com` | `cloud.s3nscloud.fr` | `cloud.berlin-build0.goog`
`UNIVERSE_API_DOMAIN` | `googleapis.com` | `s3nsapis.fr` | `apis-berlin-build0.goog`
`UNIVERSE_NAME` | `google` | `s3ns` | `berlin`
`UNIVERSE_PREFIX` | n/a | `s3ns` | `eu0`
`UNIVERSE_REGION` | n/a | `u-france-east1` | `u-germany-northeast1`

### Google Cloud CLI

Initialize the gcloud CLI for your GCD universe. Use the values from the
Configuration Reference table to replace the `<PLACEHOLDERS>` in the commands
below.

First, create a Workforce Identity Federation (WIF) login configuration:

```bash
AUDIENCE=locations/global/workforcePools/mypool/providers/myprovider
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

Once the above file has been created and the gcloud profile configured, run the
following command to login to the organization with gcloud. This will prompt a
web browser that will allow login to the organization with the configured IdP.

```bash
gcloud auth login \
  --login-config=$WF_POOL_FILE_PATH/wif-login-config-$UNIVERSE_NAME.json \
  --no-launch-browser

gcloud auth application-default login \
  --login-config=$WF_POOL_FILE_PATH/wif-login-config-$UNIVERSE_NAME.json
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
