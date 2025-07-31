# File: infra/k8s/charts/exchange-gateway/templates/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ include "exchange-gateway.fullname" . }}
  labels:
    {{- include "exchange-gateway.labels" . | nindent 4 }}
spec:
  type: {{ .Values.service.type }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: http
      protocol: TCP
      name: http
  selector:
    {{- include "exchange-gateway.selectorLabels" . | nindent 4 }}
---
# File: infra/k8s/charts/exchange-gateway/templates/_helpers.tpl
{{- define "exchange-gateway.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "exchange-gateway.fullname" -}}
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

{{- define "exchange-gateway.labels" -}}
helm.sh/chart: {{ include "exchange-gateway.name" . }}-{{ .Chart.Version | replace "+" "_" }}
{{ include "exchange-gateway.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "exchange-gateway.selectorLabels" -}}
app.kubernetes.io/name: {{ include "exchange-gateway.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "exchange-gateway.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "exchange-gateway.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
