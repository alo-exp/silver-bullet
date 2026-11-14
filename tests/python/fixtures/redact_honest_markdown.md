# Delegation notes

## Secrets in brief and log

| Surface | Behaviour |
|---------|-----------|
| Brief | The scanner refuses a literal credential and names the rule and line. |
| Log | `--redact` replaces credentials with `[REDACTED]`; names are kept. |
| Transcript | Stored in a 0700 directory, redacted before it is archived. |

Pass `SB_AGENT_ALLOW_SECRET_LIKE_BRIEF=1` to override a refusal you have reviewed.

- Never paste `password=<value>` into a brief; reference `$DB_PASSWORD` instead.
- Use `--password-stdin` with `docker login`, fed from a file: `docker login -u ci --password-stdin < ~/.secrets/registry`.
- The token is read from `$GITHUB_TOKEN` or from `gh auth token`.
- Store the API key in your secret manager, for example `vault kv get secret/app/prod`.
- A reference such as `${{ secrets.DEPLOY_TOKEN }}` is not a literal.

> Note: the access token lives in `~/.config/gh/hosts.yml`; do not copy it.

```bash
export DATABASE_URL="postgres://app:${DB_PASSWORD}@db.internal:5432/app"
curl -H "Authorization: Bearer $TOKEN" https://api.example.com/v1/items
mysql -u app -p"$MYSQL_PWD" app < schema.sql
aws configure set aws_secret_access_key "$AWS_SECRET_ACCESS_KEY"
kubectl create secret generic db --from-literal=password="$DB_PASSWORD"
```

```yaml
auth:
  existingSecret: db-credentials
  secretKeyRef:
    name: db
    key: password
token: ${{ secrets.GITHUB_TOKEN }}
password_policy: see the policy page
```

## Configuration names

- `SECRET_KEY_BASE` is read from the environment; `secret_key_ref` points at a Kubernetes secret.
- `token_url: https://auth.corp.test/oauth2/token` and `token_type: bearer` are plain settings.
- `password_field = 'user_password'` names a form field.
- `cache_key = f'user:{user_id}:profile'` and `sort_key: created_at` are not credentials.
- `api_key = settings.STRIPE_API_KEY` and `password = form.cleaned_data.password` are references.
- `private_key_path: ~/.ssh/id_ed25519` is a path.

Prose that mentions words: reset your password from the account page; tokens expire after 24 hours;
the client secret is kept in Vault; rotate the API key quarterly; if all checks pass, merge the PR.

See https://example.com/docs/auth and ssh://git.example.com/org/repo.git for details.
The base commit is abc1234.
