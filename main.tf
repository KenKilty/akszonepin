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
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name
  dns_prefix          = var.name
  kubernetes_version  = "1.30"

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
    zones               = var.system_node_zones
    os_sku              = "AzureLinux"
    tags                = local.common_tags
    temporary_name_for_rotation = "systemtemp"
  }

  identity {
    type = "SystemAssigned"
  }

  # Ensure local accounts are enabled
  local_account_disabled = false

  # Enable Kubernetes RBAC
  role_based_access_control_enabled = true

  tags = local.common_tags
}

# PostgreSQL Zone 1 Node Pool
resource "azurerm_kubernetes_cluster_node_pool" "postgres_zone1" {
  name                  = "pgzone1"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  vm_size              = var.vm_size
  node_count           = var.postgres_zone1_node_count
  zones                = var.postgres_zone1_zones
  os_sku               = "AzureLinux"
  mode                 = "User"
  tags                 = local.common_tags

  upgrade_settings {
    max_surge                     = "25%"
    drain_timeout_in_minutes      = 30
    node_soak_duration_in_minutes = 5
  }
}

# PostgreSQL Zone 2 Node Pool
resource "azurerm_kubernetes_cluster_node_pool" "postgres_zone2" {
  name                  = "pgzone2"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  vm_size              = var.vm_size
  node_count           = var.postgres_zone2_node_count
  zones                = var.postgres_zone2_zones
  os_sku               = "AzureLinux"
  mode                 = "User"
  tags                 = local.common_tags

  upgrade_settings {
    max_surge                     = "25%"
    drain_timeout_in_minutes      = 30
    node_soak_duration_in_minutes = 5
  }
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

resource "azurerm_management_lock" "aks" {
  count      = var.lock != null ? 1 : 0
  name       = var.lock.name != null ? var.lock.name : "${var.lock.kind}-${var.name}"
  scope      = azurerm_kubernetes_cluster.aks.id
  lock_level = var.lock.kind
  depends_on = [null_resource.verify_aks_provisioning]
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