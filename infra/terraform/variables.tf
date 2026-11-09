variable "location" {
  type    = string
  default = "westus2"
}

variable "prefix" {
  type    = string
  default = "mlops"
}

variable "vm_size" {
  type        = string
  default     = "Standard_D2s_v7"
  description = "Persistent VMs. Bsv2/B2s are often quota-0 or capacity-restricted on teaching subs."
}

variable "admin_username" {
  type    = string
  default = "azureuser"
}

variable "ssh_public_key" {
  type = string
}

variable "alert_email" {
  type        = string
  default     = ""
  description = "Task 3: email for a quality-alert action group. Leave empty until then."
}

variable "tags" {
  type = map(string)
  default = {
    project = "mlops"
  }
}
