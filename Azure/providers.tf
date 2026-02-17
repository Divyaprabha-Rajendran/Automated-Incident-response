terraform {
  required_providers {
    azurerm = {
      source  = "azurerm"
      version = "4.40.0"
    }
  }
}

# Default subscription
provider "azurerm" {
  alias           = "production"
  features {}
  subscription_id = "633d0b44-3342-4bfb-beca-fc7b3322565a"
}

# Additional subscription (use in resources with: provider = azurerm.secondary)
provider "azurerm" {
  alias           = "security"
  features        {}
  subscription_id = "baab7ade-9c09-4160-9794-e18f7d0e6595"
}
