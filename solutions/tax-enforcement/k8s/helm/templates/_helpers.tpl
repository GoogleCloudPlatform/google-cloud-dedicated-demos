#
# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
{{/*
Expand the name of the chart.
*/}}
{{- define "tax-office.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "tax-office.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "tax-office.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "tax-office.labels" -}}
helm.sh/chart: {{ include "tax-office.chart" . }}
{{ include "tax-office.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "tax-office.selectorLabels" -}}
app.kubernetes.io/name: {{ include "tax-office.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Jupyter labels
*/}}
{{- define "tax-office.jupyter.labels" -}}
{{ include "tax-office.labels" . }}
app: jupyter
{{- end }}

{{/*
Jupyter selector labels
*/}}
{{- define "tax-office.jupyter.selectorLabels" -}}
{{ include "tax-office.selectorLabels" . }}
app: jupyter
{{- end }}

{{/*
Tax App labels
*/}}
{{- define "tax-office.taxApp.labels" -}}
{{ include "tax-office.labels" . }}
app: tax-office-app
{{- end }}

{{/*
Tax App selector labels
*/}}
{{- define "tax-office.taxApp.selectorLabels" -}}
{{ include "tax-office.selectorLabels" . }}
app: tax-office-app
{{- end }}

{{/*
vLLM labels
*/}}
{{- define "tax-office.vllm.labels" -}}
{{ include "tax-office.labels" . }}
app: gemma-server
{{- end }}

{{/*
vLLM selector labels
*/}}
{{- define "tax-office.vllm.selectorLabels" -}}
{{ include "tax-office.selectorLabels" . }}
app: gemma-server
{{- end }}
