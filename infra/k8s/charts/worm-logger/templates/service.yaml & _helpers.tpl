# File: infra/k8s/charts/worm-logger/templates/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ include "worm-logger.fullname" . }}
  labels:
    {{- include "worm-logger.labels" . | nindent 4 }}
spec:
  type: {{ .Values.service.type }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: http
      protocol: TCP
      name: http
  selector:
    {{- include "worm-logger.selectorLabels" . | nindent 4 }}
---
# File: infra/k8s/charts/worm-logger/templates/_helpers.tpl
{{- define "worm-logger.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "worm-logger.fullname" -}}
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

{{- define "worm-logger.labels" -}}
helm.sh/chart: {{ include "worm-logger.name" . }}-{{ .Chart.Version | replace "+" "_" }}
{{ include "worm-logger.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "worm-logger.selectorLabels" -}}
app.kubernetes.io/name: {{ include "worm-logger.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "worm-logger.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "worm-logger.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
