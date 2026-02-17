# ------------------------------------------------------------------------------
# Azure Automation Account (e.g. IncidentResponseAutomation for runbooks / hybrid workers)
# ------------------------------------------------------------------------------

resource "azurerm_automation_account" "this" {
  name                          = var.automation_account_name
  location                      = var.location
  resource_group_name           = var.resource_group_name
  sku_name                      = var.sku_name
  local_authentication_enabled  = var.local_authentication_enabled
  public_network_access_enabled = var.public_network_access_enabled
  tags                          = var.tags

  identity {
    type = "SystemAssigned"
  }
}

# ------------------------------------------------------------------------------
# Automation variables for IncidentResponse runbook (destination from Terraform)
# ------------------------------------------------------------------------------
locals {
  forensics_vars = var.forensics_destination != null ? {
    ForensicsSubscriptionId    = var.forensics_destination.subscription_id
    ForensicsResourceGroup      = var.forensics_destination.resource_group
    ForensicsStorageAccountName = var.forensics_destination.storage_account_name
    ForensicsContainerName      = var.forensics_destination.container_name
    ForensicsKeyVaultName      = var.forensics_destination.key_vault_name
  } : {}
}

resource "azurerm_automation_variable_string" "forensics" {
  for_each = local.forensics_vars

  name                    = each.key
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.this.name
  value                   = each.value
}

# ------------------------------------------------------------------------------
# IncidentResponseAutomation runbook (PowerShell, WebhookData parameter)
# ------------------------------------------------------------------------------
resource "azurerm_automation_runbook" "incident_response" {
  count = var.incident_response_runbook_content != null && var.incident_response_runbook_content != "" ? 1 : 0

  name                    = "IncidentResponseAutomation"
  location                = var.location
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.this.name
  runbook_type            = "PowerShell"
  log_verbose             = true
  log_progress            = true
  content                 = var.incident_response_runbook_content
}

# ------------------------------------------------------------------------------
# IncidentResponseContainVM runbook (PowerShell, WebhookData parameter; logVerbose/logProgress false)
# ------------------------------------------------------------------------------
resource "azurerm_automation_runbook" "incident_response_contain_vm" {
  count = var.incident_response_contain_vm_runbook_content != null && var.incident_response_contain_vm_runbook_content != "" ? 1 : 0

  name                    = "IncidentResponseContainVM"
  location                = var.location
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.this.name
  runbook_type            = "PowerShell"
  log_verbose             = false
  log_progress            = false
  content                 = var.incident_response_contain_vm_runbook_content
}
