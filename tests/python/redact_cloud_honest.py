"""Honest cloud-SDK and CLI lines (review round 10): identifiers, ARNs, resource names, digests, SHAs, URIs and paths inside calls
are not secrets. Values are generated at run time."""

import hashlib
import random
import uuid


def build():
    r = random.Random(1010)
    U = lambda: str(uuid.UUID(int=r.getrandbits(128)))
    H = lambda n: hashlib.sha256(str(r.random()).encode()).hexdigest()[:n]
    acct = "".join(r.choice("0123456789") for _ in range(12))
    key = "%s-%s-%s" % (H(8), H(4), H(12))
    digest = "sha256:" + H(64)
    sha = H(40)
    return [
        'cred = ClientSecretCredential(tenant_id="%s", client_id="%s")' % (U(), U()),
        'client = SecretClient(vault_url="https://kv-prod.vault.azure.net/", credential=cred)',
        'sts.assume_role(RoleArn="arn:aws:iam::%s:role/Deploy", RoleSessionName="ci")' % acct,
        'kms.decrypt(KeyId="arn:aws:kms:eu-west-1:%s:key/%s", CiphertextBlob=blob)' % (acct, key),
        "s3.get_object(Bucket='my-bucket', Key='path/to/obj')",
        "s3 = boto3.client('s3', region_name='eu-west-1')",
        "lam.invoke(FunctionName='arn:aws:lambda:eu-west-1:%s:function:build-index')" % acct,
        "ecr.describe_images(repositoryName='app', imageIds=[{'imageDigest': '%s'}])" % digest,
        "token = client.access_secret_version(name='projects/123456/secrets/db-pass/versions/latest')",
        "secret = sm.get_secret_value(SecretId='arn:aws:secretsmanager:eu-west-1:%s:secret:prod/db-AbCdEf')" % acct,
        'subscription = SubscriptionClient(credential, subscription_id="%s")' % U(),
        'az account set --subscription "%s"' % U(),
        'docker.pull(image="repo/app@%s")' % digest,
        'checkout(ref="%s")' % sha,
        'repo.git.checkout("%s")' % sha,
        "gsutil cp gs://prod-bucket/exports/2024/data.csv ./data.csv",
        "s3.upload_file('report.pdf', 'my-bucket', 'reports/2024/report.pdf')",
        "requests.get('https://api.example.com/v1/items?page=2')",
        "session.get(url='https://registry.corp.net/v2/_catalog')",
        "open('/etc/app/secrets/db_password', 'r')",
        "load_dotenv(dotenv_path='/home/ci/.config/app/.env')",
        "client = storage.Client(project='my-project-123')",
        "bucket = client.get_bucket('prod-assets-bucket')",
        "sm.create_secret(Name='prod/db/password', Description='database password')",
        "ssm.get_parameter(Name='/prod/db/password', WithDecryption=True)",
        'terraform import aws_instance.web i-%s' % H(17),
        "ec2.describe_instances(InstanceIds=['i-%s'])" % H(17),
        "credential = DefaultAzureCredential(managed_identity_client_id='%s')" % U(),
        "app = msal.ConfidentialClientApplication(client_id='%s', authority='https://login.microsoftonline.com/%s')" % (U(), U()),
        "api = OpenAI(organization='org-%s')" % H(24),
        "client.put_object(Bucket=bucket, Key=f'uploads/{user_id}/{name}')",
        "sns.publish(TopicArn='arn:aws:sns:eu-west-1:%s:alerts', Message=msg)" % acct,
        "dynamodb.Table('users-prod').get_item(Key={'id': user_id})",
        "logging.getLogger('azure.identity').setLevel(logging.DEBUG)",
        "cache_key = hashlib.sha256(f'{user}:{path}'.encode()).hexdigest()",
        "etag = '%s'" % H(32),
        "image: ghcr.io/corp/app@%s" % digest,
        "gcloud secrets versions access latest --secret=db-password --project=my-project",
        "aws secretsmanager get-secret-value --secret-id prod/db/password --region eu-west-1",
        "az keyvault secret show --vault-name kv-prod --name db-password",
        "kubectl get secret db-credentials -n prod -o yaml",
        "resource_id = '/subscriptions/%s/resourceGroups/rg-prod/providers/Microsoft.KeyVault/vaults/kv-prod'" % U(),
        "arn = 'arn:aws:iam::%s:policy/service-role/AmazonEC2RoleforSSM'" % acct,
        "KeyId: arn:aws:kms:eu-west-1:%s:alias/prod-secrets" % acct,
        "token_endpoint = 'https://login.microsoftonline.com/%s/oauth2/v2.0/token'" % U(),
        "secret_name = 'projects/%s/secrets/api-key'" % acct,
        "password_policy = {'MinimumLength': 14, 'RequireSymbols': True}",
        "key_vault_id = '/subscriptions/%s/resourceGroups/rg/providers/Microsoft.KeyVault/vaults/kv'" % U(),
    ]
