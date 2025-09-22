{{/*
Expand the name of the chart.
*/}}
{{- define "happy-speller.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "happy-speller.fullname" -}}
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

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "happy-speller.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "happy-speller.labels" -}}
helm.sh/chart: {{ include "happy-speller.chart" . }}
{{ include "happy-speller.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.labels }}
{{- toYaml . }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "happy-speller.selectorLabels" -}}
app.kubernetes.io/name: {{ include "happy-speller.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "happy-speller.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "happy-speller.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Generate basic auth secret name
*/}}
{{- define "happy-speller.basicAuthSecret" -}}
{{- printf "%s-basic-auth" (include "happy-speller.fullname" .) -}}
{{- end }}

{{/*
Generate TLS secret name
*/}}
{{- define "happy-speller.tlsSecret" -}}
{{- printf "%s-tls" (include "happy-speller.fullname" .) -}}
{{- end }}