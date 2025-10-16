module "naming" {
  source  = "Azure/naming/azurerm"
  version = "0.3.0"
}

# This is required for resource modules
resource "azurerm_resource_group" "this" {
  location = "southeastasia"
  name     = module.naming.resource_group.name_unique
}

resource "azurerm_user_assigned_identity" "example_identity" {
  location            = azurerm_resource_group.this.location
  name                = module.naming.user_assigned_identity.name_unique
  resource_group_name = azurerm_resource_group.this.name
}

resource "azurerm_disk_encryption_set" "this" {
  location                  = azurerm_resource_group.this.location
  name                      = module.naming.disk_encryption_set.name_unique
  resource_group_name       = azurerm_resource_group.this.name
  key_vault_key_id          = "https://${module.avm_res_keyvault_vault.name}.vault.azure.net/keys/${data.azapi_resource_id.key.name}"
  auto_key_rotation_enabled = true

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.example_identity.id]
  }
}


module "testvm" {
  source   = "Azure/avm-res-compute-virtualmachine/azurerm"
  version  = "0.19.3"
  location = azurerm_resource_group.this.location
  name     = module.naming.virtual_machine.name_unique
  network_interfaces = {
    network_interface_1 = {
      name = "${module.naming.network_interface.name_unique}-1"
      ip_configurations = {
        ip_configuration_1 = {
          name                          = "${module.naming.network_interface.name_unique}-nic1-ipconfig1"
          private_ip_subnet_resource_id = "/subscriptions/0450884c-0ba2-44d8-81e5-ab63e21fe7b8/resourceGroups/privatekvrg/providers/Microsoft.Network/virtualNetworks/privatekvvm-vnet/subnets/default"
          create_public_ip_address      = true
          public_ip_address_name        = "testvm-pip"
        }
      }
      resource_group_name = azurerm_resource_group.this.name
    }
  }
  resource_group_name = azurerm_resource_group.this.name
  zone                = null
  account_credentials = {
    admin_credentials = {
      username                           = "azureuser"
      ssh_keys                           = [tls_private_key.this.public_key_openssh]
      generate_admin_password_or_ssh_key = false
    }
  }
  data_disk_managed_disks = {
    disk1 = {
      name                   = "${module.naming.managed_disk.name_unique}-lun0"
      storage_account_type   = "Premium_LRS"
      lun                    = 0
      caching                = "ReadWrite"
      disk_size_gb           = 32
      disk_encryption_set_id = azurerm_disk_encryption_set.this.id
      resource_group_name    = azurerm_resource_group.this.name
      role_assignments = {
        role_assignment_2 = {
          principal_id               = data.azurerm_client_config.current.client_id
          role_definition_id_or_name = "Contributor"
          description                = "Assign the Contributor role to the deployment user on this managed disk resource scope."
          principal_type             = "ServicePrincipal"
        }
      }
    }
  }
  enable_telemetry = false
  managed_identities = {
    system_assigned            = true
    user_assigned_resource_ids = [azurerm_user_assigned_identity.example_identity.id]
  }
  os_disk = {
    caching                = "ReadWrite"
    storage_account_type   = "Premium_LRS"
    disk_encryption_set_id = azurerm_disk_encryption_set.this.id
  }
  os_type = "Linux"
  role_assignments = {
    role_assignment_2 = {
      principal_id               = data.azurerm_client_config.current.client_id
      role_definition_id_or_name = "Virtual Machine Contributor"
      description                = "Assign the Virtual Machine Contributor role to the deployment user on this virtual machine resource scope."
      principal_type             = "ServicePrincipal"
    }
  }
  role_assignments_system_managed_identity = {
    role_assignment_1 = {
      scope_resource_id          = module.avm_res_keyvault_vault.resource_id
      role_definition_id_or_name = "Key Vault Secrets Officer"
      description                = "Assign the Key Vault Secrets Officer role to the virtual machine's system managed identity"
      principal_type             = "ServicePrincipal"
    }
  }
  sku_size = "Standard_B2s"
  source_image_reference = {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }


  depends_on = [
    module.avm_res_keyvault_vault
  ]
}