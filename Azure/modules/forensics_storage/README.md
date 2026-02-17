# Forensics Storage Module

Creates an Azure Storage Account with a blob container (for snapshots) and a Key Vault in the same resource group. Use this in the subscription/resource group where you want to store forensics snapshots and blob hashes (e.g. destination for the IncidentResponse runbook).

## Resources

- **azurerm_storage_account** – Storage account (Standard LRS by default)
- **azurerm_storage_container** – Blob container (default name: `snapshots`)
- **azurerm_key_vault** – Key Vault with an access policy for the current Terraform client

## Usage

Use in an environment that has (or creates) the target resource group, for example the forensics destination subscription:

```hcl
module "forensics_storage" {
  source = "../../modules/forensics_storage"

  resource_group_name  = "ForensicsRG"
  location             = "Canada East"
  storage_account_name = "forensicsapoc"   # Globally unique, 3–24 chars, lowercase alphanumeric
  container_name       = "snapshots"
  key_vault_name       = "ForensicKV"     # Globally unique

  tags = {
    Environment = "forensics"
    Project     = "CAGE"
  }
}
```

## Variables

| Name | Description | Default |
|------|-------------|--------|
| `resource_group_name` | Resource group for storage and Key Vault | (required) |
| `location` | Azure region | (required) |
| `storage_account_name` | Storage account name (globally unique) | (required) |
| `container_name` | Blob container name | `"snapshots"` |
| `key_vault_name` | Key Vault name (globally unique) | (required) |
| `container_access_type` | Container access: private, blob, container | `"private"` |
| `account_tier` | Standard or Premium | `"Standard"` |
| `account_replication_type` | LRS, GRS, etc. | `"LRS"` |
| `tags` | Tags for both resources | `{}` |

## Outputs

- `storage_account_id`, `storage_account_name`, `storage_account_primary_connection_string`, `storage_account_primary_access_key`
- `container_name`, `container_id`
- `key_vault_id`, `key_vault_name`, `key_vault_uri`

Grant the Automation account’s managed identity access to this storage account and Key Vault in the destination subscription so the IncidentResponse runbook can copy snapshots and store hashes.
