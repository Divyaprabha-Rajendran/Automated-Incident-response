# ------------------------------------------------------------------------------
# Automation module outputs
# ------------------------------------------------------------------------------

output "id" {
  description = "The ID of the Automation Account."
  value       = azurerm_automation_account.this.id
}

output "name" {
  description = "The name of the Automation Account."
  value       = azurerm_automation_account.this.name
}

output "identity" {
  description = "System-assigned identity (principal_id, tenant_id) for the Automation Account."
  value = {
    principal_id = azurerm_automation_account.this.identity[0].principal_id
    tenant_id    = azurerm_automation_account.this.identity[0].tenant_id
  }
}

output "incident_response_runbook_id" {
  description = "ID of the IncidentResponseAutomation runbook, if created."
  value       = try(azurerm_automation_runbook.incident_response[0].id, null)
}

output "incident_response_runbook_name" {
  description = "Name of the IncidentResponseAutomation runbook, if created."
  value       = try(azurerm_automation_runbook.incident_response[0].name, null)
}

output "incident_response_contain_vm_runbook_id" {
  description = "ID of the IncidentResponseContainVM runbook, if created."
  value       = try(azurerm_automation_runbook.incident_response_contain_vm[0].id, null)
}

output "incident_response_contain_vm_runbook_name" {
  description = "Name of the IncidentResponseContainVM runbook, if created."
  value       = try(azurerm_automation_runbook.incident_response_contain_vm[0].name, null)
}

