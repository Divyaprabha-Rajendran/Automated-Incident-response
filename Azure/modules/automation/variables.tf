# ------------------------------------------------------------------------------
# Automation module variables
# ------------------------------------------------------------------------------

variable "resource_group_name" {
  description = "Name of the resource group where the Automation Account will be created."
  type        = string
}

variable "location" {
  description = "Azure region for the Automation Account."
  type        = string
}

variable "automation_account_name" {
  description = "Name of the Automation Account (e.g. IncidentResponseAutomation)."
  type        = string
}

variable "sku_name" {
  description = "SKU of the Automation Account. Possible values are Basic and Free."
  type        = string
  default     = "Basic"
}

variable "local_authentication_enabled" {
  description = "Whether local (non-AAD) authentication is allowed. Corresponds to disableLocalAuth = false when true."
  type        = bool
  default     = true
}

variable "public_network_access_enabled" {
  description = "Whether public network access is allowed for the automation account."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to assign to the Automation Account."
  type        = map(string)
  default     = {}
}

# ------------------------------------------------------------------------------
# Forensics destination (for IncidentResponse runbook) – stored as Automation variables
# ------------------------------------------------------------------------------
variable "forensics_destination" {
  description = "Forensics destination used by the IncidentResponse runbook. Stored as Automation Account variables (ForensicsSubscriptionId, ForensicsResourceGroup, etc.). Set to null to skip creating these variables."
  type = object({
    subscription_id       = string
    resource_group       = string
    storage_account_name = string
    container_name       = optional(string, "snapshots")
    key_vault_name      = string
  })
  default = null
}

# ------------------------------------------------------------------------------
# IncidentResponse runbook (PowerShell script content from Terraform)
# ------------------------------------------------------------------------------
variable "incident_response_runbook_content" {
  description = "PowerShell script content for the IncidentResponseAutomation runbook. Pass file(\"path/to/IncidentResponseAutomation\") from the caller. Set to null to skip creating the runbook."
  type        = string
  default     = null
}

variable "incident_response_contain_vm_runbook_content" {
  description = "PowerShell script content for the IncidentResponseContainVM runbook. Pass file(\"path/to/IncidentResponseContainVM\") from the caller. Set to null to skip creating the runbook."
  type        = string
  default     = null
}
