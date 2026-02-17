variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "East US"
}

variable "vnet_name" { type = string }
variable "vnet_address_space" {
  type    = list(string)
  default = ["10.0.0.0/16"]
}

variable "subnets" { type = any }
variable "nsgs" { type = any }
variable "tags" {
  type    = map(string)
  default = {}
}

variable "enable_bastion" {
  type    = bool
  default = false
}

variable "bastion_host_name" {
  type    = string
  default = "bastion-host"
}

variable "vms" {
  type    = any
  default = null
}
