locals {
  # Read SSH public key from file when ssh_public_key_path is set; pass content to module
  vms_with_ssh = var.vms != null ? {
    for k, v in var.vms : k => merge(
      v,
      (try(v.ssh_public_key_path, null) != null && v.ssh_public_key_path != "") ? { ssh_public_key = file(v.ssh_public_key_path) } : {}
    )
  } : {}
}

module "prod_setup" {
  source = "./modules/vnet"

  resource_group_name = "ProductionRG"
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