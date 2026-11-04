{{/* Service/workload names are fixed (loci-db, loci-auth, ...) — one release per namespace. */}}

{{- define "loci.labels" -}}
app.kubernetes.io/part-of: loci
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end }}

{{/* Usage: include "loci.selector" "loci-db" */}}
{{- define "loci.selector" -}}
app.kubernetes.io/name: {{ . }}
{{- end }}

{{- define "loci.host" -}}
{{- required "Set .Values.host (the IP or hostname users open, e.g. --set host=192.168.1.5)" .Values.host -}}
{{- end }}

{{- define "loci.publicUrl" -}}
https://{{ include "loci.host" . }}
{{- end }}

{{- define "loci.tlsSecret" -}}
{{- if .Values.tls.generate -}}loci-tls{{- else -}}{{ required "tls.existingSecret is required when tls.generate=false" .Values.tls.existingSecret }}{{- end -}}
{{- end }}

{{/* initContainer that blocks until Postgres accepts TCP connections (i.e. after the seed has run) */}}
{{- define "loci.waitForDb" -}}
- name: wait-for-db
  image: {{ .Values.postgres.image }}
  command: ["sh", "-c", "until pg_isready -h loci-db -p 5432; do echo waiting for loci-db; sleep 2; done"]
{{- end }}
