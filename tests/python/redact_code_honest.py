"""Honest everyday code under credential-named variables (review round 8): 12 names x 20 right-hand sides = 240 lines that must not
be refused, plus a list of other everyday shapes (type annotations, input(), os.getenv(), f-strings, Terraform plan output)."""

NAMES = ["password", "token", "api_key", "secret", "access_token", "client_secret", "auth_token", "self.password",
         "user.password_hash", "hashed_password", "refresh_token", "session_token"]
RHS = ["hashlib.sha256(pw.encode()).hexdigest()", "base64.b64encode(raw.encode()).decode()", "str(uuid.uuid4())",
       "bcrypt.hashpw(pw.encode(), bcrypt.gensalt())", "make_password(form.cleaned_data['password'])",
       "jwt.encode(payload, settings.SECRET_KEY, algorithm='HS256')", "secrets.token_hex(16)", "os.urandom(32).hex()",
       "request.POST.get('password', '')", "data['token'].strip()", "json.loads(body)['access_token']",
       "hmac.new(key, msg, hashlib.sha256).hexdigest()", "generate_token(user.id, expires=timedelta(hours=1))",
       "get_secret(name=f'{env}/db')", "cipher.decrypt(enc).decode('utf-8')", "sha1(salt + pw).hexdigest()",
       "str(int(time.time()))", "client.fetch_token(token_url, code=code)",
       "''.join(random.choices(string.ascii_letters, k=32))", "Fernet(key).encrypt(pw.encode())"]

EXTRAS = [
    'password = input("Password: ")', 'api_key = os.getenv("API_KEY")', 'token: str = ""', "secret = hashlib.sha256(x).hexdigest()",
    "key = cache_key(user, page)", "password_field = forms.CharField(widget=forms.PasswordInput)", "token = str(uuid.uuid4())",
    "api_key = os.environ['API_KEY']", "String token = Jwts.builder().setSubject(user).signWith(key).compact();",
    "const token = await getToken({ audience, scope });", "password = getpass.getpass()", "secret = f'{prefix}-{name}'",
    "token = request.headers.get('Authorization', '').split(' ')[-1]", "self.api_key = config['services']['stripe']['key']",
    "      + password = (sensitive value)", "  ~ token = (known after apply)", '  Error: Invalid value for "password": (sensitive value)',
    "password: '@Microsoft.KeyVault(SecretUri=https://kv.vault.azure.net/secrets/db/)'", 'password: "%env(DATABASE_PASSWORD)%"',
    "password: !env_var DB_PASSWORD", "MasterUserPassword: !Ref DBPassword", "Password: !Sub '${Stack}-db-password'",
    "api_key: !secret ha_api_key", "password: '{{resolve:ssm-secure:/prod/db/password:1}}'", "password:  16 bytes",
    "SENTRY_DSN=https://<key>@o0.ingest.sentry.io/<project>", "password = ***", "token: <redacted>", "secret = [REDACTED]",
    "password: known after apply", "token = <secret>", "password = (sensitive)", "token = jwt.encode(payload, key, algorithm='HS256')",
    "password = PasswordField('Password', validators=[DataRequired()])", "if (password === confirm) { submit(); }",
    "def login(user: str, password: str, api_key: Optional[str] = None):", "password = var.db_password",
    "secretKeyRef:\n  name: db-credentials\n  key: password", "valueFrom:\n  secretKeyRef:\n    name: db\n    key: password",
]


def build():
    lines = ["    %s = %s" % (n, r) for n in NAMES for r in RHS]
    return lines, list(EXTRAS)
