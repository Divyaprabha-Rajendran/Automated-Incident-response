# ------------------------------------------------------------------------------
# VNET variables
# ------------------------------------------------------------------------------

variable "resource_group_name" {
  description = "Name of the resource group where the VNET and related resources will be created."
  type        = string
}

variable "location" {
  description = "Azure region for all resources."
  type        = string
  default     = "East US"
}

variable "vnet_name" {
  description = "Name of the virtual network."
  type        = string
}

variable "vnet_address_space" {
  description = "List of address spaces (CIDR blocks) for the VNET."
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "tags" {
  description = "Tags to apply to all resources created by this module."
  type        = map(string)
  default     = {}
}

# ------------------------------------------------------------------------------
# Bastion host (optional)
# ------------------------------------------------------------------------------

variable "enable_bastion" {
  description = "Create an Azure Bastion host in the AzureBastionSubnet. Subnet must exist and be named exactly AzureBastionSubnet."
  type        = bool
  default     = false
}

variable "bastion_host_name" {
  description = "Name of the Bastion host resource."
  type        = string
  default     = "bastion-host"
}

# ------------------------------------------------------------------------------
# Subnet variables
# ------------------------------------------------------------------------------

variable "subnets" {
  description = "List of subnets to create. Each subnet can reference an NSG by key (nsg_key)."
  type = list(object({
    name             = string
    address_prefixes = list(string)
    service_endpoints = optional(list(string), [])
    nsg_key          = optional(string, null)  # Key into var.nsgs; if set, this subnet gets that NSG
    delegation       = optional(list(object({
      name = string
      service_delegation = object({
        name    = string
        actions = optional(list(string), [])
      })
    })), [])
  }))
  default = [
    {
      name             = "default"
      address_prefixes = ["10.0.1.0/24"]
      service_endpoints = []
      nsg_key          = "default"
      delegation       = []
    }
  ]
}

# ------------------------------------------------------------------------------
# NSG variables (keyed by nsg_key referenced from subnets)
# ------------------------------------------------------------------------------

variable "nsgs" {
  description = "Map of NSG key to NSG configuration. Each entry defines an NSG and its rules. Keys must match subnet nsg_key values."
  type = map(object({
    name = optional(string, null)  # If null, key is used as name
    rules = optional(list(object({
      name                         = string
      priority                     = number
      direction                    = string   # Inbound | Outbound
      access                       = string   # Allow | Deny
      protocol                     = string   # * | Tcp | Udp | Icmp | Ah | Esp
      source_port_range            = optional(string, "*")
      destination_port_range      = optional(string, "*")
      source_address_prefix       = optional(string, "*")
      destination_address_prefix  = optional(string, "*")
      source_address_prefixes     = optional(list(string), null)
      destination_address_prefixes = optional(list(string), null)
      description                  = optional(string, null)
    })), [])
  }))
  default = {
    default = {
      name = null
      rules = [
        {
          name                         = "AllowVnetInbound"
          priority                     = 100
          direction                    = "Inbound"
          access                       = "Allow"
          protocol                     = "*"
          source_port_range            = "*"
          destination_port_range      = "*"
          source_address_prefix        = "VirtualNetwork"
          destination_address_prefix  = "VirtualNetwork"
          source_address_prefixes     = null
          destination_address_prefixes = null
          description                  = "Allow traffic from VNet"
        },
        {
          name                         = "AllowAzureLoadBalancerInbound"
          priority                     = 110
          direction                    = "Inbound"
          access                       = "Allow"
          protocol                     = "*"
          source_port_range            = "*"
          destination_port_range      = "*"
          source_address_prefix        = "AzureLoadBalancer"
          destination_address_prefix  = "*"
          source_address_prefixes     = null
          destination_address_prefixes = null
          description                  = "Allow Azure Load Balancer"
        },
        {
          name                         = "DenyAllInbound"
          priority                     = 4096
          direction                    = "Inbound"
          access                       = "Deny"
          protocol                     = "*"
          source_port_range            = "*"
          destination_port_range      = "*"
          source_address_prefix        = "*"
          destination_address_prefix  = "*"
          source_address_prefixes     = null
          destination_address_prefixes = null
          description                  = "Deny all other inbound"
        }
      ]
    }
  }
}

# ------------------------------------------------------------------------------
# VMs (optional): map of key => VM config; use subnet_key = subnet name from subnets
# ------------------------------------------------------------------------------

variable "vms" {
  description = "Map of VM key to VM configuration. Use subnet_key = subnet name (e.g. \"private\"). Set to {} to create no VMs."
  type = map(object({
    name        = string
    vm_size     = optional(string, "Standard_B2s")
    subnet_key  = string              # Subnet name from var.subnets (e.g. \"private\", \"default\")
    os_type     = string              # \"linux\" | \"windows\"
    image       = optional(object({
      publisher = string
      offer     = string
      sku       = string
      version   = optional(string, "latest")
    }), null)
    admin_username = string
    admin_password = optional(string, null)
    computer_name  = optional(string, null)       # Windows: hostname (max 15 chars). If null and name length > 15, truncated.
    ssh_public_key      = optional(string, null)  # Public key content (set by root from file when ssh_public_key_path used)
    ssh_public_key_path = optional(string, null)  # Ignored here; root reads file() and passes as ssh_public_key
    enable_public_ip = optional(bool, false)
    custom_script_extension = optional(object({
      file_uris       = optional(list(string), [])
      command_to_run  = string
      timeout_seconds = optional(number, 30)
    }), null)
  }))
  default = {}
}
