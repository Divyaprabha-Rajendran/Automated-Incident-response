# Azure VNET Terraform Module

Configurable module that creates an Azure Virtual Network with subnets, NSGs, and optional VMs (including custom script extensions).

## Resources created

- **azurerm_resource_group** – Resource group (created by the module; all other resources use it)
- **azurerm_virtual_network** – VNET
- **azurerm_subnet** – One per entry in `subnets`
- **azurerm_network_security_group** – One per key in `nsgs`
- **azurerm_network_security_rule** – Rules per NSG
- **azurerm_subnet_network_security_group_association** – Subnet–NSG links
- **azurerm_public_ip** (optional) – One per VM with `enable_public_ip = true`
- **azurerm_network_interface** – One per VM when `vms` is non-empty
- **azurerm_linux_virtual_machine** / **azurerm_windows_virtual_machine** – One per VM
- **azurerm_virtual_machine_extension** – Custom Script (Linux/Windows) when `custom_script_extension` is set per VM

## Usage

```hcl
module "vnet" {
  source = "./modules/vnet"

  resource_group_name = "MyRG"
  location            = "East US"
  vnet_name           = "MyVNet"
  vnet_address_space  = ["10.0.0.0/16"]

  subnets = [
    {
      name             = "default"
      address_prefixes = ["10.0.1.0/24"]
      service_endpoints = ["Microsoft.Storage"]
      nsg_key          = "default"
      delegation       = []
    },
    {
      name             = "apps"
      address_prefixes = ["10.0.2.0/24"]
      service_endpoints = []
      nsg_key          = "apps"
      delegation       = []
    }
  ]

  nsgs = {
    default = {
      name = null  # uses "nsg-default"
      rules = [/* see variables.tf default */]
    }
    apps = {
      name = "nsg-apps"
      rules = [
        {
          name                         = "AllowHTTPS"
          priority                     = 100
          direction                    = "Inbound"
          access                       = "Allow"
          protocol                     = "Tcp"
          source_port_range            = "*"
          destination_port_range       = "443"
          source_address_prefix        = "VirtualNetwork"
          destination_address_prefix   = "*"
          source_address_prefixes     = null
          destination_address_prefixes = null
          description                  = "Allow HTTPS from VNet"
        }
      ]
    }
  }

  vms = {
    my-vm = {
      name       = "my-vm"
      subnet_key = "apps"
      os_type    = "linux"
      admin_username = "azureuser"
      admin_password = null
      ssh_public_key_path = "C:/Users/you/.ssh/id_rsa.pub"  # Root reads file() and passes content as ssh_public_key
      custom_script_extension = { file_uris = [], command_to_run = "exit 0" }
    }
  }

  tags = { Environment = "production" }
}

output "vnet_id" { value = module.vnet.vnet_id }
output "subnet_ids" { value = module.vnet.subnet_ids }
output "nsg_ids" { value = module.vnet.nsg_ids }
```

## Variables

All settings are in `variables.tf` with defaults. Key variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `resource_group_name` | Resource group name | (required) |
| `location` | Azure region | `"East US"` |
| `vnet_name` | VNET name | (required) |
| `vnet_address_space` | VNET CIDR list | `["10.0.0.0/16"]` |
| `subnets` | List of subnet objects (name, address_prefixes, service_endpoints, nsg_key, delegation, etc.) | One default subnet |
| `nsgs` | Map of NSG key → { name, rules } | One default NSG |
| `vms` | Map of VM key → VM config (subnet_key, os_type, custom_script_extension, etc.) | `{}` (no VMs) |
| `tags` | Tags for all resources | `{}` |

Subnet `nsg_key` must match a key in `nsgs`. For VMs, `subnet_key` must match a subnet `name` from `subnets`.

## Outputs

- `resource_group_name`, `resource_group_id` – Created resource group
- `vnet_id`, `vnet_name`, `vnet_address_space`
- `subnet_ids` – map of subnet name → ID
- `nsg_ids`, `nsg_names` – map of NSG key → ID / name
- `vm_ids`, `vm_private_ips`, `vm_public_ips`, `vm_network_interface_ids` – when `vms` is non-empty
