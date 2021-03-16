{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "cloudman.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "cloudman.fullname" -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "cloudman.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "cloudman.keycloak_url" -}}
{{- printf "%s://auth.%s/auth" .Values.ingress.protocol (.Values.global.domain | default (index .Values.ingress.hosts 0)) }} 
{{- end -}}

{{/*
Rancher config settings
*/}}
{{- define "cloudman.cluster_config" -}}
{{- if .Values.cm_initial_cluster_data -}}
{{ .Values.cm_initial_cluster_data }}
{{- end -}}
rke_config:
  rke_cluster_id: {{ .Values.global.domain }}
  rke_registration_server: {{ .Values.rke_registration_server }}
  rke_registration_token: {{ .Values.rke_registration_token }}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "keycloak_data.name" -}}
{{- printf "%s-keycloak" .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Generate an ID for KeyCloak objects.
*/}}
{{- define "keycloak_data.random_id" -}}
{{- printf "%s-%s-%s-%s-%s" (randAlphaNum 8) (randAlphaNum 4) (randAlphaNum 4) (randAlphaNum 4) (randAlphaNum 12) | lower -}}
{{- end -}}

{{/*
Generate root URL
*/}}
{{- define "cloudman.root_url" -}}
{{.Values.cloudlaunch.cloudlaunchserver.ingress.protocol }}://{{ .Values.global.domain | default (index .Values.cloudlaunch.cloudlaunchserver.ingress.hosts 0) }}
{{- end -}}

{{/*
influxdb service url
*/}}
{{- define "cloudman.influxdb_url_cluster" -}}
{{- printf "http://%s-influxdb.%s.svc.cluster.local:8086" .Release.Name .Release.Namespace -}}
{{- end -}}

{{/*
influxdb service url
*/}}
{{- define "cloudman.influxdb_url_local" -}}
{{- printf "http://%s-influxdb:8086" .Release.Name  -}}
{{- end -}}

{{/*
influxdb database name
Currently, must match the database name created by influxdb startup scripts
This can be overridden by creating a custom database on startup
*/}}
{{- define "cloudman.influxdb_database" -}}
{{- printf "telegraf" -}}
{{- end -}}

{{/*
Return password for postgres keycloak user
*/}}
{{- define "cloudman.dbKeycloakPassword" -}}
{{- if .Values.keycloak.keycloak.persistence.dbPassword }}
    {{- .Values.keycloak.keycloak.persistence.dbPassword -}}
{{- else -}}
    {{- randAlphaNum 10 -}}
{{- end -}}
{{- end -}}

{{/*
Return password for keycloak admin user
*/}}
{{- define "cloudman.httpKeycloakPassword" -}}
{{- if .Values.keycloak.keycloak.password }}
    {{- .Values.keycloak.keycloak.password -}}
{{- else -}}
    {{- randAlphaNum 10 -}}
{{- end -}}
{{- end -}}
