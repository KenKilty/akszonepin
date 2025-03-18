# Cluster Configuration
variable "name" {
  description = "Name of the AKS cluster"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region where resources will be created"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version for the AKS cluster"
  type        = string
}

# System Node Pool Configuration
variable "vm_size" {
  description = "VM size for the system node pool"
  type        = string
}

variable "system_node_count" {
  description = "Number of nodes in the system node pool"
  type        = number
}

variable "system_node_zones" {
  description = "Availability zones for the system node pool"
  type        = list(string)
}

# PostgreSQL Zone 1 Node Pool Configuration
variable "postgres_vm_size" {
  description = "VM size for PostgreSQL node pools"
  type        = string
}

variable "postgreszone1_node_count" {
  description = "Number of nodes in PostgreSQL Zone 1 node pool"
  type        = number
}

variable "postgreszone1_zones" {
  description = "Availability zones for PostgreSQL Zone 1 node pool"
  type        = list(string)
}

# PostgreSQL Zone 2 Node Pool Configuration
variable "postgreszone2_node_count" {
  description = "Number of nodes in PostgreSQL Zone 2 node pool"
  type        = number
}

variable "postgreszone2_zones" {
  description = "Availability zones for PostgreSQL Zone 2 node pool"
  type        = list(string)
}

# Resource Tags and Metadata
variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
}

variable "agents_tags" {
  description = "Tags to apply to agent nodes"
  type        = map(string)
}

variable "owner" {
  description = "Owner of the resources"
  type        = string
}

variable "vnet_address_space" {
  description = "Address space for the virtual network"
  type        = list(string)
}

variable "subnet_address_prefixes" {
  description = "Address prefixes for the subnet"
  type        = list(string)
}

# Node Pool Upgrade Settings
variable "node_pool_max_surge" {
  description = "Maximum number of nodes that can be created above the desired count during an upgrade"
  type        = string
}

variable "postgres_storage_size" {
  description = "Size of the storage pool for PostgreSQL nodes"
  type        = string
} 