#! /bin/sh

# get auth token
token=$(curl -s -d "client_id=admin-cli" -d "username=admin" -d "password=gvl_letmein" -d "grant_type=password" \
       "http://localhost:8080/auth/realms/master/protocol/openid-connect/token" | jq -r '.access_token')

# get admin user id
user_id=$(curl -s -H "Content-Type: application/json" -H "Authorization: bearer $token" http://localhost:8080/auth/admin/realms/master/users/?username=admin | \
          jq -r '.[] | select(.username=="admin") | .id')

# update admin user info
updated_user=$(curl -s -H "Content-Type: application/json" -H "Authorization: bearer $token" http://localhost:8080/auth/admin/realms/master/users/$user_id | \
          jq -r '.firstName="{{ .Values.admin_firstname }}" | .lastName="{{ .Values.admin_lastname }}" | .email="{{ .Values.admin_email }}"')

# Save new info
curl -v -X PUT -H "Content-Type: application/json" -H "Authorization: bearer $token" http://localhost:8080/auth/admin/realms/master/users/$user_id -d "$updated_user"