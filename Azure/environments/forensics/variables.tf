variable "resource_group_name" {
  description = "Name of the resource group (e.g. ForensicsRGAutomation)."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
  default     = "Canada East"
}

variable "vnet_name" {
  description = "Name of the virtual network."
  type        = string
}

variable "vnet_address_space" {
  description = "Address space(s) for the VNet."
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "subnets" {
  description = "List of subnets to create."
  type        = any
}

variable "nsgs" {
  description = "Map of NSG key to NSG config (name, rules)."
  type        = any
}

variable "tags" {
  description = "Tags for all resources."
  type        = map(string)
  default     = {}
}

variable "enable_bastion" {
  description = "Whether to create Azure Bastion (and AzureBastionSubnet)."
  type        = bool
  default     = false
}

variable "bastion_host_name" {
  description = "Name of the Bastion host when enable_bastion is true."
  type        = string
  default     = "forensics-bastion"
}

# No VMs in forensics by default; vnet module accepts vms = {}
variable "vms" {
  description = "Map of VMs to create (empty for forensics environment)."
  type        = any
  default     = null
}

# Suffix appended to storage, container, and Key Vault names (e.g. timestamp for uniqueness)
# Pass at deploy time: -var='name_suffix=20250212120000' or set in tfvars. Use digits only to keep names valid.
variable "name_suffix" {
  description = "Suffix appended to storage account, container, and Key Vault names (e.g. timestamp YYYYMMDDhhmmss). Set via -var or tfvars; e.g. PowerShell: Get-Date -Format 'yyyyMMddHHmmss'."
  type        = string
  default     = ""
}

# Storage account + container + Key Vault (forensics_storage module); final names = base + name_suffix (truncated to Azure limits)
variable "storage_account_name" {
  description = "Base name of the storage account (before suffix). Final name truncated to 24 chars, lowercased."
  type        = string
}

variable "container_name" {
  description = "Base name of the blob container (before suffix). Default snapshots."
  type        = string
  default     = "snapshots"
}

variable "key_vault_name" {
  description = "Base name of the Key Vault (before suffix). Final name truncated to 24 chars. Use e.g. ForensicsKV."
  type        = string
}
