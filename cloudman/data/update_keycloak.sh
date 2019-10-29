#! /bin/sh

# abort if any command fails
set -e
username="admin"
password="{{ .Values.keycloak.keycloak.password }}"

# get auth token
token=$(curl -k -s -d "client_id=admin-cli" -d "username=admin" -d "password=$password" -d "grant_type=password" \
       "https://{{ .Values.global.domain }}/auth/realms/master/protocol/openid-connect/token" | jq -r '.access_token')

# get admin user id
user_id=$(curl -k -s -H "Content-Type: application/json" -H "Authorization: bearer $token" https://{{ .Values.global.domain }}/auth/admin/realms/master/users/?username=admin | \
          jq -r '.[] | select(.username=="admin") | .id')

# update admin user info
updated_user=$(curl -k -s -H "Content-Type: application/json" -H "Authorization: bearer $token" https://{{ .Values.global.domain }}/auth/admin/realms/master/users/$user_id | \
          jq -r '.firstName="{{ .Values.admin_firstname }}" | .lastName="{{ .Values.admin_lastname }}" | .email="{{ .Values.admin_email }}"')

# Save new info
curl -k -X PUT -H "Content-Type: application/json" -H "Authorization: bearer $token" https://{{ .Values.global.domain }}/auth/admin/realms/master/users/$user_id -d "$updated_user"

# Add Brute Force Detection to Master realm
curl -k -X PUT -H "Content-Type: application/json" -H "Authorization: bearer $token" https://{{ .Values.global.domain }}/auth/admin/realms/master -d '{"bruteForceProtected": true, "failureFactor": 5, "maxFailureWaitSeconds": 1800, "minimumQuickLoginWaitSeconds": 300}'

# Add CloudMan client
curl -k -X POST -H "Content-Type: application/json" -H "Authorization: bearer $token" https://{{ .Values.global.domain }}/auth/admin/realms/master/clients -d '{"clientId":"cloudman","rootUrl":"https://{{ .Values.global.domain }}/cloudman","adminUrl":"https://{{ .Values.global.domain }}/cloudman","surrogateAuthRequired":false,"enabled":true,"redirectUris":["https://{{ .Values.global.domain }}/*"],"webOrigins":["https://{{ .Values.global.domain }}/"],"notBefore":0,"bearerOnly":false,"consentRequired":false,"standardFlowEnabled":true,"implicitFlowEnabled":false,"directAccessGrantsEnabled":true,"serviceAccountsEnabled":false,"publicClient":false,"frontchannelLogout":false,"protocol":"openid-connect","attributes":{"saml.assertion.signature":"false","saml.force.post.binding":"false","saml.multivalued.roles":"false","saml.encrypt":"false","saml.server.signature":"false","saml.server.signature.keyinfo.ext":"false","exclude.session.state.from.auth.response":"false","saml_force_name_id_format":"false","saml.client.signature":"false","tls.client.certificate.bound.access.tokens":"false","saml.authnstatement":"false","display.on.consent.screen":"false","saml.onetimeuse.condition":"false"},"authenticationFlowBindingOverrides":{},"fullScopeAllowed":true,"nodeReRegistrationTimeout":-1,"defaultClientScopes":["web-origins","role_list","profile","roles","email"],"optionalClientScopes":["address","phone","offline_access","microprofile-jwt"],"access":{"view":true,"configure":true,"manage":true},"authorizationServicesEnabled":""}'

{{ range $key, $chart := .Values.helmsman_config.charts -}}
{{ if $chart.oidc_client -}}
{{ $client_id := tpl $chart.oidc_client.client_id $ -}}
{{ $client_secret := tpl $chart.oidc_client.client_secret $ }}
{{ $redirect_uris := "" }}
{{ range $index, $uri := $chart.oidc_client.redirect_uris }}
{{ if $index }}
{{ $redirect_uris = print $redirect_uris ", " }}
{{ end }}
{{ $redirect_uris = print $redirect_uris (tpl $uri $ | quote) }}
{{ end }}

curl -k -X POST -H "Content-Type: application/json" -H "Authorization: bearer $token" https://{{ $.Values.global.domain }}/auth/admin/realms/master/clients -d '{"clientId":{{ $client_id | quote }}, "clientAuthenticatorType" : "client-secret", "secret": {{ $client_secret | quote }},"publicClient":false,"enabled":true,"protocol":"openid-connect"},"redirectUris":[{{ $redirect_uris }}]'
{{- end -}}
{{- end -}}

