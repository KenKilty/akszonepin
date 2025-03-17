# AKS Zone-Aware PostgreSQL Cluster

This project deploys an Azure Kubernetes Service (AKS) cluster with zone-redundant node pools optimized for PostgreSQL workloads, using Premium SSD v2 storage.

## Architecture

```ascii
+------------------------------------------+
|              AKS Cluster                  |
|                                          |
|  +----------------+  +----------------+   |
|  |   Zone 1      |  |    Zone 2     |   |
|  |               |  |               |   |
|  | +-----------+ |  | +-----------+ |   |
|  | |  System   | |  | |  System   | |   |
|  | |   Node    | |  | |   Node    | |   |
|  | +-----------+ |  | +-----------+ |   |
|  |               |  |               |   |
|  | +-----------+ |  | +-----------+ |   |
|  | | Postgres  | |  | | Postgres  | |   |
|  | | Node (x2) | |  | | Node (x1) | |   |
|  | +-----------+ |  | +-----------+ |   |
|  |               |  |               |   |
|  +----------------+  +----------------+   |
|                                          |
|  +----------------------------------+    |
|  |      Premium SSD v2 Storage      |    |
|  |  +-------------+ +-------------+ |    |
|  |  | Zone 1 Pool | | Zone 2 Pool | |    |
|  |  | 80K IOPS   | | 80K IOPS    | |    |
|  |  | 1.2GB/s    | | 1.2GB/s     | |    |
|  |  +-------------+ +-------------+ |    |
|  +----------------------------------+    |
+------------------------------------------+
```

## Components

### Node Pools
1. **System Node Pool**
   - VM Size: Standard_D2s_v3
   - Nodes: 2 (distributed across zones 1 and 2)
   - Auto-scaling: 1-3 nodes
   - Purpose: System workloads and cluster services

2. **PostgreSQL Node Pools**
   - VM Size: Standard_D2s_v3 (smallest in Dsv3-series)
   - Zone 1: 2 nodes
   - Zone 2: 1 node
   - Auto-scaling: 1-3 nodes per zone
   - Node taints: "node-type=postgres:NoSchedule"
   - Labels: node-type=postgres, zone=1|2

### Storage Configuration
- **Storage Class**: Premium SSD v2
- **Performance**:
  - IOPS: 80,000 per disk
  - Throughput: 1,200 MB/s per disk
- **Features**:
  - Volume expansion enabled
  - WaitForFirstConsumer binding mode
  - Zone-redundant deployment

### Networking
- Virtual Network: 10.0.0.0/16
- AKS Subnet: 10.0.1.0/24
- Network Plugin: Azure CNI
- Network Policy: Azure

### Container Registry
- Basic SKU with admin access
- System-assigned managed identity
- Integrated with AKS using AcrPull and AcrPush roles

## Prerequisites
- Azure subscription
- Azure CLI (az)
- Terraform
- kubectl

## Deployment

1. Initialize Terraform:
```bash
terraform init
```

2. Review the configuration:
```bash
terraform plan
```

3. Deploy the infrastructure:
```bash
terraform apply
```

4. Run the verification script:
```bash
./run.sh
```

The script will:
- Verify prerequisites
- Deploy the AKS cluster
- Configure kubectl
- Verify node distribution
- Display storage class configuration

## Configuration

Key configuration values in `terraform.tfvars`:
```hcl
# Node Sizes
vm_size         = "Standard_D2s_v3"    # System nodes
postgres_vm_size = "Standard_D2s_v3"    # PostgreSQL nodes

# Node Counts
system_node_count        = 2
postgres_zone1_node_count = 2
postgres_zone2_node_count = 1

# Auto-scaling
min_node_count = 1
max_count = 3

# Kubernetes Version
kubernetes_version = "1.30"
```

## Cleanup

To destroy the infrastructure:
```bash
terraform destroy
```

## Production Considerations
1. Enable Azure AD integration for RBAC
2. Configure network policies
3. Implement proper backup strategies
4. Monitor node and storage performance
5. Consider using availability zones 1, 2, and 3 for better redundancy
6. Implement proper resource requests and limits
7. Configure cluster autoscaling thresholds appropriately

## Tags and Labels
- Environment-specific tags for resource management
- Workload-specific tags for node pools
- Zone labels for topology awareness
- Node type labels for workload placement

## License
Apache License 2.0 