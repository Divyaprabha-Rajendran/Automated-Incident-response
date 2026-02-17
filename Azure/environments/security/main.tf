# Resolve VM config: inject SSH key when ssh_public_key_path is set (Linux); inject Windows admin password when not set in vms.
locals {
  vms_with_ssh = var.vms != null ? {
    for k, v in var.vms : k => merge(
      v,
      (try(v.ssh_public_key_path, null) != null && try(v.ssh_public_key_path, "") != "") ? { ssh_public_key = file(try(v.ssh_public_key_path, "")) } : {},
      (try(v.os_type, "") == "windows" && try(v.admin_password, null) == null && try(var.windows_vm_admin_password, null) != null && var.windows_vm_admin_password != "") ? { admin_password = var.windows_vm_admin_password } : {}
    )
  } : {}
}

module "vnet" {
  source = "../../modules/vnet"

  resource_group_name = var.resource_group_name
  location            = var.location
  vnet_name           = var.vnet_name
  vnet_address_space  = var.vnet_address_space
  subnets             = var.subnets
  nsgs                = var.nsgs
  vms                 = local.vms_with_ssh
  enable_bastion      = var.enable_bastion
  bastion_host_name   = var.bastion_host_name
  tags                = var.tags
}

# Runbook scripts (in SecurityRGAutomation; referenced by automation module)
locals {
  incident_response_script_path         = "${path.module}/../../resources/IncidentResponseAutomation"
  incident_response_contain_vm_script_path = "${path.module}/../../resources/IncidentResponseContainVM"
}

module "automation" {
  source = "../../modules/automation"

  resource_group_name                        = var.resource_group_name
  location                                   = var.location
  automation_account_name                    = var.automation_account_name
  sku_name                                   = "Basic"
  local_authentication_enabled               = true
  public_network_access_enabled              = true
  tags                                       = var.tags
  forensics_destination                      = var.forensics_destination
  incident_response_runbook_content          = file(local.incident_response_script_path)
  incident_response_contain_vm_runbook_content = file(local.incident_response_contain_vm_script_path)

  depends_on = [module.vnet]
}

# Optional: forensics storage (storage account + container + Key Vault) in same resource group
module "forensics_storage" {
  source = "../../modules/forensics_storage"
  count  = var.forensics_storage != null ? 1 : 0

  resource_group_name  = var.resource_group_name
  location             = var.location
  storage_account_name = var.forensics_storage.storage_account_name
  container_name       = var.forensics_storage.container_name
  key_vault_name       = var.forensics_storage.key_vault_name
  tags                 = var.tags

  depends_on = [module.vnet]
}
