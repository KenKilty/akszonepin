# AKS Zone-Pinned PostgreSQL Deployment

This project deploys an Azure Kubernetes Service (AKS) cluster with zone-pinned PostgreSQL nodes using Azure Container Storage for persistent storage.

## Architecture

The deployment consists of:

1. **AKS Cluster**
   - System node pool (3 nodes) in zones 1 and 2
   - PostgreSQL node pool (3 nodes) in zone 1
   - PostgreSQL node pool (3 nodes) in zone 2
   - Azure Container Storage for persistent storage

2. **Node Pools**
   - System nodes: Standard_D4s_v5 (4 vCPUs)
   - PostgreSQL nodes: Standard_D4s_v5 (4 vCPUs)
   - All nodes support premium storage

3. **Storage**
   - Azure Container Storage for persistent volumes
   - PostgreSQL nodes labeled with `acstor.azure.com/io-engine:acstor`
   - Minimum 3 nodes per pool required for Azure Container Storage

## Prerequisites

- Azure CLI (version 2.35.0 or later)
- Terraform (version 1.0.0 or later)
- kubectl
- Azure subscription with permissions to create AKS clusters
- Azure Container Storage supported region (westus3)

## Deployment Steps

1. **Initialize Terraform**
   ```bash
   terraform init
   ```

2. **Review Configuration**
   - Check `terraform.tfvars` for your desired settings
   - Ensure VM sizes meet Azure Container Storage requirements (minimum 4 vCPUs)
   - Verify node counts (minimum 3 nodes per pool)

3. **Deploy Infrastructure**
   ```bash
   ./run.sh
   ```

4. **Verify Deployment**
   - Check node readiness
   - Verify zone labels
   - Monitor Azure Container Storage pods

## Node Pool Configuration

### System Node Pool
- Size: Standard_D4s_v5
- Count: 3 nodes
- Zones: 1, 2
- Purpose: System workloads and Azure Container Storage control plane

### PostgreSQL Node Pool (Zone 1)
- Size: Standard_D4s_v5
- Count: 3 nodes
- Zone: 1
- Purpose: PostgreSQL primary nodes
- Labels: `acstor.azure.com/io-engine:acstor`

### PostgreSQL Node Pool (Zone 2)
- Size: Standard_D4s_v5
- Count: 3 nodes
- Zone: 2
- Purpose: PostgreSQL secondary nodes
- Labels: `acstor.azure.com/io-engine:acstor`

## Storage Configuration

Azure Container Storage is configured with:
- Data plane components on PostgreSQL nodes
- Control plane components on system nodes
- Minimum 3 nodes per pool for high availability
- Premium storage support via Standard_D4s_v5 VMs

## Cleanup

To remove all resources:
```bash
terraform destroy -auto-approve
```

## Notes

- Azure Container Storage requires minimum 4 vCPUs per VM
- Each node pool must have at least 3 nodes for Azure Container Storage
- PostgreSQL nodes are tainted to prevent other workloads from scheduling
- System nodes are spread across zones 1 and 2 for high availability

## Configuration

Key configuration values in `terraform.tfvars`:
```hcl
# Node Sizes
vm_size         = "Standard_D4s_v5"    # System nodes
postgres_vm_size = "Standard_D4s_v5"    # PostgreSQL nodes

# Node Counts
system_node_count        = 3
postgres_zone1_node_count = 3
postgres_zone2_node_count = 3

# Auto-scaling
min_node_count = 3
max_count = 3

# Kubernetes Version
kubernetes_version = "1.30"
```

## Tags and Labels
- Environment-specific tags for resource management
- Workload-specific tags for node pools
- Zone labels for topology awareness
- Node type labels for workload placement

## License
Apache License 2.0 