# ------------------------------------------------------------------------------
# Storage account for snapshots (e.g. forensics)
# ------------------------------------------------------------------------------

resource "azurerm_storage_account" "this" {
  name                     = var.storage_account_name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = var.account_tier
  account_replication_type = var.account_replication_type
  account_kind             = var.account_kind
  access_tier              = var.access_tier
  tags                     = var.tags

  min_tls_version = "TLS1_2"

  blob_properties {
    versioning_enabled = var.blob_versioning_enabled
  }
}

# ------------------------------------------------------------------------------
# Blob container for snapshots (e.g. "snapshots")
# ------------------------------------------------------------------------------

resource "azurerm_storage_container" "snapshots" {
  name                  = var.container_name
  storage_account_name  = azurerm_storage_account.this.name
  container_access_type = var.container_access_type
}

# ------------------------------------------------------------------------------
# Key Vault (e.g. for storing snapshot hashes / secrets)
# ------------------------------------------------------------------------------

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "this" {
  name                        = var.key_vault_name
  location                    = var.location
  resource_group_name         = var.resource_group_name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = var.key_vault_sku_name
  soft_delete_retention_days  = var.key_vault_soft_delete_retention_days
  purge_protection_enabled    = var.key_vault_purge_protection_enabled
  tags                        = var.tags

  enabled_for_disk_encryption = var.key_vault_enabled_for_disk_encryption
}

# Grant the current Terraform client (e.g. run-as identity) access to Key Vault so Terraform can manage secrets later if needed
resource "azurerm_key_vault_access_policy" "terraform_client" {
  key_vault_id = azurerm_key_vault.this.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  secret_permissions = [
    "Get", "List", "Set", "Delete", "Recover", "Backup", "Restore"
  ]
}
