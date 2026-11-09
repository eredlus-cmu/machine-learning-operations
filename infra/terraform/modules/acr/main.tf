variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "prefix" { type = string }
variable "tags" { type = map(string) }

resource "azurerm_container_registry" "acr" {
  name                = substr(replace("acr${var.prefix}", "-", ""), 0, 50)
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Basic"
  admin_enabled       = false
  tags                = var.tags
}

output "login_server" {
  value = azurerm_container_registry.acr.login_server
}

output "name" {
  value = azurerm_container_registry.acr.name
}

output "id" {
  value = azurerm_container_registry.acr.id
}
