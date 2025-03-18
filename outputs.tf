# Storage outputs
output "storage_class_name" {
  description = "Name of the storage class for PostgreSQL"
  value       = "acs-sc-postgres-zone1"
}

# Node pool outputs
output "system_node_count" {
  description = "Number of nodes in the system node pool"
  value       = var.system_node_count
}

output "postgres_zone1_node_count" {
  description = "Number of nodes in PostgreSQL Zone 1"
  value       = var.postgreszone1_node_count
}

output "postgres_zone2_node_count" {
  description = "Number of nodes in PostgreSQL Zone 2"
  value       = var.postgreszone2_node_count
}

# AKS cluster outputs
output "resource_group_name" {
  description = "The name of the resource group"
  value       = azurerm_resource_group.aks_infrastructure.name
}

output "kubernetes_cluster_name" {
  description = "The name of the AKS cluster"
  value       = azurerm_kubernetes_cluster.aks.name
}

output "kubernetes_cluster_id" {
  description = "The ID of the AKS cluster"
  value       = azurerm_kubernetes_cluster.aks.id
}

output "kubernetes_cluster_host" {
  description = "The Kubernetes cluster server host"
  value       = azurerm_kubernetes_cluster.aks.kube_config[0].host
  sensitive   = true
}

output "kubernetes_cluster_username" {
  description = "The Kubernetes cluster admin username"
  value       = azurerm_kubernetes_cluster.aks.kube_config[0].username
  sensitive   = true
}

output "kubernetes_cluster_password" {
  description = "The Kubernetes cluster admin password"
  value       = azurerm_kubernetes_cluster.aks.kube_config[0].password
  sensitive   = true
}

output "kubernetes_cluster_ca_certificate" {
  description = "The Kubernetes cluster CA certificate"
  value       = azurerm_kubernetes_cluster.aks.kube_config[0].cluster_ca_certificate
  sensitive   = true
}

output "kubernetes_cluster_client_key" {
  description = "The Kubernetes cluster client key"
  value       = azurerm_kubernetes_cluster.aks.kube_config[0].client_key
  sensitive   = true
}

output "kubernetes_cluster_client_certificate" {
  description = "The Kubernetes cluster client certificate"
  value       = azurerm_kubernetes_cluster.aks.kube_config[0].client_certificate
  sensitive   = true
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

# Container registry outputs
output "container_registry_id" {
  description = "The ID of the container registry"
  value       = azurerm_container_registry.aks_registry.id
}

output "container_registry_name" {
  description = "The name of the container registry"
  value       = azurerm_container_registry.aks_registry.name
}

output "container_registry_admin_username" {
  description = "The admin username of the container registry"
  value       = azurerm_container_registry.aks_registry.admin_username
}

output "container_registry_admin_password" {
  description = "The admin password of the container registry"
  value       = azurerm_container_registry.aks_registry.admin_password
  sensitive   = true
}

output "acr_login_server" {
  description = "The login server of the container registry"
  value       = azurerm_container_registry.aks_registry.login_server
}

# Identity outputs
output "aks_identity" {
  description = "Identity of the AKS cluster"
  value       = azurerm_kubernetes_cluster.aks.identity
}

output "aks_identity_principal_id" {
  description = "The principal ID of the AKS cluster's managed identity"
  value       = azurerm_user_assigned_identity.aks_identity.principal_id
}

output "aks_identity_client_id" {
  description = "The client ID of the AKS cluster's managed identity"
  value       = azurerm_user_assigned_identity.aks_identity.client_id
}

output "acr_identity" {
  description = "The identity of the container registry"
  value       = azurerm_container_registry.aks_registry.identity
}

output "acr_tenant_id" {
  description = "Tenant ID of the container registry"
  value       = azurerm_container_registry.aks_registry.identity[0].tenant_id
}

output "vnet_name" {
  description = "The name of the virtual network"
  value       = azurerm_virtual_network.aks_network.name
}

output "subnet_name" {
  description = "The name of the subnet"
  value       = azurerm_subnet.aks_network.name
}

output "subnet_id" {
  description = "The ID of the subnet"
  value       = azurerm_subnet.aks_network.id
} 