#!/bin/bash

# Exit on error
set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print section headers
print_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}\n"
}

# Function to print success messages
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Function to print error messages
print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Function to print info messages
print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

# Function to verify Azure Container Storage
verify_acstor() {
    print_header "Verifying Azure Container Storage Setup"
    
    # Get cluster details
    CLUSTER_NAME=$(terraform output -raw cluster_name)
    RESOURCE_GROUP=$(terraform output -raw resource_group_name)
    
    # 1. Verify Azure Container Storage Extension
    print_info "Checking Azure Container Storage Extension..."
    extension_state=$(az aks extension show \
        --cluster-name "$CLUSTER_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --name microsoft-azurecontainerstorage \
        --cluster-type managedClusters \
        --query provisioningState -o tsv)
    
    if [ "$extension_state" != "Succeeded" ]; then
        print_error "Azure Container Storage extension is not in Succeeded state (current state: $extension_state)"
        return 1
    fi
    print_success "Azure Container Storage extension is in Succeeded state"

    # 2. Verify acstor namespace and pods
    print_info "Checking acstor namespace and pods..."
    if ! kubectl get namespace acstor &>/dev/null; then
        print_error "acstor namespace not found"
        return 1
    fi
    print_success "acstor namespace exists"

    # Check core pods
    core_pods=(
        "microsoft-azurecontainerstorage-agent-core"
        "microsoft-azurecontainerstorage-csi-controller"
        "microsoft-azurecontainerstorage-azuresan-csi-driver"
        "microsoft-azurecontainerstorage-etcd-operator"
    )

    for pod in "${core_pods[@]}"; do
        print_info "Checking $pod..."
        if ! kubectl get pods -n acstor -l app="$pod" -o name &>/dev/null; then
            print_error "$pod not found"
            return 1
        fi
        
        # Check pod readiness
        ready_pods=$(kubectl get pods -n acstor -l app="$pod" -o jsonpath='{.items[*].status.containerStatuses[*].ready}' | tr ' ' '\n' | grep -c "true" || echo "0")
        total_pods=$(kubectl get pods -n acstor -l app="$pod" -o jsonpath='{.items[*].status.containerStatuses[*].ready}' | tr ' ' '\n' | wc -l || echo "0")
        
        if [ "$ready_pods" -eq "$total_pods" ] && [ "$total_pods" -gt 0 ]; then
            print_success "$pod is ready ($ready_pods/$total_pods pods)"
        else
            print_error "$pod is not ready ($ready_pods/$total_pods pods)"
            return 1
        fi
    done

    # 3. Verify Storage Classes
    print_info "Checking Storage Classes..."
    expected_storage_classes=("acstor-postgres-zone1" "acstor-postgres-zone2")
    
    for sc in "${expected_storage_classes[@]}"; do
        if ! kubectl get storageclass "$sc" &>/dev/null; then
            print_error "Storage class $sc not found"
            return 1
        fi
        
        # Verify storage class parameters
        sc_yaml=$(kubectl get storageclass "$sc" -o yaml)
        if ! echo "$sc_yaml" | grep -q "storage-provisioner: disk.csi.azure.com"; then
            print_error "Storage class $sc has incorrect provisioner"
            return 1
        fi
        
        if ! echo "$sc_yaml" | grep -q "volumeBindingMode: WaitForFirstConsumer"; then
            print_error "Storage class $sc has incorrect volume binding mode"
            return 1
        fi
        
        print_success "Storage class $sc is correctly configured"
    done

    # 4. Verify Node Labels for ACStor
    print_info "Checking Node Labels for ACStor..."
    acstor_nodes=$(kubectl get nodes -l acstor.azure.com/io-engine=acstor -o name | wc -l)
    if [ "$acstor_nodes" -lt 3 ]; then
        print_error "Insufficient nodes with ACStor label (found: $acstor_nodes, expected: >= 3)"
        return 1
    fi
    print_success "Found $acstor_nodes nodes with ACStor label"

    # 5. Verify CRDs
    print_info "Checking Custom Resource Definitions..."
    required_crds=(
        "storagepools.acstor.azure.com"
        "storageclassclaims.acstor.azure.com"
    )
    
    for crd in "${required_crds[@]}"; do
        if ! kubectl get crd "$crd" &>/dev/null; then
            print_error "CRD $crd not found"
            return 1
        fi
        print_success "CRD $crd exists"
    done

    # 6. Verify CSI Drivers
    print_info "Checking CSI Drivers..."
    if ! kubectl get csidrivers | grep -q "disk.csi.azure.com"; then
        print_error "Azure Disk CSI driver not found"
        return 1
    fi
    print_success "Azure Disk CSI driver is installed"

    print_success "Azure Container Storage verification completed successfully"
    return 0
}

# Main script execution
main() {
    print_header "Starting Azure Container Storage Deployment and Verification"

    # Step 1: Deploy ACStor extension with Terraform
    print_info "Deploying Azure Container Storage extension..."
    terraform apply -target=azurerm_kubernetes_cluster_extension.container_storage -auto-approve

    # Step 2: Deploy storage classes with Terraform
    print_info "Deploying storage classes..."
    terraform apply -target=kubernetes_storage_class.acstor_postgres_zone1 -target=kubernetes_storage_class.acstor_postgres_zone2 -auto-approve

    # Step 3: Verify ACStor setup
    verify_acstor || exit 1

    print_success "Azure Container Storage deployment and verification completed successfully"
}

# Run main function
main 