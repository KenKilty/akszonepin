#!/bin/bash

# Exit on error
set -e

# Source common functions
source ./common.sh

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

# Function to get vCPU count for a VM size
get_vcpu_count() {
    local vm_size=$1
    local location=$2
    local vcpu_count=$(az vm list-sizes --location "$location" --query "[?name=='$vm_size'].numberOfCores | [0]" -o tsv)
    echo "$vcpu_count"
}

# Function to verify node readiness
verify_node_readiness() {
    print_info "Waiting for all nodes to be ready..."
    wait_with_progress "nodes" "Ready" 300 || return 1
    print_success "All nodes are ready"
    return 0
}

# Function to verify zone labels
verify_zone_labels() {
    print_info "Verifying zone labels..."
    local zone1_nodes=$(kubectl get nodes -l node-type=postgres -o jsonpath='{.items[?(@.metadata.labels.topology\.kubernetes\.io/zone=="westus3-1")].metadata.name}' | wc -w)
    local zone2_nodes=$(kubectl get nodes -l node-type=postgres -o jsonpath='{.items[?(@.metadata.labels.topology\.kubernetes\.io/zone=="westus3-2")].metadata.name}' | wc -w)
    
    if [ "$zone1_nodes" -gt 0 ] && [ "$zone2_nodes" -gt 0 ]; then
        print_success "Zone labels verified"
        return 0
    else
        print_error "Missing zone labels"
        return 1
    fi
}

# Function to verify node distribution
verify_node_distribution() {
    print_info "Verifying node distribution..."
    local zone1_count=$(kubectl get nodes -l node-type=postgres -o jsonpath='{.items[?(@.metadata.labels.topology\.kubernetes\.io/zone=="westus3-1")].metadata.name}' | wc -w)
    local zone2_count=$(kubectl get nodes -l node-type=postgres -o jsonpath='{.items[?(@.metadata.labels.topology\.kubernetes\.io/zone=="westus3-2")].metadata.name}' | wc -w)
    
    echo "Current node distribution:"
    echo "Zone 1 (pgzone1): $zone1_count nodes"
    echo "Zone 2 (pgzone2): $zone2_count nodes"
}

# Function to get cluster credentials
get_cluster_credentials() {
    print_info "Getting cluster credentials..."
    local resource_group=$(terraform output -raw resource_group_name)
    local cluster_name=$(terraform output -raw kubernetes_cluster_name)
    az aks get-credentials --resource-group "$resource_group" --name "$cluster_name" --overwrite-existing
}

# Function to verify infrastructure requirements
verify_infrastructure_requirements() {
    print_header "Verifying Infrastructure Requirements"
    
    # Get location from terraform.tfvars
    local location=$(grep "^[[:space:]]*location[[:space:]]*=" terraform.tfvars | cut -d"=" -f2 | cut -d"#" -f1 | tr -d " \"")
    print_info "Location: $location"
    
    # Get VM sizes and check vCPUs
    local system_vm_size=$(grep "^[[:space:]]*vm_size[[:space:]]*=" terraform.tfvars | cut -d"=" -f2 | cut -d"#" -f1 | tr -d " \"")
    local postgres_vm_size=$(grep "^[[:space:]]*postgres_vm_size[[:space:]]*=" terraform.tfvars | cut -d"=" -f2 | cut -d"#" -f1 | tr -d " \"")
    
    print_info "Checking VM sizes..."
    local system_vcpu_count=$(get_vcpu_count "$system_vm_size" "$location")
    local postgres_vcpu_count=$(get_vcpu_count "$postgres_vm_size" "$location")
    
    echo "System nodes: $system_vm_size ($system_vcpu_count vCPUs)"
    echo "PostgreSQL nodes: $postgres_vm_size ($postgres_vcpu_count vCPUs)"
    
    if [ "$system_vcpu_count" -ge 4 ] && [ "$postgres_vcpu_count" -ge 4 ]; then
        print_success "VM sizes meet requirements (minimum 4 vCPUs)"
    else
        print_error "VM sizes do not meet requirements. Need minimum 4 vCPUs"
        return 1
    fi

    # Check total eligible node count using Terraform outputs
    local pgzone1_count=$(terraform output -raw postgres_zone1_node_count)
    local pgzone2_count=$(terraform output -raw postgres_zone2_node_count)
    local total_nodes=$((pgzone1_count + pgzone2_count))
    
    echo "Total PostgreSQL nodes: $total_nodes"
    if [ "$total_nodes" -ge 3 ]; then
        print_success "Node count meets requirements (minimum 3 nodes)"
    else
        print_error "Node count does not meet requirements. Need minimum 3 nodes"
        return 1
    fi
}

# Main script execution
main() {
    print_header "Starting Infrastructure Deployment and Verification"

    # Step 1: Deploy infrastructure with Terraform
    print_info "Deploying infrastructure with Terraform..."
    terraform init
    terraform apply -auto-approve

    # Step 2: Get cluster credentials
    get_cluster_credentials

    # Step 3: Wait for nodes to be ready
    verify_node_readiness || exit 1

    # Step 4: Verify zone labels
    verify_zone_labels || exit 1

    # Step 5: Verify node distribution
    verify_node_distribution

    # Step 6: Verify infrastructure requirements
    verify_infrastructure_requirements || exit 1

    print_success "Infrastructure deployment and verification completed successfully"
}

# Run main function
main 