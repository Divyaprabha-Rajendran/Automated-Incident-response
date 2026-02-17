variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "East US"
}

# VNET module inputs
variable "vnet_name" {
  description = "Name of the virtual network"
  type        = string
}

variable "vnet_address_space" {
  description = "Address space (CIDR list) for the VNET"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "subnets" {
  description = "List of subnets; each can reference an NSG via nsg_key"
  type = list(object({
    name             = string
    address_prefixes = list(string)
    service_endpoints = optional(list(string), [])
    nsg_key          = optional(string, null)
    delegation       = optional(list(object({
      name = string
      service_delegation = object({
        name    = string
        actions = optional(list(string), [])
      })
    })), [])
  }))
}

variable "nsgs" {
  description = "Map of NSG key to { name, rules }; keys must match subnet nsg_key"
  type = map(object({
    name  = optional(string, null)
    rules = optional(list(object({
      name                         = string
      priority                     = number
      direction                    = string
      access                       = string
      protocol                     = string
      source_port_range            = optional(string, "*")
      destination_port_range       = optional(string, "*")
      source_address_prefix        = optional(string, "*")
      destination_address_prefix   = optional(string, "*")
      source_address_prefixes      = optional(list(string), null)
      destination_address_prefixes = optional(list(string), null)
      description                  = optional(string, null)
    })), [])
  }))
}

variable "tags" {
  description = "Tags for all resources"
  type        = map(string)
  default     = {}
}

# Bastion host
variable "enable_bastion" {
  description = "Create Azure Bastion host in AzureBastionSubnet."
  type        = bool
  default     = false
}

variable "bastion_host_name" {
  description = "Name of the Bastion host resource."
  type        = string
  default     = "bastion-host"
}

# VM module inputs (optional; use subnet_key = subnet name from VNET, e.g. "private")
variable "vms" {
  description = "Map of VM key to VM config. Use subnet_key = subnet name (e.g. \"private\"). Set to null or {} to create no VMs."
  type = map(object({
    name        = string
    vm_size     = optional(string, "Standard_B2s")
    subnet_key  = string              # Subnet name from VNET (e.g. \"private\", \"default\")
    os_type     = string              # \"linux\" | \"windows\"
    image       = optional(object({
      publisher = string
      offer     = string
      sku       = string
      version   = optional(string, "latest")
    }), null)
    admin_username = string
    admin_password = optional(string, null)
    ssh_public_key_path = optional(string, null)  # Path to .pub file (e.g. C:/Users/you/.ssh/id_rsa.pub); read at apply
    enable_public_ip = optional(bool, false)
    custom_script_extension = optional(object({
      file_uris       = optional(list(string), [])
      command_to_run  = string
      timeout_seconds = optional(number, 30)
    }), null)
  }))
  default = null
}