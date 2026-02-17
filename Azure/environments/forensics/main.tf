# Forensics environment: VNet (no VMs) + storage account with snapshots container + Key Vault
# All resources in the same resource group (ForensicsRGAutomation).
# Storage/container/Key Vault names get name_suffix appended (e.g. timestamp); truncated to Azure limits.

locals {
  # Storage: max 24 chars, lowercase alphanumeric only
  storage_account_name_final = lower(substr("${var.storage_account_name}${var.name_suffix}", 0, 24))
  # Container: snapshots + suffix (no strict length limit; use reasonable length)
  container_name_final = "${var.container_name}${var.name_suffix}"
  # Key Vault: max 24 chars, alphanumeric and hyphens
  key_vault_name_final = substr("${var.key_vault_name}${var.name_suffix}", 0, 24)
}

module "vnet" {
  source = "../../modules/vnet"

  resource_group_name = var.resource_group_name
  location            = var.location
  vnet_name           = var.vnet_name
  vnet_address_space  = var.vnet_address_space
  subnets             = var.subnets
  nsgs                = var.nsgs
  vms                 = coalesce(var.vms, {})
  enable_bastion      = var.enable_bastion
  bastion_host_name   = var.bastion_host_name
  tags                = var.tags
}

module "forensics_storage" {
  source = "../../modules/forensics_storage"

  resource_group_name  = var.resource_group_name
  location             = var.location
  storage_account_name = local.storage_account_name_final
  container_name       = local.container_name_final
  key_vault_name       = local.key_vault_name_final
  tags                 = var.tags

  depends_on = [module.vnet]
}
