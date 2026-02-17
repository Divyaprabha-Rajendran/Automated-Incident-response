# ------------------------------------------------------------------------------
# Forensics storage module outputs
# ------------------------------------------------------------------------------

output "storage_account_id" {
  description = "The ID of the storage account."
  value       = azurerm_storage_account.this.id
}

output "storage_account_name" {
  description = "The name of the storage account."
  value       = azurerm_storage_account.this.name
}

output "storage_account_primary_connection_string" {
  description = "Primary connection string for the storage account (sensitive)."
  value       = azurerm_storage_account.this.primary_connection_string
  sensitive   = true
}

output "storage_account_primary_access_key" {
  description = "Primary access key for the storage account (sensitive)."
  value       = azurerm_storage_account.this.primary_access_key
  sensitive   = true
}

output "container_name" {
  description = "The name of the blob container for snapshots."
  value       = azurerm_storage_container.snapshots.name
}

output "container_id" {
  description = "The ID of the blob container."
  value       = azurerm_storage_container.snapshots.id
}

output "key_vault_id" {
  description = "The ID of the Key Vault."
  value       = azurerm_key_vault.this.id
}

output "key_vault_name" {
  description = "The name of the Key Vault."
  value       = azurerm_key_vault.this.name
}

output "key_vault_uri" {
  description = "The URI of the Key Vault."
  value       = azurerm_key_vault.this.vault_uri
}
