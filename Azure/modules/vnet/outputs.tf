# ------------------------------------------------------------------------------
# Resource Group outputs
# ------------------------------------------------------------------------------

output "resource_group_name" {
  description = "Name of the resource group created by the module."
  value       = azurerm_resource_group.this.name
}

output "resource_group_id" {
  description = "ID of the resource group created by the module."
  value       = azurerm_resource_group.this.id
}

# ------------------------------------------------------------------------------
# VNET outputs
# ------------------------------------------------------------------------------

output "vnet_id" {
  description = "ID of the virtual network."
  value       = azurerm_virtual_network.this.id
}

output "vnet_name" {
  description = "Name of the virtual network."
  value       = azurerm_virtual_network.this.name
}

output "vnet_address_space" {
  description = "Address space of the virtual network."
  value       = azurerm_virtual_network.this.address_space
}

# ------------------------------------------------------------------------------
# Subnet outputs
# ------------------------------------------------------------------------------

output "subnet_ids" {
  description = "Map of subnet name to subnet ID. Use module.vnet.subnet_ids[\"subnet_name\"] to reference a subnet."
  value       = { for k, s in azurerm_subnet.this : k => s.id }
}

# ------------------------------------------------------------------------------
# NSG outputs
# ------------------------------------------------------------------------------

output "nsg_ids" {
  description = "Map of NSG key to NSG ID."
  value       = { for k, n in azurerm_network_security_group.this : k => n.id }
}

output "nsg_names" {
  description = "Map of NSG key to NSG name."
  value       = { for k, n in azurerm_network_security_group.this : k => n.name }
}

# ------------------------------------------------------------------------------
# VM outputs (when vms is non-empty)
# ------------------------------------------------------------------------------

output "vm_ids" {
  description = "Map of VM key to VM ID (Linux and Windows)."
  value = merge(
    { for k, v in azurerm_linux_virtual_machine.this : k => v.id },
    { for k, v in azurerm_windows_virtual_machine.this : k => v.id }
  )
}

output "vm_private_ips" {
  description = "Map of VM key to private IP address."
  value       = { for k, n in azurerm_network_interface.vm : k => n.private_ip_address }
}

output "vm_public_ips" {
  description = "Map of VM key to public IP (only for VMs with enable_public_ip = true)."
  value       = { for k, p in azurerm_public_ip.vm : k => p.ip_address }
}

output "vm_network_interface_ids" {
  description = "Map of VM key to network interface ID."
  value       = { for k, n in azurerm_network_interface.vm : k => n.id }
}

# ------------------------------------------------------------------------------
# Bastion outputs (when enable_bastion = true)
# ------------------------------------------------------------------------------

output "bastion_host_id" {
  description = "ID of the Bastion host (when enable_bastion = true)."
  value       = try(azurerm_bastion_host.this[0].id, null)
}

output "bastion_host_dns_name" {
  description = "DNS name of the Bastion host (when enable_bastion = true)."
  value       = try(azurerm_bastion_host.this[0].dns_name, null)
}
