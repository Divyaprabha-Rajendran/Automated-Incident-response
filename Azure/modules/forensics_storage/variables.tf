# ------------------------------------------------------------------------------
# Forensics storage module variables
# ------------------------------------------------------------------------------

variable "resource_group_name" {
  description = "Name of the resource group where the storage account and Key Vault will be created."
  type        = string
}

variable "location" {
  description = "Azure region for the resources."
  type        = string
}

variable "storage_account_name" {
  description = "Name of the storage account (lowercase alphanumeric, 3–24 chars, globally unique)."
  type        = string
}

variable "container_name" {
  description = "Name of the blob container for snapshots (e.g. snapshots)."
  type        = string
  default     = "snapshots"
}

variable "container_access_type" {
  description = "Access type for the container: private, blob, or container."
  type        = string
  default     = "private"
}

variable "account_tier" {
  description = "Storage account tier: Standard or Premium."
  type        = string
  default     = "Standard"
}

variable "account_replication_type" {
  description = "Replication type: LRS, GRS, RAGRS, ZRS, GZRS, or RAGZRS."
  type        = string
  default     = "LRS"
}

variable "account_kind" {
  description = "Storage account kind: Storage, StorageV2, BlobStorage."
  type        = string
  default     = "StorageV2"
}

variable "access_tier" {
  description = "Access tier for blob storage: Hot or Cool."
  type        = string
  default     = "Hot"
}

variable "blob_versioning_enabled" {
  description = "Enable versioning on the storage account blob container."
  type        = bool
  default     = false
}

variable "key_vault_name" {
  description = "Name of the Key Vault (globally unique, 3–24 chars, alphanumeric and hyphens)."
  type        = string
}

variable "key_vault_sku_name" {
  description = "Key Vault SKU: standard or premium."
  type        = string
  default     = "standard"
}

variable "key_vault_soft_delete_retention_days" {
  description = "Number of days to retain soft-deleted Key Vault data."
  type        = number
  default     = 7
}

variable "key_vault_purge_protection_enabled" {
  description = "Enable purge protection on the Key Vault."
  type        = bool
  default     = false
}

variable "key_vault_enabled_for_disk_encryption" {
  description = "Allow Key Vault to be used for Azure disk encryption."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to assign to the storage account and Key Vault."
  type        = map(string)
  default     = {}
}
