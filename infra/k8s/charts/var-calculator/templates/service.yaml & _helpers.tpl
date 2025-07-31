# File: infra/k8s/charts/var-calculator/templates/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ include "var-calculator.fullname" . }}
  labels:
    {{- include "var-calculator.labels" . | nindent 4 }}
spec:
  type: {{ .Values.service.type }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: http
      protocol: TCP
      name: http
  selector:
    {{- include "var-calculator.selectorLabels" . | nindent 4 }}
---
# File: infra/k8s/charts/var-calculator/templates/_helpers.tpl
{{- define "var-calculator.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "var-calculator.fullname" -}}
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

{{- define "var-calculator.labels" -}}
helm.sh/chart: {{ include "var-calculator.name" . }}-{{ .Chart.Version | replace "+" "_" }}
{{ include "var-calculator.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "var-calculator.selectorLabels" -}}
app.kubernetes.io/name: {{ include "var-calculator.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "var-calculator.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "var-calculator.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
