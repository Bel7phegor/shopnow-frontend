  {{/*
  Expand the name of the chart.
  */}}
  {{- define "template-project.name" -}}
  {{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
  {{- end }}

  {{/*
  Create a default fully qualified app name.
  We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
  If release name contains chart name it will be used as a full name.
  */}}
  {{- define "template-project.fullname" -}}
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
  {{- define "template-project.chart" -}}
  {{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
  {{- end }}

  {{/*
  Common labels
  */}}
  {{- define "template-project.labels" -}}
  helm.sh/chart: {{ include "template-project.chart" . }}
  {{ include "template-project.selectorLabels" . }}
  {{- if .Chart.AppVersion }}
  app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
  {{- end }}
  app.kubernetes.io/managed-by: {{ .Release.Service }}
  {{- end }}

  {{/*
  Selector labels
  */}}
  {{- define "template-project.selectorLabels" -}}
  app.kubernetes.io/name: {{ include "template-project.name" . }}
  app.kubernetes.io/instance: {{ .Release.Name }}
  {{- end }}

  {{/*
  Create the name of the service account to use
  */}}
  {{- define "template-project.serviceAccountName" -}}
  {{- if .Values.serviceAccount.create }}
  {{- default (include "template-project.fullname" .) .Values.serviceAccount.name }}
  {{- else }}
  {{- default "default" .Values.serviceAccount.name }}
  {{- end }}
  {{- end }}

  {{- define "template-project.deploymentName" -}}
  {{- printf "%s-deployment" (include "template-project.fullname" .) | trunc 63 | trimSuffix "-" -}}
  {{- end -}}

  {{- define "template-project.serviceName" -}}
  {{- printf "%s-service" (include "template-project.fullname" .) | trunc 63 | trimSuffix "-" -}}
  {{- end -}}

  {{- define "template-project.ingressName" -}}
  {{- printf "%s-ingress" (include "template-project.fullname" .) | trunc 63 | trimSuffix "-" -}}
  {{- end -}}

  {{- define "template-project.hpaName" -}}
  {{- printf "%s-hpa" (include "template-project.fullname" .) | trunc 63 | trimSuffix "-" -}}
  {{- end -}}

  {{- define "template-project.configmapName" -}}
  {{- printf "%s-configmap" (include "template-project.fullname" .) | trunc 63 | trimSuffix "-" -}}
  {{- end -}}

  {{- define "template-project.secretName" -}}
  {{- printf "%s-secret" (include "template-project.fullname" .) | trunc 63 | trimSuffix "-" -}}
  {{- end -}}
