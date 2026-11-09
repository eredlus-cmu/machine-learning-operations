variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "prefix" { type = string }
variable "subnet_id" { type = string }
variable "vm_size" { type = string }
variable "admin_username" { type = string }
variable "ssh_public_key" { type = string }
variable "custom_data" { type = string }
variable "assign_public_ip" { type = bool }
variable "user_assigned_identity_ids" {
  type    = list(string)
  default = []
}
variable "enable_system_identity" {
  type    = bool
  default = false
}
variable "tags" { type = map(string) }

resource "azurerm_public_ip" "pip" {
  count               = var.assign_public_ip ? 1 : 0
  name                = "pip-${var.prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_network_interface" "nic" {
  name                = "nic-${var.prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = var.assign_public_ip ? azurerm_public_ip.pip[0].id : null
  }
}

resource "azurerm_linux_virtual_machine" "vm" {
  name                  = "vm-${var.prefix}"
  resource_group_name   = var.resource_group_name
  location              = var.location
  size                  = var.vm_size
  admin_username        = var.admin_username
  tags                  = var.tags
  network_interface_ids = [azurerm_network_interface.nic.id]
  custom_data           = var.custom_data

  dynamic "identity" {
    for_each = length(var.user_assigned_identity_ids) > 0 ? [1] : (var.enable_system_identity ? [1] : [])
    content {
      type         = length(var.user_assigned_identity_ids) > 0 ? "UserAssigned" : "SystemAssigned"
      identity_ids = length(var.user_assigned_identity_ids) > 0 ? var.user_assigned_identity_ids : null
    }
  }

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}

output "public_ip" {
  value = var.assign_public_ip ? azurerm_public_ip.pip[0].ip_address : ""
}

output "private_ip" {
  value = azurerm_network_interface.nic.private_ip_address
}

output "vm_name" {
  value = azurerm_linux_virtual_machine.vm.name
}

output "principal_id" {
  value = try(azurerm_linux_virtual_machine.vm.identity[0].principal_id, "")
}
