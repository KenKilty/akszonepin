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

# Function to verify command exists
verify_command() {
    if ! command -v "$1" &> /dev/null; then
        print_error "$1 is not installed. Please install it first."
        exit 1
    fi
}

# Function to verify node distribution
verify_node_distribution() {
    echo "Verifying node distribution..."
    local zone1_count=$(kubectl get nodes -l node-type=postgres,zone=1 -o json | jq '.items | length')
    local zone2_count=$(kubectl get nodes -l node-type=postgres,zone=2 -o json | jq '.items | length')
    
    echo "Current node distribution:"
    echo "Zone 1 (pgzone1): $zone1_count nodes"
    echo "Zone 2 (pgzone2): $zone2_count nodes"
}

# Output storage class information
output_storage_info() {
    echo "Storage Class Information:"
    echo "Premium SSD v2 Storage Class: $(terraform output -raw storage_class_name)"
    echo "Storage Class Details:"
    kubectl get sc $(terraform output -raw storage_class_name) -o yaml
}

# Main script execution
main() {
    # Verify required commands
    print_header "Verifying Prerequisites"
    verify_command "terraform"
    verify_command "az"
    verify_command "kubectl"
    print_success "All prerequisites verified"
    
    # Initialize Terraform
    print_header "Initializing Terraform"
    if ! terraform init; then
        print_error "Terraform initialization failed"
        exit 1
    fi
    print_success "Terraform initialized"
    
    # Deploy Infrastructure
    print_header "Deploying AKS Cluster"
    if ! terraform apply -auto-approve; then
        print_error "Terraform apply failed"
        exit 1
    fi
    print_success "AKS cluster deployed"
    
    # Get AKS credentials
    print_header "Configuring kubectl"
    CLUSTER_NAME=$(terraform output -raw cluster_name)
    RESOURCE_GROUP=$(terraform output -raw resource_group_name)
    
    # Configure kubectl for the AKS cluster
    print_info "Configuring kubectl for AKS cluster..."
    if ! az aks get-credentials --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME" --admin --overwrite-existing; then
        print_error "Failed to get AKS credentials"
        exit 1
    fi
    
    # Verify node readiness
    if ! verify_node_readiness; then
        exit 1
    fi
    
    # Verify zone labels
    if ! verify_zone_labels; then
        exit 1
    fi
    
    # Verify node distribution
    verify_node_distribution
    output_storage_info
    
    print_success "All verifications completed successfully!"
}

# Run the main function
main

# Optional cleanup section
read -p "Do you want to destroy the infrastructure? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_header "Cleaning up infrastructure"
    terraform destroy -auto-approve
    print_success "Infrastructure destroyed"
fi 