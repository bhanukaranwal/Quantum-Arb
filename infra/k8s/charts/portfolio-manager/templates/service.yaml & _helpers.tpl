# File: infra/k8s/charts/portfolio-manager/templates/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ include "portfolio-manager.fullname" . }}
  labels:
    {{- include "portfolio-manager.labels" . | nindent 4 }}
spec:
  type: {{ .Values.service.type }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: http
      protocol: TCP
      name: http
  selector:
    {{- include "portfolio-manager.selectorLabels" . | nindent 4 }}
---
# File: infra/k8s/charts/portfolio-manager/templates/_helpers.tpl
{{- define "portfolio-manager.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "portfolio-manager.fullname" -}}
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

{{- define "portfolio-manager.labels" -}}
helm.sh/chart: {{ include "portfolio-manager.name" . }}-{{ .Chart.Version | replace "+" "_" }}
{{ include "portfolio-manager.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "portfolio-manager.selectorLabels" -}}
app.kubernetes.io/name: {{ include "portfolio-manager.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "portfolio-manager.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "portfolio-manager.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
