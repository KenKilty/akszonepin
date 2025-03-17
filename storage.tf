resource "kubernetes_storage_class" "acs_postgres" {
  depends_on = [azurerm_kubernetes_cluster.aks]

  metadata {
    name = "acs-sc-postgres"
  }

  storage_provisioner = "disk.csi.azure.com"
  reclaim_policy     = "Delete"
  volume_binding_mode = "WaitForFirstConsumer"
  allow_volume_expansion = true

  parameters = {
    skuName = "PremiumV2_LRS"
    DiskIOPSReadWrite = "80000"
    DiskMBpsReadWrite = "1200"
  }
} 