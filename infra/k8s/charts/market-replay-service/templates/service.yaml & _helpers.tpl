# File: infra/k8s/charts/market-replay-service/templates/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ include "market-replay-service.fullname" . }}
  labels:
    {{- include "market-replay-service.labels" . | nindent 4 }}
spec:
  type: {{ .Values.service.type }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: 80 # Default target port, can be adjusted if service exposes one
      protocol: TCP
      name: http
  selector:
    {{- include "market-replay-service.selectorLabels" . | nindent 4 }}
---
# File: infra/k8s/charts/market-replay-service/templates/_helpers.tpl
{{- define "market-replay-service.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "market-replay-service.fullname" -}}
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

{{- define "market-replay-service.labels" -}}
helm.sh/chart: {{ include "market-replay-service.name" . }}-{{ .Chart.Version | replace "+" "_" }}
{{ include "market-replay-service.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "market-replay-service.selectorLabels" -}}
app.kubernetes.io/name: {{ include "market-replay-service.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "market-replay-service.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "market-replay-service.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
