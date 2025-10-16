terraform {
  required_version = ">= 1.9, < 2.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.117"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "2.7.0"
    }
  }
}

data "azurerm_client_config" "current" {}

provider "azapi" {}

provider "azurerm" {
  features {}
  subscription_id = "0450884c-0ba2-44d8-81e5-ab63e21fe7b8"
}