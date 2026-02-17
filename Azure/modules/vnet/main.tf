# ------------------------------------------------------------------------------
# Resource Group
# ------------------------------------------------------------------------------

resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# ------------------------------------------------------------------------------
# Virtual Network
# ------------------------------------------------------------------------------

resource "azurerm_virtual_network" "this" {
  name                = var.vnet_name
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = var.vnet_address_space
  tags                = var.tags
}

# ------------------------------------------------------------------------------
# Network Security Groups (one per key in var.nsgs)
# ------------------------------------------------------------------------------

resource "azurerm_network_security_group" "this" {
  for_each = var.nsgs

  name                = coalesce(each.value.name, "nsg-${each.key}")
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags
}

# ------------------------------------------------------------------------------
# NSG Rules (one rule resource per rule in each NSG)
# ------------------------------------------------------------------------------

resource "azurerm_network_security_rule" "this" {
  for_each = merge([
    for nsg_key, nsg in var.nsgs : {
      for rule in nsg.rules : "${nsg_key}-${rule.name}" => {
        nsg_key = nsg_key
        rule    = rule
      }
    }
  ]...)

  name                         = each.value.rule.name
  priority                     = each.value.rule.priority
  direction                    = each.value.rule.direction
  access                       = each.value.rule.access
  protocol                     = each.value.rule.protocol
  source_port_range            = each.value.rule.source_port_range
  destination_port_range       = each.value.rule.destination_port_range
  source_address_prefix        = each.value.rule.source_address_prefixes != null ? null : (each.value.rule.source_address_prefix != null ? each.value.rule.source_address_prefix : "*")
  destination_address_prefix   = each.value.rule.destination_address_prefixes != null ? null : (each.value.rule.destination_address_prefix != null ? each.value.rule.destination_address_prefix : "*")
  source_address_prefixes      = each.value.rule.source_address_prefixes
  destination_address_prefixes = each.value.rule.destination_address_prefixes
  description                  = each.value.rule.description

  resource_group_name         = azurerm_resource_group.this.name
  network_security_group_name = azurerm_network_security_group.this[each.value.nsg_key].name
}

# ------------------------------------------------------------------------------
# Subnets
# ------------------------------------------------------------------------------

resource "azurerm_subnet" "this" {
  for_each = { for idx, s in var.subnets : s.name => merge(s, { index = idx }) }

  name                 = each.value.name
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = each.value.address_prefixes

  service_endpoints = each.value.service_endpoints

  dynamic "delegation" {
    for_each = each.value.delegation
    content {
      name = delegation.value.name
      service_delegation {
        name    = delegation.value.service_delegation.name
        actions = delegation.value.service_delegation.actions
      }
    }
  }
}

# ------------------------------------------------------------------------------
# Subnet–NSG associations (only for subnets that have nsg_key set)
# ------------------------------------------------------------------------------

resource "azurerm_subnet_network_security_group_association" "this" {
  for_each = { for s in var.subnets : s.name => s if s.nsg_key != null && try(var.nsgs[s.nsg_key], null) != null }

  subnet_id                 = azurerm_subnet.this[each.value.name].id
  network_security_group_id = azurerm_network_security_group.this[each.value.nsg_key].id
}

# ------------------------------------------------------------------------------
# Azure Bastion host (optional; requires subnet named AzureBastionSubnet)
# ------------------------------------------------------------------------------

locals {
  has_bastion_subnet = length([for s in var.subnets : s if s.name == "AzureBastionSubnet"]) > 0
  create_bastion    = var.enable_bastion && local.has_bastion_subnet
}

resource "azurerm_public_ip" "bastion" {
  count = local.create_bastion ? 1 : 0

  name                = "pip-${var.bastion_host_name}"
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_bastion_host" "this" {
  count = local.create_bastion ? 1 : 0

  name                = var.bastion_host_name
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.this["AzureBastionSubnet"].id
    public_ip_address_id = azurerm_public_ip.bastion[0].id
  }
}

# ------------------------------------------------------------------------------
# VMs (optional): resolve subnet_key to subnet_id
# ------------------------------------------------------------------------------

locals {
  vms_config = {
    for k, v in var.vms : k => merge(
      { for key, val in v : key => val if key != "subnet_key" },
      { subnet_id = azurerm_subnet.this[v.subnet_key].id }
    )
  }
}

# ------------------------------------------------------------------------------
# Public IP (optional, one per VM with enable_public_ip = true)
# ------------------------------------------------------------------------------

resource "azurerm_public_ip" "vm" {
  for_each = { for k, v in local.vms_config : k => v if v.enable_public_ip }

  name                = "pip-${each.value.name}"
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

# ------------------------------------------------------------------------------
# Network interface (one per VM)
# ------------------------------------------------------------------------------

resource "azurerm_network_interface" "vm" {
  for_each = local.vms_config

  name                = "nic-${each.value.name}"
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = each.value.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = each.value.enable_public_ip ? azurerm_public_ip.vm[each.key].id : null
  }
}

# ------------------------------------------------------------------------------
# Default images when not specified
# ------------------------------------------------------------------------------

locals {
  default_linux_image = {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
  default_windows_image = {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }
  vm_images = {
    for k, v in local.vms_config : k => v.image != null ? v.image : (
      v.os_type == "linux" ? local.default_linux_image : local.default_windows_image
    )
  }
}

# ------------------------------------------------------------------------------
# Linux VMs
# ------------------------------------------------------------------------------

resource "azurerm_linux_virtual_machine" "this" {
  for_each = { for k, v in local.vms_config : k => v if v.os_type == "linux" }

  name                = each.value.name
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  size                = each.value.vm_size
  admin_username      = each.value.admin_username
  tags                = var.tags

  network_interface_ids = [azurerm_network_interface.vm[each.key].id]

  admin_password                  = each.value.admin_password
  disable_password_authentication = each.value.ssh_public_key != null && each.value.ssh_public_key != ""

  dynamic "admin_ssh_key" {
    for_each = each.value.ssh_public_key != null && each.value.ssh_public_key != "" ? [1] : []
    content {
      username   = each.value.admin_username
      public_key = each.value.ssh_public_key
    }
  }

  os_disk {
    caching             = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = local.vm_images[each.key].publisher
    offer     = local.vm_images[each.key].offer
    sku       = local.vm_images[each.key].sku
    version   = local.vm_images[each.key].version
  }
}

# ------------------------------------------------------------------------------
# Windows VMs
# ------------------------------------------------------------------------------

# Only create Windows VMs when admin_password is set (Azure requires it). Skip when null/empty so plan works with no vms or before password is supplied.
resource "azurerm_windows_virtual_machine" "this" {
  for_each = { for k, v in local.vms_config : k => v if v.os_type == "windows" && try(v.admin_password, null) != null && v.admin_password != "" }

  name                = each.value.name
  computer_name       = try(each.value.computer_name, null) != null ? each.value.computer_name : substr(each.value.name, 0, min(length(each.value.name), 15))
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  size                = each.value.vm_size
  admin_username      = each.value.admin_username
  admin_password      = each.value.admin_password
  tags                = var.tags

  network_interface_ids = [azurerm_network_interface.vm[each.key].id]

  os_disk {
    caching             = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = local.vm_images[each.key].publisher
    offer     = local.vm_images[each.key].offer
    sku       = local.vm_images[each.key].sku
    version   = local.vm_images[each.key].version
  }
}

# ------------------------------------------------------------------------------
# Custom script extension (Linux)
# ------------------------------------------------------------------------------

resource "azurerm_virtual_machine_extension" "custom_script_linux" {
  for_each = {
    for k, v in local.vms_config : k => v
    if v.os_type == "linux" && v.custom_script_extension != null
  }

  name                 = "CustomScript"
  virtual_machine_id   = azurerm_linux_virtual_machine.this[each.key].id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.1"

  settings = jsonencode({
    fileUris         = each.value.custom_script_extension.file_uris
    commandToExecute = each.value.custom_script_extension.command_to_run
  })

  tags = var.tags
}

# ------------------------------------------------------------------------------
# Custom script extension (Windows)
# ------------------------------------------------------------------------------

resource "azurerm_virtual_machine_extension" "custom_script_windows" {
  for_each = {
    for k, v in local.vms_config : k => v
    if v.os_type == "windows" && v.custom_script_extension != null && try(v.admin_password, null) != null && v.admin_password != ""
  }

  name                 = "CustomScriptExtension"
  virtual_machine_id   = azurerm_windows_virtual_machine.this[each.key].id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = jsonencode({
    fileUris         = each.value.custom_script_extension.file_uris
    commandToExecute = each.value.custom_script_extension.command_to_run
  })

  tags = var.tags
}
