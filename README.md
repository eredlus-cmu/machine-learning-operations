# MLOps starter

Vendor-neutral MLOps project: self-hosted MLflow, FastAPI on Azure VMs (beta +
prod), GitHub Actions, Terraform. **ML training code is given.** You build
continuous training on ephemeral compute, registry-alias promotion, and an
alert that fires when a bad model is served.

Environments are MLflow aliases (`beta`, `prod`), not git branches.

## What is already given

- Platform Terraform: resource group, VNet, ACR, MLflow VM, beta + prod VMs,
  VNet GitHub runner VM, identities, `/health` App Insights ping (liveness only)
- `src/training/`, `tests/`, `config/`, `docker/Dockerfile.train`,
  `scripts/train_entrypoint.sh`, `scripts/promote_alias.py`
- `docker/Dockerfile.mlflow` and cloud-init that starts MLflow
- PR `ci.yml`

## What you fill in (TODOs)

| Task | Files |
| ---- | ----- |
| 1 Build | `.github/workflows/train.yml`, `scripts/run_training_vm.sh` |
| 2 Ship | `src/inference/app.py` (load `models:/name@alias`), `scripts/deploy_inference.sh`, `promote-beta.yml`, `promote-prod.yml` |
| 3 Observe | `infra/terraform/modules/monitoring` — not `/health`; must fire when prod is up and `/predict` is wrong |

Container name on the inference VMs must be `inference` (port 8000). The
submitter looks for that name.

## 1. Provision

```bash
cd infra/terraform
terraform init
terraform apply -var="ssh_public_key=$(cat ~/.ssh/id_rsa.pub)"
```

Persistent VMs default to `Standard_D2s_v3` (`B2ls_v2` / `B2s` are often
quota 0 or capacity-restricted). Teaching subscriptions are often ~10
regional vCPUs (4 persistent VMs = 8 vCPUs; ephemeral training needs 2 more).

Build and push the MLflow image, then register the runner once:

```bash
acr=$(terraform -chdir=infra/terraform output -raw acr_login_server)
az acr login -n $(terraform -chdir=infra/terraform output -raw acr_name)
docker build -f docker/Dockerfile.mlflow -t $acr/mlflow-server:latest .
docker push $acr/mlflow-server:latest

export GITHUB_REPO=<owner/this-repo>
export RESOURCE_GROUP=$(terraform -chdir=infra/terraform output -raw resource_group_name)
export RUNNER_VM_NAME=$(terraform -chdir=infra/terraform output -raw runner_vm_name)
bash scripts/register_runner.sh
bash scripts/fill_meta.sh   # writes meta.json (gitignored)
```

## 2. GitHub Actions OIDC

Create a user-assigned identity in the project resource group, grant it Owner
on that group, and add a federated credential for
`repo:<owner/repo>:ref:refs/heads/main`. If `azure/login` fails with
AADSTS700213, copy the **subject claim** from the job log (GitHub may send
`repo:<owner>@<id>/<repo>@<id>:ref:refs/heads/main`) and add a second
federated credential with that exact string.

**Secrets:** `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`,
`RESOURCE_GROUP`, `LOCATION`, `SUBNET_ID`, `MLFLOW_PRIVATE_IP`, `SSH_PUBLIC_KEY`.

**Variables** (not secrets — job outputs get masked if stored as secrets):
`ACR_NAME`, `ACR_LOGIN_SERVER`, `PROD_VM_IP`, `PROD_VM_NAME`, `BETA_VM_IP`,
`BETA_VM_NAME`, `TRAIN_UAI_ID`.

## 3. Pipelines

Complete the TODOs so that:

1. `train.yml` (workflow_dispatch) trains on an ephemeral VM and registers a
   new model version. VM count in the project RG must rise during the run and
   return to the pre-run count after.
2. `promote-beta.yml` / `promote-prod.yml` set the registry alias and redeploy
   inference. Prod is manual. `/version` must report `model_alias` and
   `model_version`.
3. An alert fires when a known-bad model is served on prod while `/health`
   stays 200.

```bash
gh workflow run train.yml
gh workflow run promote-prod.yml -f model_version=N
```

## Teardown

```bash
cd infra/terraform && terraform destroy -var="ssh_public_key=$(cat ~/.ssh/id_rsa.pub)"
az disk list -g <rg> --query "[?contains(name,'train-eph')].id" -o tsv | xargs -r -I{} az disk delete --ids {} --yes
```
