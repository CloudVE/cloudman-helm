#! /bin/sh

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