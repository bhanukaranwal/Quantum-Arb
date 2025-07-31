# File: infra/k8s/charts/risk-gateway/templates/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ include "risk-gateway.fullname" . }}
  labels:
    {{- include "risk-gateway.labels" . | nindent 4 }}
spec:
  type: {{ .Values.service.type }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: http
      protocol: TCP
      name: http
  selector:
    {{- include "risk-gateway.selectorLabels" . | nindent 4 }}
---
# File: infra/k8s/charts/risk-gateway/templates/_helpers.tpl
{{- define "risk-gateway.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "risk-gateway.fullname" -}}
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

{{- define "risk-gateway.labels" -}}
helm.sh/chart: {{ include "risk-gateway.name" . }}-{{ .Chart.Version | replace "+" "_" }}
{{ include "risk-gateway.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "risk-gateway.selectorLabels" -}}
app.kubernetes.io/name: {{ include "risk-gateway.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "risk-gateway.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "risk-gateway.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
