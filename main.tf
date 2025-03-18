locals {
  # Generate a random string for ACR name uniqueness
  acr_suffix = random_string.acr_suffix.result

  # Common tags for all resources
  common_tags = merge(
    var.tags,
    {
      owner = var.owner
    }
  )
}

resource "random_string" "acr_suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "azurerm_resource_group" "aks_infrastructure" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.common_tags
}

resource "azurerm_container_registry" "aks_registry" {
  name                = "acr${local.acr_suffix}"
  resource_group_name = azurerm_resource_group.aks_infrastructure.name
  location            = azurerm_resource_group.aks_infrastructure.location
  sku                 = "Basic"
  admin_enabled       = true
  tags                = local.common_tags

  identity {
    type = "SystemAssigned"
  }
}

# Virtual Network and Subnet
resource "azurerm_virtual_network" "aks_network" {
  name                = "vnet-${var.name}-network"
  location            = var.location
  resource_group_name = azurerm_resource_group.aks_infrastructure.name
  address_space       = var.vnet_address_space
}

resource "azurerm_subnet" "aks_network" {
  name                 = "subnet-${var.name}-network"
  resource_group_name  = azurerm_resource_group.aks_infrastructure.name
  virtual_network_name = azurerm_virtual_network.aks_network.name
  address_prefixes     = var.subnet_address_prefixes
}

resource "azurerm_user_assigned_identity" "aks_identity" {
  name                = "identity-${var.name}"
  resource_group_name = azurerm_resource_group.aks_infrastructure.name
  location            = azurerm_resource_group.aks_infrastructure.location
  tags                = local.common_tags
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.name
  location            = var.location
  resource_group_name = azurerm_resource_group.aks_infrastructure.name
  dns_prefix          = var.name
  kubernetes_version  = var.kubernetes_version

  # System Node Pool
  default_node_pool {
    name                = "system"
    node_count          = var.system_node_count
    vm_size             = var.vm_size
    vnet_subnet_id      = azurerm_subnet.aks_network.id
    zones               = var.system_node_zones
    tags = var.agents_tags

    upgrade_settings {
      max_surge = var.node_pool_max_surge
    }
  }

  identity {
    type = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks_identity.id]
  }

  network_profile {
    network_plugin = "azure"
    network_policy = "azure"
    service_cidr   = "172.16.0.0/16"
    dns_service_ip = "172.16.0.10"
  }

  tags = var.tags

  depends_on = [
    azurerm_subnet.aks_network,
    azurerm_user_assigned_identity.aks_identity
  ]
}

# PostgreSQL Zone 1 Node Pool
resource "azurerm_kubernetes_cluster_node_pool" "postgreszone1" {
  name                  = "pgzone1"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  vm_size              = var.postgres_vm_size
  node_count           = var.postgreszone1_node_count
  zones                = var.postgreszone1_zones
  vnet_subnet_id       = azurerm_subnet.aks_network.id
  node_labels = {
    "node-type" = "postgres"
    "acstor.azure.com/io-engine" = "acstor"
  }
  node_taints = [
    "node-type=postgres:NoSchedule"
  ]

  upgrade_settings {
    max_surge = var.node_pool_max_surge
  }

  depends_on = [
    azurerm_kubernetes_cluster.aks,
    azurerm_subnet.aks_network
  ]
}

# PostgreSQL Zone 2 Node Pool
resource "azurerm_kubernetes_cluster_node_pool" "postgreszone2" {
  name                  = "pgzone2"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  vm_size              = var.postgres_vm_size
  node_count           = var.postgreszone2_node_count
  zones                = var.postgreszone2_zones
  vnet_subnet_id       = azurerm_subnet.aks_network.id
  node_labels = {
    "node-type" = "postgres"
    "acstor.azure.com/io-engine" = "acstor"
  }
  node_taints = [
    "node-type=postgres:NoSchedule"
  ]

  upgrade_settings {
    max_surge = var.node_pool_max_surge
  }

  depends_on = [
    azurerm_kubernetes_cluster.aks,
    azurerm_subnet.aks_network
  ]
}

# Azure Container Storage Extension for NVMe
resource "azurerm_kubernetes_cluster_extension" "container_storage_nvme" {
  name           = "microsoft-azurecontainerstorage"
  cluster_id     = azurerm_kubernetes_cluster.aks.id
  extension_type = "microsoft.azurecontainerstorage"

  configuration_settings = {
    "enable-azure-container-storage" = "ephemeralDisk"
    "storage-pool-option"           = "NVMe"
    "ephemeral-disk-volume-type"    = "PersistentVolumeWithAnnotation"
  }
  depends_on = [
    azurerm_kubernetes_cluster_node_pool.postgreszone1,
    azurerm_kubernetes_cluster_node_pool.postgreszone2,
    null_resource.verify_aks_provisioning
  ]
}

# Azure Container Storage Extension for Azure Disk
resource "azurerm_kubernetes_cluster_extension" "container_storage_azuredisk" {
  name           = "microsoft-azurecontainerstorage"
  cluster_id     = azurerm_kubernetes_cluster.aks.id
  extension_type = "microsoft.azurecontainerstorage"

  configuration_settings = {
    "enable-azure-container-storage" = "azureDisk"
  }
  depends_on = [
    azurerm_kubernetes_cluster_node_pool.postgreszone1,
    azurerm_kubernetes_cluster_node_pool.postgreszone2,
    null_resource.verify_aks_provisioning
  ]
}

# Storage Class for PostgreSQL Zone 1
resource "kubernetes_storage_class" "postgres_zone1_storage" {
  metadata {
    name = "postgres-zone1-storage"
  }
  storage_provisioner = "containerstorage.csi.azure.com"
  reclaim_policy     = "Delete"
  parameters = {
    "storagepool" = "postgres-zone1-pool"
    "skuName"     = "PremiumV2_LRS"
    "zone"        = var.postgreszone1_zones[0]
  }
  depends_on = [
    azurerm_kubernetes_cluster_extension.container_storage_nvme,
    azurerm_kubernetes_cluster_extension.container_storage_azuredisk
  ]
}

# Storage Class for PostgreSQL Zone 2
resource "kubernetes_storage_class" "postgres_zone2_storage" {
  metadata {
    name = "postgres-zone2-storage"
  }
  storage_provisioner = "containerstorage.csi.azure.com"
  reclaim_policy     = "Delete"
  parameters = {
    "storagepool" = "postgres-zone2-pool"
    "skuName"     = "PremiumV2_LRS"
    "zone"        = var.postgreszone2_zones[0]
  }
  depends_on = [
    azurerm_kubernetes_cluster_extension.container_storage_nvme,
    azurerm_kubernetes_cluster_extension.container_storage_azuredisk
  ]
}

# Verify AKS cluster provisioning state
resource "null_resource" "verify_aks_provisioning" {
  depends_on = [azurerm_kubernetes_cluster.aks]

  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for AKS cluster to be fully provisioned..."
      while true; do
        PROVISIONING_STATE=$(az aks show --resource-group ${azurerm_resource_group.aks_infrastructure.name} --name ${azurerm_kubernetes_cluster.aks.name} --query provisioningState -o tsv)
        echo "Current provisioning state: $PROVISIONING_STATE"
        if [ "$PROVISIONING_STATE" = "Succeeded" ]; then
          echo "AKS cluster is fully provisioned"
          break
        elif [ "$PROVISIONING_STATE" = "Failed" ]; then
          echo "AKS cluster provisioning failed"
          exit 1
        fi
        sleep 30
      done
    EOT
  }
}

# Role assignment for AKS to pull from ACR
resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                = azurerm_container_registry.aks_registry.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.aks_identity.principal_id
  depends_on           = [null_resource.verify_aks_provisioning]
}

# Role assignment for AKS to push to ACR
resource "azurerm_role_assignment" "aks_acr_push" {
  scope                = azurerm_container_registry.aks_registry.id
  role_definition_name = "AcrPush"
  principal_id         = azurerm_user_assigned_identity.aks_identity.principal_id
  depends_on           = [null_resource.verify_aks_provisioning]
}

# Role assignment for ACR to manage its own identity
resource "azurerm_role_assignment" "acr_identity" {
  scope                = azurerm_container_registry.aks_registry.id
  role_definition_name = "Owner"
  principal_id         = azurerm_container_registry.aks_registry.identity[0].principal_id
  depends_on           = [null_resource.verify_aks_provisioning]
}

data "azurerm_client_config" "current" {} 