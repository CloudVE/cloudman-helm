#!/bin/sh

# abort if any command fails
set -e
username="admin"

# get auth token
token=$(curl -k -s -d "client_id=admin-cli" -d "username=$username" -d "password=$KEYCLOAK_HTTP_PASSWORD" -d "grant_type=password" \
       "{{ include "cloudman.root_url" . }}/auth/realms/master/protocol/openid-connect/token" | jq -r '.access_token')

# Get current brute force protection status
realm_protection=$(curl -k -s -H "Content-Type: application/json" -H "Authorization: bearer $token" {{ include "cloudman.root_url" . }}/auth/admin/realms/master | \
                   jq -r '.bruteForceProtected')

if [ "$realm_protection" = "false" ]
then

      # Add Brute Force Detection to 'master' realm
      curl -k -X PUT -H "Content-Type: application/json" -H "Authorization: bearer $token" {{ include "cloudman.root_url" . }}/auth/admin/realms/master -d '{"bruteForceProtected": true, "failureFactor": 5, "maxFailureWaitSeconds": 1800, "minimumQuickLoginWaitSeconds": 300}'

else
      echo "Brute Force Protection is already on."
fi

# Add User Registration to 'master' realm
curl -k -X PUT -H "Content-Type: application/json" -H "Authorization: bearer $token" {{ include "cloudman.root_url" . }}/auth/admin/realms/master -d '{"registrationAllowed": {{.Values.keycloak.userRegistration.enabled}}, "registrationEmailAsUsername": true, "loginWithEmailAllowed": true, "duplicateEmailsAllowed": false}'

# Get superuser role
super_role=$(curl -X GET -k -s -H "Content-Type: application/json" -H "Authorization: bearer $token" {{ include "cloudman.root_url" . }}/auth/admin/realms/master/roles | \
                   jq -r '.[] | select(.name=="superuser") | .id')

if [ -z "$super_role" ]
then
       # Add superuser role
       curl -k -s -H "Content-Type: application/json" -H "Authorization: bearer $token" {{ include "cloudman.root_url" . }}/auth/admin/realms/master/roles -d '{"name":"superuser"}'
else
      echo "The superuser role already exists."
fi


# Get superuser role ID
role_id=$(curl -k -s -H "Content-Type: application/json" -H "Authorization: bearer $token" {{ include "cloudman.root_url" . }}/auth/admin/realms/master/roles | jq -r '.[] | select(.name=="superuser") | .id')

# get admin user id
user_id=$(curl -k -s -H "Content-Type: application/json" -H "Authorization: bearer $token" {{ include "cloudman.root_url" . }}/auth/admin/realms/master/users/?username=admin | \
          jq -r '.[] | select(.username=="admin") | .id')

# Add superuser role to admin user
curl -k -s -H "Content-Type: application/json" -H "Authorization: bearer $token" {{ include "cloudman.root_url" . }}/auth/admin/realms/master/users/$user_id/role-mappings/realm -d "[{\"id\":\"$role_id\",\"name\":\"superuser\",\"composite\":false,\"clientRole\":false,\"containerId\":\"master\"}]"

# get admin user email
user_email=$(curl -k -s -H "Content-Type: application/json" -H "Authorization: bearer $token" {{ include "cloudman.root_url" . }}/auth/admin/realms/master/users/$user_id | \
jq -r '.email')

if [ "$user_email" = "null" ]
then
      # update admin user info
      updated_user=$(curl -k -s -H "Content-Type: application/json" -H "Authorization: bearer $token" {{ include "cloudman.root_url" . }}/auth/admin/realms/master/users/$user_id | \
                jq -r '.firstName="{{ .Values.admin_firstname }}" | .lastName="{{ .Values.admin_lastname }}" | .email="{{ .Values.admin_email }}"')

      # Save new info
      curl -k -X PUT -H "Content-Type: application/json" -H "Authorization: bearer $token" {{ include "cloudman.root_url" . }}/auth/admin/realms/master/users/$user_id -d "$updated_user"
else
      echo "The admin user already had an email address."
fi


# Get superuser role
existing_flow=$(curl -X GET -k -s -H "Content-Type: application/json" -H "Authorization: bearer $token" {{ include "cloudman.root_url" . }}/auth/admin/realms/master/authentication/flows | jq -r '.[] | select(.alias=="BrowserFlowWithRoleRestrictions") | .id')

if [ -z "$existing_flow" ]
then
       
       # Add browser with client restriction JS authenticator script
       curl -k -s -H "Content-Type: application/json" -H "Authorization: bearer $token" {{ include "cloudman.root_url" . }}/auth/admin/realms/master/authentication/flows/browser/copy -d "{\"newName\":\"BrowserFlowWithRoleRestrictions\"}"

       # Add JS script
       curl -k -s -H "Content-Type: application/json" -H "Authorization: bearer $token" {{ include "cloudman.root_url" . }}/auth/admin/realms/master/authentication/flows/BrowserFlowWithRoleRestrictions/executions/execution -d "{\"provider\": \"auth-script-based\"}"

       # Get current flows and make Script required
       flows=$(curl -X GET -k -s -H "Content-Type: application/json" -H "Authorization: bearer $token" {{ include "cloudman.root_url" . }}/auth/admin/realms/master/authentication/flows/BrowserFlowWithRoleRestrictions/executions | jq -r '.[] | select(.displayName=="Script") | .requirement = "REQUIRED"')

       scriptid=$(curl -X GET -k -s -H "Content-Type: application/json" -H "Authorization: bearer $token" {{ include "cloudman.root_url" . }}/auth/admin/realms/master/authentication/flows/BrowserFlowWithRoleRestrictions/executions | jq -r '.[] | select(.displayName=="Script") | .id')

       # PUT the new flows with Script required
       curl -X PUT -k -s -H "Content-Type: application/json" -H "Authorization: bearer $token" {{ include "cloudman.root_url" . }}/auth/admin/realms/master/authentication/flows/BrowserFlowWithRoleRestrictions/executions -d "$flows"

       authscript=$(cat <<EOF
 // modfied version of https://stackoverflow.com/a/57271777
 AuthenticationFlowError = Java.type("org.keycloak.authentication.AuthenticationFlowError");

 function authenticate(context) {
    var username = user ? user.username : "anonymous";

    var client = session.getContext().getClient();
    var MANDATORY_ROLE = client.getClientId();
    LOG.warn("Checking access to authentication for client '" + client.getClientId() + "' through mandatory role '" + MANDATORY_ROLE + "' for user '" + username + "'");
    
    // It requires the role to be assigned to the client as well
    var mandatoryRole = client.getRole(MANDATORY_ROLE);

    if (user.hasRole(mandatoryRole)) {
        LOG.info("Successful authentication for user '" + username + "' with mandatory role '" + MANDATORY_ROLE + "' for client '" + client.getClientId() + "'");
        return context.success();
    }

    LOG.info("Denied authentication for user '" + username + "' without mandatory role '" + MANDATORY_ROLE + "' for client '" + client.getClientId() + "'");
    return denyAccess(context, mandatoryRole);
 }

 // TODO: fix the returning page
 function denyAccess(context, mandatoryRole) {
    var formBuilder = context.form();
    var client = session.getContext().getClient();
    var description = !mandatoryRole.getAttribute('deniedMessage').isEmpty() ? mandatoryRole.getAttribute('deniedMessage') : [''];
    var form = formBuilder
        .setAttribute('clientUrl', client.getRootUrl())
        .setAttribute('clientName', client.getName())
        .setAttribute('description', description[0])
        .createForm('denied-auth.ftl');
    return context.failure(AuthenticationFlowError.INVALID_USER, form);
 }
EOF
       )

       authconfig=$(cat <<EOF
{
   "id":"$scriptid",
   "alias":"clientRoles",
   "config":{
      "scriptName":"clientRoles",
      "scriptCode":"placeholder"
   }
}
EOF
       )

       authconfig=$(echo $authconfig | jq --arg authscript "$authscript" '.config.scriptCode = $authscript')

       # Change name and add code to the created Script execution step
       curl -k -s -H "Content-Type: application/json" -H "Authorization: bearer $token" "{{ include "cloudman.root_url" . }}/auth/admin/realms/master/authentication/executions/$scriptid/config" -d "$authconfig"

else
      echo "The 'BrowserFlowWithRoleRestrictions' flow already exists."
fi


flowid=$(curl -X GET -k -s -H "Content-Type: application/json" -H "Authorization: bearer $token" {{ include "cloudman.root_url" . }}/auth/admin/realms/master/authentication/flows | jq -r '.[] | select(.alias=="BrowserFlowWithRoleRestrictions") | .id')

cloudman_client=$(curl -k -s -H "Content-Type: application/json" -H "Authorization: bearer $token" {{ include "cloudman.root_url" . }}/auth/admin/realms/master/clients | \
jq -r '.[] | select(.clientId=="cloudman")')

if [ -z "$cloudman_client" ]
then
      cloudman_client=$(cat <<EOF
{
    "clientId": "$OIDC_CLIENT_ID",
    "rootUrl": "{{ include "cloudman.root_url" . }}/cloudman",
    "adminUrl": "{{ include "cloudman.root_url" . }}/cloudman",
    "enabled": true,
    "clientAuthenticatorType": "client-secret",
    "redirectUris": [
        "{{ include "cloudman.root_url" . }}/*"
    ],
    "webOrigins": [
        "{{ include "cloudman.root_url" . }}"
    ],
    "publicClient": true,
    "protocol": "openid-connect",
    "fullScopeAllowed": true,
    "protocolMappers": [
        {
            "name": "cloudman-audience",
            "protocol": "openid-connect",
            "protocolMapper": "oidc-audience-mapper",
            "consentRequired": false,
            "config": {
                "included.client.audience": "$OIDC_CLIENT_ID",
                "id.token.claim": "false",
                "access.token.claim": "true"
            }
        },
        {
            "name": "given name",
            "protocol": "openid-connect",
            "protocolMapper": "oidc-usermodel-property-mapper",
            "consentRequired": false,
            "config": {
                "userinfo.token.claim": "true",
                "user.attribute": "firstName",
                "id.token.claim": "true",
                "access.token.claim": "true",
                "claim.name": "given_name",
                "jsonType.label": "String"
            }
        },
        {
            "name": "full name",
            "protocol": "openid-connect",
            "protocolMapper": "oidc-full-name-mapper",
            "consentRequired": false,
            "config": {
                "id.token.claim": "true",
                "access.token.claim": "true",
                "userinfo.token.claim": "true"
            }
        },
        {
            "name": "role list",
            "protocol": "saml",
            "protocolMapper": "saml-role-list-mapper",
            "consentRequired": false,
            "config": {
                "single": "false",
                "attribute.nameformat": "Basic",
                "attribute.name": "Role"
            }
        },
        {
            "name": "username",
            "protocol": "openid-connect",
            "protocolMapper": "oidc-usermodel-property-mapper",
            "consentRequired": false,
            "config": {
                "userinfo.token.claim": "true",
                "user.attribute": "username",
                "id.token.claim": "true",
                "access.token.claim": "true",
                "claim.name": "preferred_username",
                "jsonType.label": "String"
            }
        },
        {
            "name": "family name",
            "protocol": "openid-connect",
            "protocolMapper": "oidc-usermodel-property-mapper",
            "consentRequired": false,
            "config": {
                "userinfo.token.claim": "true",
                "user.attribute": "lastName",
                "id.token.claim": "true",
                "access.token.claim": "true",
                "claim.name": "family_name",
                "jsonType.label": "String"
            }
        },
        {
            "name": "email",
            "protocol": "openid-connect",
            "protocolMapper": "oidc-usermodel-property-mapper",
            "consentRequired": false,
            "config": {
                "userinfo.token.claim": "true",
                "user.attribute": "email",
                "id.token.claim": "true",
                "access.token.claim": "true",
                "claim.name": "email",
                "jsonType.label": "String"
            }
        },
        {
          "name": "role",
          "protocolMapper": "oidc-usermodel-realm-role-mapper",
          "protocol": "openid-connect",
          "config": {
            "multivalued": "true",
            "id.token.claim": "true",
            "access.token.claim": "true",
            "userinfo.token.claim": "true"
          }
        }
    ]
}
EOF
      )

      # Add CloudMan client
      curl -k -X POST -H "Content-Type: application/json" -H "Authorization: bearer $token" {{ include "cloudman.root_url" . }}/auth/admin/realms/master/clients -d "$cloudman_client"
else
      echo "The cloudman client already exists."
fi

{{- range $key, $client := .Values.oidc_clients -}}
{{- $client_id := tpl $client.client_id $ -}}
{{- $redirect_uris := "" }}
{{- range $index, $uri := $client.redirect_uris }}
{{- if $index }}
{{- $redirect_uris = print $redirect_uris ", " }}
{{- end }}
{{- $redirect_uris = print $redirect_uris (tpl $uri $ | quote) }}
{{- end }}

{{ $key }}_client=$(curl -k -s -H "Content-Type: application/json" -H "Authorization: bearer $token" {{ include "cloudman.root_url" $ }}/auth/admin/realms/master/clients | \
jq -r '.[] | select(.clientId=="$client_id")')

if [ -z "${{ $key }}_client" ]
then
      {{ $key }}_client=$(cat <<EOF
{
    "clientId": {{ $client_id | quote }},
    "enabled": true,
    "clientAuthenticatorType": "client-secret",
    "authenticationFlowBindingOverrides":
    {
      "browser": "$flowid"
    },
    "redirectUris": [{{ $redirect_uris }}],
    {{- if $client.public_client }}
    "publicClient": true,
    {{- else }}
    {{- $client_secret := tpl (required "The client secret is required if the client is not public" $client.client_secret) $ }}
    "publicClient": false,
    "secret": {{ $client_secret | quote }},
    {{- end }}
    "protocol": "openid-connect",
    "fullScopeAllowed": true,
    "protocolMappers": [
        {
            "name": "{{ $client_id }}-audience",
            "protocol": "openid-connect",
            "protocolMapper": "oidc-audience-mapper",
            "consentRequired": false,
            "config": {
                "included.client.audience": {{ $client_id | quote }},
                "id.token.claim": "false",
                "access.token.claim": "true"
            }
        }
    ]
}
EOF
      )

      # add new client
      curl -k -X POST -H "Content-Type: application/json" -H "Authorization: bearer $token" {{ include "cloudman.root_url" $ }}/auth/admin/realms/master/clients -d "${{ $key }}_client"

else
      echo "The {{ $client_id }} client already exists."
fi

{{- end -}}
