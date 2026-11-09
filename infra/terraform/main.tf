resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

locals {
  unique_prefix             = "${var.prefix}${random_string.suffix.result}"
  docker_install_cloud_init = file("${path.module}/cloud-init/docker-install.yml")
  runner_cloud_init         = file("${path.module}/cloud-init/runner.yml")
}

module "rg" {
  source   = "./modules/rg"
  location = var.location
  name     = "rg-${local.unique_prefix}"
  tags     = var.tags
}

module "network" {
  source              = "./modules/network"
  resource_group_name = module.rg.name
  location            = var.location
  prefix              = local.unique_prefix
  tags                = var.tags
}

module "acr" {
  source              = "./modules/acr"
  resource_group_name = module.rg.name
  location            = var.location
  prefix              = local.unique_prefix
  tags                = var.tags
}

resource "azurerm_user_assigned_identity" "inference" {
  name                = "id-inference-${local.unique_prefix}"
  resource_group_name = module.rg.name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_role_assignment" "acr_pull_inference" {
  scope                = module.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.inference.principal_id
}

resource "azurerm_user_assigned_identity" "train" {
  name                = "id-train-${local.unique_prefix}"
  resource_group_name = module.rg.name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_role_assignment" "acr_pull_train" {
  scope                = module.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.train.principal_id
}

locals {
  mlflow_cloud_init = templatefile("${path.module}/cloud-init/mlflow-vm.yml", {
    acr_login_server = module.acr.login_server
    acr_name         = module.acr.name
    mlflow_image     = "${module.acr.login_server}/mlflow-server:latest"
  })
}

module "mlflow_vm" {
  source                 = "./modules/vm"
  resource_group_name    = module.rg.name
  location               = var.location
  prefix                 = "${local.unique_prefix}-mlflow"
  subnet_id              = module.network.subnet_id
  vm_size                = var.vm_size
  admin_username         = var.admin_username
  ssh_public_key         = var.ssh_public_key
  custom_data            = base64encode(local.mlflow_cloud_init)
  assign_public_ip       = true
  enable_system_identity = true
  tags                   = var.tags
}

resource "azurerm_role_assignment" "acr_pull_mlflow" {
  scope                = module.acr.id
  role_definition_name = "AcrPull"
  principal_id         = module.mlflow_vm.principal_id
}

module "inference_prod" {
  source                     = "./modules/vm"
  resource_group_name        = module.rg.name
  location                   = var.location
  prefix                     = "${local.unique_prefix}-prod"
  subnet_id                  = module.network.subnet_id
  vm_size                    = var.vm_size
  admin_username             = var.admin_username
  ssh_public_key             = var.ssh_public_key
  custom_data                = base64encode(local.docker_install_cloud_init)
  assign_public_ip           = true
  user_assigned_identity_ids = [azurerm_user_assigned_identity.inference.id]
  tags                       = merge(var.tags, { role = "inference-prod" })
}

module "inference_beta" {
  source                     = "./modules/vm"
  resource_group_name        = module.rg.name
  location                   = var.location
  prefix                     = "${local.unique_prefix}-beta"
  subnet_id                  = module.network.subnet_id
  vm_size                    = var.vm_size
  admin_username             = var.admin_username
  ssh_public_key             = var.ssh_public_key
  custom_data                = base64encode(local.docker_install_cloud_init)
  assign_public_ip           = true
  user_assigned_identity_ids = [azurerm_user_assigned_identity.inference.id]
  tags                       = merge(var.tags, { role = "inference-beta" })
}

module "runner_vm" {
  source                 = "./modules/vm"
  resource_group_name    = module.rg.name
  location               = var.location
  prefix                 = "${local.unique_prefix}-runner"
  subnet_id              = module.network.subnet_id
  vm_size                = var.vm_size
  admin_username         = var.admin_username
  ssh_public_key         = var.ssh_public_key
  custom_data            = base64encode(local.runner_cloud_init)
  assign_public_ip       = true
  enable_system_identity = true
  tags                   = merge(var.tags, { role = "gha-runner" })
}

resource "azurerm_role_assignment" "acr_pull_runner" {
  scope                = module.acr.id
  role_definition_name = "AcrPull"
  principal_id         = module.runner_vm.principal_id
}

module "monitoring" {
  source              = "./modules/monitoring"
  resource_group_name = module.rg.name
  location            = var.location
  prefix              = local.unique_prefix
  tags                = var.tags
  health_url          = "http://${module.inference_prod.public_ip}:8000/health"
  predict_url         = "http://${module.inference_prod.public_ip}:8000/predict"
  golden_request_body = file("${path.module}/../../tests/golden/predict_request.json")
  alert_email         = var.alert_email
}
