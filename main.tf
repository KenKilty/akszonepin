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

resource "azurerm_resource_group" "aks" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.common_tags
}

resource "azurerm_container_registry" "aks" {
  name                = "acr${local.acr_suffix}"
  resource_group_name = azurerm_resource_group.aks.name
  location            = azurerm_resource_group.aks.location
  sku                 = "Basic"
  admin_enabled       = true
  tags                = local.common_tags

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.name
  location            = var.location
  resource_group_name = azurerm_resource_group.aks.name
  dns_prefix          = var.name
  kubernetes_version  = var.kubernetes_version

  # Disable AAD RBAC and enable local accounts
  azure_active_directory_role_based_access_control {
    managed = true
    azure_rbac_enabled = false
    admin_group_object_ids = []
    tenant_id = data.azurerm_client_config.current.tenant_id
  }

  # System node pool for system workloads
  default_node_pool {
    name                = "system"
    node_count          = var.system_node_count
    vm_size             = var.vm_size
    vnet_subnet_id      = azurerm_subnet.aks.id
    zones               = var.system_node_zones
    enable_auto_scaling = false
    max_pods            = 30
    os_disk_size_gb     = 30
    os_disk_type        = "Managed"
    node_labels = {
      "node-type" = "system"
    }
    tags = var.agents_tags
  }

  identity {
    type = "SystemAssigned"
  }

  # Ensure local accounts are enabled
  local_account_disabled = false

  # Enable Kubernetes RBAC
  role_based_access_control_enabled = true

  network_profile {
    network_plugin = "azure"
    network_policy = "azure"
    service_cidr   = "172.16.0.0/16"
    dns_service_ip = "172.16.0.10"
  }

  tags = var.tags
}

# PostgreSQL Zone 1 Node Pool
resource "azurerm_kubernetes_cluster_node_pool" "pgzone1" {
  name                  = "pgzone1"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  vm_size              = var.postgres_vm_size
  node_count           = var.postgres_zone1_node_count
  vnet_subnet_id       = azurerm_subnet.aks.id
  zones                = var.postgres_zone1_zones
  enable_auto_scaling  = false
  max_pods            = 30
  os_disk_size_gb     = 30
  os_disk_type        = "Managed"
  os_type             = "Linux"
  priority            = "Regular"
  node_labels = {
    "node-type" = "postgres"
    "zone"      = "1"
  }
  node_taints = ["node-type=postgres:NoSchedule"]
  tags        = var.agents_tags
}

# PostgreSQL Zone 2 Node Pool
resource "azurerm_kubernetes_cluster_node_pool" "pgzone2" {
  name                  = "pgzone2"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  vm_size              = var.postgres_vm_size
  node_count           = var.postgres_zone2_node_count
  vnet_subnet_id       = azurerm_subnet.aks.id
  zones                = var.postgres_zone2_zones
  enable_auto_scaling  = false
  max_pods            = 30
  os_disk_size_gb     = 30
  os_disk_type        = "Managed"
  os_type             = "Linux"
  priority            = "Regular"
  node_labels = {
    "node-type" = "postgres"
    "zone"      = "2"
  }
  node_taints = ["node-type=postgres:NoSchedule"]
  tags        = var.agents_tags
}

# Verify AKS cluster provisioning state
resource "null_resource" "verify_aks_provisioning" {
  depends_on = [azurerm_kubernetes_cluster.aks]

  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for AKS cluster to be fully provisioned..."
      while true; do
        PROVISIONING_STATE=$(az aks show --resource-group ${azurerm_resource_group.aks.name} --name ${azurerm_kubernetes_cluster.aks.name} --query provisioningState -o tsv)
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
  scope                = azurerm_container_registry.aks.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.aks.identity[0].principal_id
  depends_on           = [null_resource.verify_aks_provisioning]
}

# Role assignment for AKS to push to ACR
resource "azurerm_role_assignment" "aks_acr_push" {
  scope                = azurerm_container_registry.aks.id
  role_definition_name = "AcrPush"
  principal_id         = azurerm_kubernetes_cluster.aks.identity[0].principal_id
  depends_on           = [null_resource.verify_aks_provisioning]
}

# Role assignment for ACR to manage its own identity
resource "azurerm_role_assignment" "acr_identity" {
  scope                = azurerm_container_registry.aks.id
  role_definition_name = "Owner"
  principal_id         = azurerm_container_registry.aks.identity[0].principal_id
  depends_on           = [null_resource.verify_aks_provisioning]
}

data "azurerm_client_config" "current" {}

output "system_node_count" {
  description = "Number of nodes in the system node pool"
  value       = 2
}

output "postgres_zone1_node_count" {
  description = "Number of nodes in the PostgreSQL Zone 1 node pool"
  value       = 2
}

output "postgres_zone2_node_count" {
  description = "Number of nodes in the PostgreSQL Zone 2 node pool"
  value       = 1
}

output "cluster_name" {
  description = "Name of the AKS cluster"
  value       = azurerm_kubernetes_cluster.aks.name
}

output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.aks.name
}

output "resource_id" {
  description = "Resource ID of the AKS cluster"
  value       = azurerm_kubernetes_cluster.aks.id
}

output "resource_name" {
  description = "Name of the AKS cluster"
  value       = azurerm_kubernetes_cluster.aks.name
}

output "kube_config" {
  description = "Kubernetes config for the cluster"
  value       = azurerm_kubernetes_cluster.aks.kube_config_raw
  sensitive   = true
}

output "resource" {
  description = "Full AKS cluster resource"
  value       = azurerm_kubernetes_cluster.aks
  sensitive   = true
}

output "container_registry_id" {
  description = "Resource ID of the container registry"
  value       = azurerm_container_registry.aks.id
}

output "container_registry_name" {
  description = "Name of the container registry"
  value       = azurerm_container_registry.aks.name
}

output "container_registry_login_server" {
  description = "Login server for the container registry"
  value       = azurerm_container_registry.aks.login_server
}

output "container_registry_admin_username" {
  description = "Admin username for the container registry"
  value       = azurerm_container_registry.aks.admin_username
}

output "container_registry_admin_password" {
  description = "Admin password for the container registry"
  value       = azurerm_container_registry.aks.admin_password
  sensitive   = true
}

output "container_registry_encryption" {
  description = "Encryption settings for the container registry"
  value       = azurerm_container_registry.aks.encryption
}

output "container_registry_network_rule_set" {
  description = "Network rule set for the container registry"
  value       = azurerm_container_registry.aks.network_rule_set
}

output "container_registry_georeplications" {
  description = "Georeplications for the container registry"
  value       = azurerm_container_registry.aks.georeplications
}

output "container_registry_tags" {
  description = "Tags for the container registry"
  value       = azurerm_container_registry.aks.tags
}

output "acr_identity" {
  description = "Identity of the container registry"
  value       = azurerm_container_registry.aks.identity
}

output "acr_principal_id" {
  description = "Principal ID of the container registry"
  value       = azurerm_container_registry.aks.identity[0].principal_id
}

output "acr_tenant_id" {
  description = "Tenant ID of the container registry"
  value       = azurerm_container_registry.aks.identity[0].tenant_id
}

output "aks_identity" {
  description = "Identity of the AKS cluster"
  value       = azurerm_kubernetes_cluster.aks.identity
}

output "aks_principal_id" {
  description = "Principal ID of the AKS cluster"
  value       = azurerm_kubernetes_cluster.aks.identity[0].principal_id
}

output "aks_tenant_id" {
  description = "Tenant ID of the AKS cluster"
  value       = azurerm_kubernetes_cluster.aks.identity[0].tenant_id
}

resource "azurerm_kubernetes_cluster_extension" "container_storage" {
  name           = "microsoft-azurecontainerstorage"
  cluster_id     = azurerm_kubernetes_cluster.aks.id
  extension_type = "microsoft.azurecontainerstorage"

  configuration_settings = {
    "enable-azure-container-storage" = "ephemeralDisk"
    "storage-pool-option"           = "PremiumSSDv2"
    "ephemeral-disk-volume-type"    = "PersistentVolumeWithAnnotation"
  }
}

# Virtual Network and Subnet
resource "azurerm_virtual_network" "aks" {
  name                = "vnet-${var.name}"
  location            = var.location
  resource_group_name = azurerm_resource_group.aks.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "aks" {
  name                 = "subnet-${var.name}"
  resource_group_name  = azurerm_resource_group.aks.name
  virtual_network_name = azurerm_virtual_network.aks.name
  address_prefixes     = ["10.0.1.0/24"]
} 