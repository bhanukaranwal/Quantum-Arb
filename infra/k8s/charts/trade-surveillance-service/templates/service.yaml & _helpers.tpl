# File: infra/k8s/charts/trade-surveillance-service/templates/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ include "trade-surveillance-service.fullname" . }}
  labels:
    {{- include "trade-surveillance-service.labels" . | nindent 4 }}
spec:
  type: {{ .Values.service.type }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: http
      protocol: TCP
      name: http
  selector:
    {{- include "trade-surveillance-service.selectorLabels" . | nindent 4 }}
---
# File: infra/k8s/charts/trade-surveillance-service/templates/_helpers.tpl
{{- define "trade-surveillance-service.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "trade-surveillance-service.fullname" -}}
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

{{- define "trade-surveillance-service.labels" -}}
helm.sh/chart: {{ include "trade-surveillance-service.name" . }}-{{ .Chart.Version | replace "+" "_" }}
{{ include "trade-surveillance-service.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "trade-surveillance-service.selectorLabels" -}}
app.kubernetes.io/name: {{ include "trade-surveillance-service.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "trade-surveillance-service.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "trade-surveillance-service.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
