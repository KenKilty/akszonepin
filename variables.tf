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
  description = "The size of the VM for the AKS node pools."
  type        = string
  default     = "Standard_DS2_v2"
}

variable "node_count" {
  description = "(Optional) The number of nodes in the AKS node pool."
  type        = number
  default     = 1
}

variable "min_node_count" {
  description = "(Optional) The minimum number of nodes in the AKS node pool."
  type        = number
  default     = 1
}

variable "max_node_count" {
  description = "(Optional) The maximum number of nodes in the AKS node pool."
  type        = number
  default     = 4
}

variable "availability_zones" {
  description = "(Optional) The availability zones for the AKS node pool."
  type        = list(string)
  default     = ["1", "2"]
}

variable "agents_tags" {
  description = "(Optional) A mapping of tags to assign to the Node Pool."
  type        = map(string)
  default     = null
}

variable "container_registry_name" {
  description = "(Optional) The name of the container registry to use for the AKS cluster."
  type        = string
  default     = null
}

variable "enable_telemetry" {
  description = "(Optional) This variable controls whether or not telemetry is enabled for the module."
  type        = bool
  default     = true
}

variable "kubernetes_version" {
  description = "(Optional) Specify which Kubernetes release to use. Specify only minor version, such as '1.28'."
  type        = string
  default     = null
}

variable "lock" {
  description = "(Optional) Controls the Resource Lock configuration for this resource."
  type = object({
    kind = string
    name = optional(string, null)
  })
  default = null
}

variable "rbac_aad_admin_group_object_ids" {
  description = "(Optional) Object ID of groups with admin access."
  type        = list(string)
  default     = null
}

variable "rbac_aad_azure_rbac_enabled" {
  description = "(Optional) Is Role Based Access Control based on Azure AD enabled?"
  type        = bool
  default     = null
}

variable "rbac_aad_tenant_id" {
  description = "(Optional) The Tenant ID used for Azure Active Directory Application."
  type        = string
  default     = null
}

variable "tags" {
  description = "(Optional) Tags of the resource."
  type        = map(string)
  default     = null
}

variable "user_assigned_identity_name" {
  description = "(Optional) The name of the User Assigned Managed Identity to create."
  type        = string
  default     = null
}

variable "user_assigned_managed_identity_resource_ids" {
  description = "(Optional) Specifies a list of User Assigned Managed Identity resource IDs to be assigned to this resource."
  type        = set(string)
  default     = []
}

variable "min_nodes_per_zone" {
  description = "Minimum number of nodes per availability zone"
  type        = number
  default     = 3
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