{{/*
Expand the name of the chart.
*/}}
{{- define "service-example.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "service-example.fullname" -}}
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
{{- define "service-example.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "service-example.labels" -}}
helm.sh/chart: {{ include "service-example.chart" . }}
{{ include "service-example.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "service-example.selectorLabels" -}}
app.kubernetes.io/name: {{ include "service-example.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "service-example.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "service-example.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the MongoDB connection string
*/}}
{{- define "service-example.mongodb-connection-string" -}}
{{- if and .Values.mongodb.auth.enabled .Values.mongodb.auth.existingSecret }}

- name: MONGO_PASS
  valueFrom:
    secretKeyRef:
      name: {{ .Values.mongodb.auth.existingSecret | quote }}
      key: mongodb-passwords

- name: Aspire__MongoDB__Driver__ConnectionString
  value: {{ printf "mongodb://%s:$(MONGO_PASS)@%s-mongodb:%d/%s?authSource=%s" 
      .Values.mongodb.auth.username 
      .Release.Name 
      ((default 27017 .Values.mongodb.service.ports.mongodb) | int)
      .Values.mongodb.auth.database 
      .Values.mongodb.auth.database 
    | quote }}

{{- else if and .Values.mongodb.auth.enabled .Values.mongodb.auth.password }}

- name: Aspire__MongoDB__Driver__ConnectionString
  value: {{ printf "mongodb://%s:%s@%s-mongodb:%d/%s?authSource=%s" 
      .Values.mongodb.auth.username 
      .Values.mongodb.auth.password 
      .Release.Name 
      ((default 27017 .Values.mongodb.service.ports.mongodb) | int)
      .Values.mongodb.auth.database 
      .Values.mongodb.auth.database 
    | quote }}

{{- else }}

- name: Aspire__MongoDB__Driver__ConnectionString
  value: {{ printf "mongodb://%s-mongodb:%d" 
      .Release.Name 
      ((default 27017 .Values.mongodb.service.ports.mongodb) | int)
    | quote }}

{{- end }}
{{- end }}

{{/*
Create the Redis connection string
*/}}
{{- define "service-example.redis-connection-string" -}}

{{- if and .Values.redis.auth.enabled .Values.redis.auth.existingSecret }}

- name: REDIS_PASS
  valueFrom:
    secretKeyRef:
      name: {{ .Values.redis.auth.existingSecret | quote }}
      key: redis-password

- name: Aspire__StackExchange__Redis__ConnectionString
  value: {{ printf "redis://:$(REDIS_PASS)@%s-redis-master:%d"
      .Release.Name
      ((default 6379 .Values.redis.master.service.ports.redis) | int)
    | quote }}

{{- else if and .Values.redis.auth.enabled .Values.redis.auth.password }}

- name: Aspire__StackExchange__Redis__ConnectionString
  value: {{ printf "redis://:%s@%s-redis-master:%d"
      .Values.redis.auth.password
      .Release.Name
      ((default 6379 .Values.redis.master.service.ports.redis) | int)
    | quote }}

{{- else }}

- name: Aspire__StackExchange__Redis__ConnectionString
  value: {{ printf "redis://%s-redis-master:%d"
      .Release.Name
      ((default 6379 .Values.redis.master.service.ports.redis) | int)
    | quote }}

{{- end }}
{{- end }}

{{/*
Create the NATS connection string
*/}}
{{- define "service-example.nats-connection-string" -}}

{{- if and .Values.nats.auth.enabled .Values.nats.auth.existingSecret }}

- name: NATS_USER
  valueFrom:
    secretKeyRef:
      name: {{ .Values.nats.auth.existingSecret | quote }}
      key: username

- name: NATS_PASS
  valueFrom:
    secretKeyRef:
      name: {{ .Values.nats.auth.existingSecret | quote }}
      key: password

- name: Aspire__NATS__Net__ConnectionString
  value: {{ printf "nats://$(NATS_USER):$(NATS_PASS)@%s-nats:%d"
      .Release.Name
      ((default 4222 .Values.nats.config.nats.port) | int)
    | quote }}

{{- else if and .Values.nats.auth.enabled .Values.nats.auth.username .Values.nats.auth.password }}

- name: Aspire__NATS__Net__ConnectionString
  value: {{ printf "nats://%s:%s@%s-nats:%d"
      .Values.nats.auth.username
      .Values.nats.auth.password
      .Release.Name
      ((default 4222 .Values.nats.config.nats.port) | int)
    | quote }}

{{- else }}

- name: Aspire__NATS__Net__ConnectionString
  value: {{ printf "nats://%s-nats:%d"
      .Release.Name
      ((default 4222 .Values.nats.config.nats.port) | int)
    | quote }}

{{- end }}
{{- end }}
