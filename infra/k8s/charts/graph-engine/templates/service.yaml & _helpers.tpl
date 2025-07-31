# File: infra/k8s/charts/graph-engine/templates/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ include "graph-engine.fullname" . }}
  labels:
    {{- include "graph-engine.labels" . | nindent 4 }}
spec:
  type: {{ .Values.service.type }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: 80
      protocol: TCP
      name: http
  selector:
    {{- include "graph-engine.selectorLabels" . | nindent 4 }}
---
# File: infra/k8s/charts/graph-engine/templates/_helpers.tpl
{{- define "graph-engine.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "graph-engine.fullname" -}}
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

{{- define "graph-engine.labels" -}}
helm.sh/chart: {{ include "graph-engine.name" . }}-{{ .Chart.Version | replace "+" "_" }}
{{ include "graph-engine.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "graph-engine.selectorLabels" -}}
app.kubernetes.io/name: {{ include "graph-engine.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "graph-engine.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "graph-engine.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
