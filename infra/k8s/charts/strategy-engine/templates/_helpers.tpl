{{/*
QuantumArb 2.0 - Helm Helper Templates

File: infra/k8s/charts/strategy-engine/templates/_helpers.tpl

Description:
This file contains common helper templates used throughout the chart.
Using helpers promotes code reuse and keeps the main templates clean.
*/}}

{{/*
Expand the name of the chart.
*/}}
{{- define "strategy-engine.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this length.
*/}}
{{- define "strategy-engine.fullname" -}}
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
Create chart labels.
*/}}
{{- define "strategy-engine.labels" -}}
helm.sh/chart: {{ include "strategy-engine.name" . }}-{{ .Chart.Version | replace "+" "_" }}
{{ include "strategy-engine.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Create the selector labels for the service and deployment.
*/}}
{{- define "strategy-engine.selectorLabels" -}}
app.kubernetes.io/name: {{ include "strategy-engine.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use.
*/}}
{{- define "strategy-engine.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "strategy-engine.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
