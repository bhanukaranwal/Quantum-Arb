# File: infra/k8s/charts/latency-oracle/templates/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ include "latency-oracle.fullname" . }}
  labels:
    {{- include "latency-oracle.labels" . | nindent 4 }}
spec:
  type: {{ .Values.service.type }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: http
      protocol: TCP
      name: http
  selector:
    {{- include "latency-oracle.selectorLabels" . | nindent 4 }}
---
# File: infra/k8s/charts/latency-oracle/templates/_helpers.tpl
{{- define "latency-oracle.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "latency-oracle.fullname" -}}
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

{{- define "latency-oracle.labels" -}}
helm.sh/chart: {{ include "latency-oracle.name" . }}-{{ .Chart.Version | replace "+" "_" }}
{{ include "latency-oracle.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "latency-oracle.selectorLabels" -}}
app.kubernetes.io/name: {{ include "latency-oracle.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "latency-oracle.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "latency-oracle.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
