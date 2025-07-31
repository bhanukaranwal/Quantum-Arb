# File: infra/k8s/charts/data-bus-connector/templates/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ include "data-bus-connector.fullname" . }}
  labels:
    {{- include "data-bus-connector.labels" . | nindent 4 }}
spec:
  type: {{ .Values.service.type }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: http
      protocol: TCP
      name: http
  selector:
    {{- include "data-bus-connector.selectorLabels" . | nindent 4 }}
---
# File: infra/k8s/charts/data-bus-connector/templates/_helpers.tpl
{{- define "data-bus-connector.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "data-bus-connector.fullname" -}}
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

{{- define "data-bus-connector.labels" -}}
helm.sh/chart: {{ include "data-bus-connector.name" . }}-{{ .Chart.Version | replace "+" "_" }}
{{ include "data-bus-connector.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "data-bus-connector.selectorLabels" -}}
app.kubernetes.io/name: {{ include "data-bus-connector.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "data-bus-connector.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "data-bus-connector.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
