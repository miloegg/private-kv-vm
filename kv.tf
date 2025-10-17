resource "azurerm_private_dns_zone" "this" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.this.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "example" {
  name                  = "test"
  resource_group_name   = azurerm_resource_group.this.name
  private_dns_zone_name = azurerm_private_dns_zone.this.name
  virtual_network_id    = "/subscriptions/0450884c-0ba2-44d8-81e5-ab63e21fe7b8/resourceGroups/privatekvrg/providers/Microsoft.Network/virtualNetworks/privatekvvm-vnet"
}

module "avm_res_keyvault_vault" {
  source  = "Azure/avm-res-keyvault-vault/azurerm"
  version = "0.10.2"

  location = azurerm_resource_group.this.location
  # source             = "Azure/avm-res-keyvault-vault/azurerm"
  name                = module.naming.key_vault.name_unique
  resource_group_name = azurerm_resource_group.this.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  enable_telemetry    = false
  private_endpoints = {
    primary = {
      private_dns_zone_resource_ids = [azurerm_private_dns_zone.this.id]
      subnet_resource_id            = "/subscriptions/0450884c-0ba2-44d8-81e5-ab63e21fe7b8/resourceGroups/privatekvrg/providers/Microsoft.Network/virtualNetworks/privatekvvm-vnet/subnets/default"
    }
  }
  public_network_access_enabled = false
  enabled_for_disk_encryption   = true

  network_acls = {
    default_action = "Deny"
    bypass         = "AzureServices"
  }
  role_assignments = {
    deployment_user_secrets = { #give the deployment user access to secrets
      role_definition_id_or_name = "Key Vault Secrets Officer"
      principal_id               = data.azurerm_client_config.current.object_id
    }
    deployment_user_keys = { #give the deployment user access to keys
      role_definition_id_or_name = "Key Vault Crypto Officer"
      principal_id               = data.azurerm_client_config.current.object_id
    }
    user_managed_identity_keys = { #give the user assigned managed identity for the disk encryption set access to keys
      role_definition_id_or_name = "Key Vault Crypto Officer"
      principal_id               = azurerm_user_assigned_identity.example_identity.principal_id
      principal_type             = "ServicePrincipal"
    }
  }

  wait_for_rbac_before_key_operations = {
    create = "120s"
  }
  wait_for_rbac_before_secret_operations = {
    create = "120s"
  }
}

/*
resource "azapi_resource_action" "put_accessPolicy" {
  type        = "Microsoft.KeyVault/vaults/accessPolicies@2023-02-01"
  resource_id = "${module.avm_res_keyvault_vault.resource_id}/accessPolicies/add"
  method      = "PUT"
  body = {
    properties = {
      accessPolicies = [
        {
          objectId = data.azurerm_client_config.current.object_id
          permissions = {
            certificates = [
              "ManageContacts",
            ]
            keys = [
              "All",
            ]
            secrets = [
              "All",
            ]
            storage = [
            ]
          }
          tenantId = data.azurerm_client_config.current.tenant_id
        },
      ]
    }
  }
  response_export_values = ["*"]
  depends_on             = [module.avm_res_keyvault_vault]
}
*/

data "azapi_resource_id" "key" {
  type      = "Microsoft.KeyVault/vaults/keys@2023-02-01"
  parent_id = module.avm_res_keyvault_vault.resource_id
  name      = "deskey"
}

resource "azapi_resource_action" "put_key" {
  type        = "Microsoft.KeyVault/vaults/keys@2023-02-01"
  resource_id = data.azapi_resource_id.key.id
  method      = "PUT"
  body = {
    properties = {
      keySize = 2048
      kty     = "RSA"
      keyOps  = ["encrypt", "decrypt", "sign", "verify", "wrapKey", "unwrapKey"]
    }
  }
  response_export_values = ["*"]
  depends_on             = [module.avm_res_keyvault_vault]
  # depends_on             = [azapi_resource_action.put_accessPolicy]
}

resource "tls_private_key" "this" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

data "azapi_resource_id" "sshprivatekey" {
  type      = "Microsoft.KeyVault/vaults/secrets@2023-02-01"
  parent_id = module.avm_res_keyvault_vault.resource_id
  name      = "sshprivatekey"
}

resource "azapi_resource_action" "put_secret" {
  type        = "Microsoft.KeyVault/vaults/secrets@2023-02-01"
  resource_id = data.azapi_resource_id.sshprivatekey.id
  method      = "PUT"
  body = {
    properties = {
      value = tls_private_key.this.private_key_pem
    }
  }
  response_export_values = ["*"]
  depends_on             = [module.avm_res_keyvault_vault]
  # depends_on             = [azapi_resource_action.put_accessPolicy]
}



# resource "azurerm_key_vault_secret" "admin_ssh_key" {
#   key_vault_id = module.avm_res_keyvault_vault.resource_id
#   name         = "azureuser-ssh-private-key"
#   value        = tls_private_key.this.private_key_pem

#   depends_on = [
#     module.avm_res_keyvault_vault
#   ]
# }