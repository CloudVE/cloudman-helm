#!/bin/bash

set -e

psql -v ON_ERROR_STOP=1 -v KCPASSWORD="'$KEYCLOAK_DB_PASSWORD'" --username postgres <<-EOSQL
    CREATE DATABASE keycloak;
    CREATE USER {{ .Values.keycloak.keycloak.persistence.dbUser }};
    ALTER ROLE {{ .Values.keycloak.keycloak.persistence.dbUser }} WITH PASSWORD :KCPASSWORD;
    GRANT ALL PRIVILEGES ON DATABASE keycloak TO {{ .Values.keycloak.keycloak.persistence.dbUser }};
    ALTER DATABASE keycloak OWNER TO {{ .Values.keycloak.keycloak.persistence.dbUser }};
EOSQL
