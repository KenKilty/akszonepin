variable "location" {
  description = "The Azure region where the resources should be deployed."
  type        = string
}

variable "name" {
  description = "The name for the AKS resources created in the specified Azure Resource Group."
  type        = string
}

variable "resource_group_name" {
  description = "The resource group where the resources will be deployed."
  type        = string
}

variable "owner" {
  description = "The owner tag value for all resources."
  type        = string
}

variable "vm_size" {
  description = "The size of the VM for the system node pool."
  type        = string
  default     = "Standard_D2s_v3"
}

variable "min_node_count" {
  description = "The minimum number of nodes in the AKS node pools."
  type        = number
  default     = 1
}

variable "max_node_count" {
  description = "The maximum number of nodes in the AKS node pools."
  type        = number
  default     = 3
}

variable "agents_tags" {
  description = "A mapping of tags to assign to the Node Pools."
  type        = map(string)
  default     = null
}

variable "enable_telemetry" {
  description = "Controls whether or not telemetry is enabled for the module."
  type        = bool
  default     = true
}

variable "kubernetes_version" {
  description = "Specify which Kubernetes release to use. Specify only minor version, such as '1.28'."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to all resources."
  type        = map(string)
  default     = null
}

# System Node Pool Configuration
variable "system_node_count" {
  description = "Number of nodes in the system node pool"
  type        = number
  default     = 2
}

variable "system_node_zones" {
  description = "Availability zones for the system node pool"
  type        = list(string)
  default     = ["1", "2"]
}

# PostgreSQL Node Pool Configuration
variable "postgres_zone1_node_count" {
  description = "Number of nodes in the PostgreSQL Zone 1 node pool"
  type        = number
  default     = 2
}

variable "postgres_zone2_node_count" {
  description = "Number of nodes in the PostgreSQL Zone 2 node pool"
  type        = number
  default     = 1
}

variable "postgres_zone1_zones" {
  description = "Availability zones for the PostgreSQL Zone 1 node pool"
  type        = list(string)
  default     = ["1"]
}

variable "postgres_zone2_zones" {
  description = "Availability zones for the PostgreSQL Zone 2 node pool"
  type        = list(string)
  default     = ["2"]
}

variable "postgres_vm_size" {
  description = "The size of the PostgreSQL VMs"
  type        = string
  default     = "Standard_D2s_v3"
} 