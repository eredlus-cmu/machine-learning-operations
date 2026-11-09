output "resource_group_name" { value = module.rg.name }
output "location" { value = var.location }
output "mlflow_private_ip" { value = module.mlflow_vm.private_ip }
output "mlflow_public_ip" { value = module.mlflow_vm.public_ip }
output "mlflow_uri" { value = "http://${module.mlflow_vm.private_ip}:5000" }
output "mlflow_vm_name" { value = module.mlflow_vm.vm_name }
output "prod_vm_ip" { value = module.inference_prod.public_ip }
output "prod_vm_name" { value = module.inference_prod.vm_name }
output "beta_vm_ip" { value = module.inference_beta.public_ip }
output "beta_vm_name" { value = module.inference_beta.vm_name }
output "runner_vm_name" { value = module.runner_vm.vm_name }
output "runner_vm_ip" { value = module.runner_vm.public_ip }
output "acr_login_server" { value = module.acr.login_server }
output "acr_name" { value = module.acr.name }
output "acr_id" { value = module.acr.id }
output "subnet_id" { value = module.network.subnet_id }
output "unique_prefix" { value = local.unique_prefix }
output "train_uai_id" { value = azurerm_user_assigned_identity.train.id }
output "appinsights_name" { value = module.monitoring.appinsights_name }
output "appinsights_connection_string" {
  value     = module.monitoring.appinsights_connection_string
  sensitive = true
}
