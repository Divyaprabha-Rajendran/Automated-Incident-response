variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "East US"
}

variable "vnet_name" { type = string }
variable "vnet_address_space" {
  type    = list(string)
  default = ["10.0.0.0/16"]
}

variable "subnets" { type = any }
variable "nsgs" { type = any }
variable "tags" {
  type    = map(string)
  default = {}
}

variable "enable_bastion" {
  type    = bool
  default = false
}

variable "bastion_host_name" {
  type    = string
  default = "bastion-host"
}

variable "vms" {
  type    = any
  default = null
}

# Windows VM admin password. Set when any VM has os_type = "windows" and admin_password = null in vms.
variable "windows_vm_admin_password" {
  description = "Admin password for Windows VMs. Required when you have Windows VMs with admin_password = null. Pass via -var=\"windows_vm_admin_password=YourPassword\" or TF_VAR_windows_vm_admin_password."
  type        = string
  default     = null
  sensitive   = true
}

# Automation Account (IncidentResponseAutomation)
variable "automation_account_name" {
  description = "Name of the Azure Automation Account (e.g. IncidentResponseAutomation)."
  type        = string
  default     = "IncidentResponseAutomation"
}

# Forensics destination for IncidentResponse runbook (stored as Automation variables)
variable "forensics_destination" {
  description = "Destination subscription/resource group/storage/Key Vault for the IncidentResponse runbook. Passed into the automation module as Automation Account variables."
  type = object({
    subscription_id       = string
    resource_group        = string
    storage_account_name  = string
    container_name        = optional(string, "snapshots")
    key_vault_name        = string
  })
  default = null
}

# Optional: create storage account + container + Key Vault in this subscription (e.g. for forensics snapshots)
variable "forensics_storage" {
  description = "If set, create a storage account with a snapshots container and a Key Vault in the same resource group (module forensics_storage). Use for forensics destination in this subscription."
  type = object({
    storage_account_name = string
    container_name       = optional(string, "snapshots")
    key_vault_name       = string
  })
  default = null
}
