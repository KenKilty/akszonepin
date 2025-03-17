output "storage_class_name" {
  description = "The name of the storage class created by Azure Container Storage"
  value       = "acstor-${kubernetes_storage_class.acs_postgres.metadata[0].name}"
} 