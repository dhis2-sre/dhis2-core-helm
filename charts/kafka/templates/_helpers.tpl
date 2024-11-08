{{/*
Expand the name of the chart.
*/}}
{{- define "kafka.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "kafka.fullname" -}}
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
{{- define "kafka.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "kafka.labels" -}}
helm.sh/chart: {{ include "kafka.chart" . }}
{{ include "kafka.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "kafka.selectorLabels" -}}
app.kubernetes.io/name: {{ include "kafka.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "kafka.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "kafka.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Kraft section of the server.properties
*/}}
{{- define "kafka.kraftConnectConfig" -}}
#node.id=
#controller.listener.names={{ .Values.listeners.controller.name }}
#controller.quorum.voters={{ include "kafka.kraft.controllerQuorumVoters" . }}
{{- $listener := $.Values.listeners.controller }}
{{- if and $listener.sslClientAuth (regexFind "SSL" (upper $listener.protocol)) }}
# Kraft Controller listener SSL settings
listener.name.{{lower $listener.name}}.ssl.client.auth={{ $listener.sslClientAuth }}
{{- end }}
{{- if regexFind "SASL" (upper $listener.protocol) }}
  {{- $mechanism := $.Values.sasl.controllerMechanism }}
  {{- $securityModule := include "kafka.saslSecurityModule" (dict "mechanism" (upper $mechanism)) }}
  {{- $saslJaasConfig := list $securityModule }}
  {{- if (eq (upper $mechanism) "OAUTHBEARER") }}
  {{- $saslJaasConfig = append $saslJaasConfig (printf "clientId=\"%s\"" $.Values.sasl.controller.clientId) }}
  {{- $saslJaasConfig = append $saslJaasConfig (print "clientSecret=\"controller-client-secret-placeholder\"") }}
  {{- else }}
  {{- $saslJaasConfig = append $saslJaasConfig (printf "username=\"%s\"" $.Values.sasl.controller.user) }}
  {{- $saslJaasConfig = append $saslJaasConfig (print "password=\"controller-password-placeholder\"") }}
  {{- end }}
  {{- if eq (upper $mechanism) "PLAIN" }}
  {{- $saslJaasConfig = append $saslJaasConfig (printf "user_%s=\"controller-password-placeholder\"" $.Values.sasl.controller.user) }}
  {{- end }}
# Kraft Controller listener SASL settings
sasl.mechanism.controller.protocol={{ upper $mechanism }}
listener.name.{{lower $listener.name}}.sasl.enabled.mechanisms={{ upper $mechanism }}
listener.name.{{lower $listener.name}}.{{lower $mechanism }}.sasl.jaas.config={{ join " " $saslJaasConfig }};
{{- if regexFind "OAUTHBEARER" (upper $mechanism) }}
listener.name.{{lower $listener.name}}.oauthbearer.sasl.server.callback.handler.class=org.apache.kafka.common.security.oauthbearer.secured.OAuthBearerValidatorCallbackHandler
listener.name.{{lower $listener.name}}.oauthbearer.sasl.login.callback.handler.class=org.apache.kafka.common.security.oauthbearer.secured.OAuthBearerLoginCallbackHandler
{{- end }}
{{- end }}
{{- end -}}

{{/*
Init container definition for Kafka initialization
*/}}
{{- define "kafka.prepareKafkaConnectInitContainer" -}}
{{- $role := .role -}}
{{- $roleSettings := index .context.Values .role -}}
- name: kafka-init-connect
  image: {{ include "kafka.image" .context }}
  imagePullPolicy: {{ .context.Values.image.pullPolicy }}
  {{- if $roleSettings.containerSecurityContext.enabled }}
  securityContext: {{- include "common.compatibility.renderSecurityContext" (dict "secContext" $roleSettings.containerSecurityContext "context" .context) | nindent 4 }}
  {{- end }}
  {{- if $roleSettings.initContainerResources }}
  resources: {{- toYaml $roleSettings.initContainerResources | nindent 4 }}  
  {{- end }} 
  command:
    - /bin/bash
  args:
    - -ec
    - |
      echo "Configuring Connect environment"
      /scripts-connect/kafka-init-connect.sh
  env:
    - name: BITNAMI_DEBUG
      value: {{ ternary "true" "false" (or .context.Values.image.debug .context.Values.diagnosticMode.enabled) | quote }}
    - name: MY_POD_NAME
      valueFrom:
        fieldRef:
            fieldPath: metadata.name
    - name: KAFKA_VOLUME_DIR
      value: {{ $roleSettings.persistence.mountPath | quote }}
    - name: KAFKA_MIN_ID
      value: {{ $roleSettings.minId | quote }}
    {{- if or (and (eq .role "broker") .context.Values.externalAccess.enabled) (and (eq .role "controller") .context.Values.externalAccess.enabled (or .context.Values.externalAccess.controller.forceExpose (not .context.Values.controller.controllerOnly))) }}
    {{- $externalAccess := index .context.Values.externalAccess .role }}
    - name: EXTERNAL_ACCESS_ENABLED
      value: "true"
    {{- if eq $externalAccess.service.type "LoadBalancer" }}
    {{- if not .context.Values.externalAccess.autoDiscovery.enabled }}
    - name: EXTERNAL_ACCESS_HOSTS_LIST
      value: {{ join "," (default $externalAccess.service.loadBalancerIPs $externalAccess.service.loadBalancerNames) | quote }}
    {{- end }}
    - name: EXTERNAL_ACCESS_PORT
      value: {{ $externalAccess.service.ports.external | quote }}
    {{- else if eq $externalAccess.service.type "NodePort" }}
    {{- if $externalAccess.service.domain }}
    - name: EXTERNAL_ACCESS_HOST
      value: {{ $externalAccess.service.domain | quote }}
    {{- else if and $externalAccess.service.usePodIPs .context.Values.externalAccess.autoDiscovery.enabled }}
    - name: MY_POD_IP
      valueFrom:
        fieldRef:
          fieldPath: status.podIP
    - name: EXTERNAL_ACCESS_HOST
      value: "$(MY_POD_IP)"
    {{- else if or $externalAccess.service.useHostIPs .context.Values.externalAccess.autoDiscovery.enabled }}
    - name: HOST_IP
      valueFrom:
        fieldRef:
          fieldPath: status.hostIP
    - name: EXTERNAL_ACCESS_HOST
      value: "$(HOST_IP)"
    {{- else if and $externalAccess.service.externalIPs (not .context.Values.externalAccess.autoDiscovery.enabled) }}
    - name: EXTERNAL_ACCESS_HOSTS_LIST
      value: {{ join "," $externalAccess.service.externalIPs }}
    {{- else }}
    - name: EXTERNAL_ACCESS_HOST_USE_PUBLIC_IP
      value: "true"
    {{- end }}
    {{- if not .context.Values.externalAccess.autoDiscovery.enabled }}
    {{- if and $externalAccess.service.externalIPs (empty $externalAccess.service.nodePorts)}}
    - name: EXTERNAL_ACCESS_PORT
      value: {{ $externalAccess.service.ports.external | quote }}
    {{- else }}
    - name: EXTERNAL_ACCESS_PORTS_LIST
      value: {{ join "," $externalAccess.service.nodePorts | quote }}
    {{- end }}
    {{- end }}
    {{- else if eq $externalAccess.service.type "ClusterIP" }}
    - name: EXTERNAL_ACCESS_HOST
      value: {{ $externalAccess.service.domain | quote }}
    - name: EXTERNAL_ACCESS_PORT
      value: {{ $externalAccess.service.ports.external | quote}}
    - name: EXTERNAL_ACCESS_PORT_AUTOINCREMENT
      value: "true"
    {{- end }}
    {{- end }}
    {{- if and (include "kafka.client.saslEnabled" .context ) .context.Values.sasl.client.users }}
    {{- if (include "kafka.saslUserPasswordsEnabled" .context) }}
    - name: KAFKA_CLIENT_USERS
      value: {{ join "," .context.Values.sasl.client.users | quote }}
    - name: KAFKA_CLIENT_PASSWORDS
      valueFrom:
        secretKeyRef:
          name: {{ include "kafka.saslSecretName" .context }}
          key: client-passwords
    {{- end }}
    {{- end }}
    {{- if regexFind "SASL" (upper .context.Values.listeners.interbroker.protocol) }}
    {{- if (include "kafka.saslUserPasswordsEnabled" .context) }}
    - name: KAFKA_INTER_BROKER_USER
      value: {{ .context.Values.sasl.interbroker.user | quote }}
    - name: KAFKA_INTER_BROKER_PASSWORD
      valueFrom:
        secretKeyRef:
          name: {{ include "kafka.saslSecretName" .context }}
          key: inter-broker-password
    {{- end }}
    {{- if (include "kafka.saslClientSecretsEnabled" .context) }}
    - name: KAFKA_INTER_BROKER_CLIENT_ID
      value: {{ .context.Values.sasl.interbroker.clientId | quote }}
    - name: KAFKA_INTER_BROKER_CLIENT_SECRET
      valueFrom:
        secretKeyRef:
          name: {{ include "kafka.saslSecretName" .context }}
          key: inter-broker-client-secret
    {{- end }}
    {{- end }}
    {{- if and .context.Values.kraft.enabled (regexFind "SASL" (upper .context.Values.listeners.controller.protocol)) }}
    {{- if (include "kafka.saslUserPasswordsEnabled" .context) }}
    - name: KAFKA_CONTROLLER_USER
      value: {{ .context.Values.sasl.controller.user | quote }}
    - name: KAFKA_CONTROLLER_PASSWORD
      valueFrom:
        secretKeyRef:
          name: {{ include "kafka.saslSecretName" .context }}
          key: controller-password
    {{- end }}
    {{- if (include "kafka.saslClientSecretsEnabled" .context) }}
    - name: KAFKA_CONTROLLER_CLIENT_ID
      value: {{ .context.Values.sasl.controller.clientId | quote }}
    - name: KAFKA_CONTROLLER_CLIENT_SECRET
      valueFrom:
        secretKeyRef:
          name: {{ include "kafka.saslSecretName" .context }}
          key: controller-client-secret
    {{- end }}
    {{- end }}
    {{- if (include "kafka.sslEnabled" .context )  }}
    - name: KAFKA_TLS_TYPE
      value: {{ ternary "PEM" "JKS" (or .context.Values.tls.autoGenerated (eq (upper .context.Values.tls.type) "PEM")) }}
    - name: KAFKA_TLS_KEYSTORE_PASSWORD
      valueFrom:
        secretKeyRef:
          name: {{ include "kafka.tlsPasswordsSecretName" .context }}
          key: {{ .context.Values.tls.passwordsSecretKeystoreKey | quote }}
    - name: KAFKA_TLS_TRUSTSTORE_PASSWORD
      valueFrom:
        secretKeyRef:
          name: {{ include "kafka.tlsPasswordsSecretName" .context }}
          key: {{ .context.Values.tls.passwordsSecretTruststoreKey | quote }}
    {{- if and (not .context.Values.tls.autoGenerated) (or .context.Values.tls.keyPassword (and .context.Values.tls.passwordsSecret .context.Values.tls.passwordsSecretPemPasswordKey)) }}
    - name: KAFKA_TLS_PEM_KEY_PASSWORD
      valueFrom:
        secretKeyRef:
          name: {{ include "kafka.tlsPasswordsSecretName" .context }}
          key: {{ default "key-password" .context.Values.tls.passwordsSecretPemPasswordKey | quote }}
    {{- end }}
    {{- end }}
    {{- if or .context.Values.zookeeper.enabled .context.Values.externalZookeeper.servers }}
    {{- if .context.Values.sasl.zookeeper.user }}
    - name: KAFKA_ZOOKEEPER_USER
      value: {{ .context.Values.sasl.zookeeper.user | quote }}
    - name: KAFKA_ZOOKEEPER_PASSWORD
      valueFrom:
        secretKeyRef:
          name: {{ include "kafka.saslSecretName" .context }}
          key: zookeeper-password
    {{- end }}
    {{- if .context.Values.tls.zookeeper.enabled }}
    {{- if and .context.Values.tls.zookeeper.passwordsSecretKeystoreKey (or .context.Values.tls.zookeeper.passwordsSecret .context.Values.tls.zookeeper.keystorePassword) }}
    - name: KAFKA_ZOOKEEPER_TLS_KEYSTORE_PASSWORD
      valueFrom:
        secretKeyRef:
          name: {{ include "kafka.zookeeper.tlsPasswordsSecretName" .context }}
          key: {{ .context.Values.tls.zookeeper.passwordsSecretKeystoreKey | quote }}
    {{- end }}
    {{- if and .context.Values.tls.zookeeper.passwordsSecretTruststoreKey (or .context.Values.tls.zookeeper.passwordsSecret .context.Values.tls.zookeeper.truststorePassword) }}
    - name: KAFKA_ZOOKEEPER_TLS_TRUSTSTORE_PASSWORD
      valueFrom:
        secretKeyRef:
          name: {{ include "kafka.zookeeper.tlsPasswordsSecretName" .context }}
          key: {{ .context.Values.tls.zookeeper.passwordsSecretTruststoreKey | quote }}
    {{- end }}
    {{- end }}
    {{- end }}
  volumeMounts:
    - name: data
      mountPath: /bitnami/kafka
    - name: kafka-config
      mountPath: /config
    - name: kafka-configmaps
      mountPath: /configmaps
    - name: kafka-secret-config
      mountPath: /secret-config
    - name: scripts
      mountPath: /scripts
    - name: tmp
      mountPath: /tmp
    {{- if and .context.Values.externalAccess.enabled .context.Values.externalAccess.autoDiscovery.enabled }}
    - name: kafka-autodiscovery-shared
      mountPath: /shared
    {{- end }}
    {{- if or (include "kafka.sslEnabled" .context) .context.Values.tls.zookeeper.enabled }}
    - name: kafka-shared-certs
      mountPath: /certs
    {{- if and (include "kafka.sslEnabled" .context) (or .context.Values.tls.existingSecret .context.Values.tls.autoGenerated) }}
    - name: kafka-certs
      mountPath: /mounted-certs
      readOnly: true
    {{- end }}
    {{- if and .context.Values.tls.zookeeper.enabled .context.Values.tls.zookeeper.existingSecret }}
    - name: kafka-zookeeper-cert
      mountPath: /zookeeper-certs
      readOnly: true
    {{- end }}
    {{- end }}
    - name: kafka-config-connect
      mountPath: /config-connect
    - name: kafka-configmaps-connect
      mountPath: /configmaps-connect
    - name: scripts-connect
      mountPath: /scripts-connect
{{- end -}}
