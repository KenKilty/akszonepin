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
    print_info "Verifying node distribution..."
    
    # Get expected node counts from terraform output
    local expected_system_count
    local expected_zone1_count
    local expected_zone2_count
    
    if ! expected_system_count=$(terraform output system_node_count | tr -d '"'); then
        print_error "Failed to get system node count from terraform output"
        return 1
    fi
    
    if ! expected_zone1_count=$(terraform output postgres_zone1_node_count | tr -d '"'); then
        print_error "Failed to get zone1 node count from terraform output"
        return 1
    fi
    
    if ! expected_zone2_count=$(terraform output postgres_zone2_node_count | tr -d '"'); then
        print_error "Failed to get zone2 node count from terraform output"
        return 1
    fi
    
    print_info "Expected node counts:"
    echo "   System nodes: $expected_system_count"
    echo "   Postgres Zone 1 nodes: $expected_zone1_count"
    echo "   Postgres Zone 2 nodes: $expected_zone2_count"
    
    # Get current node distribution
    print_info "Current node distribution:"
    if ! kubectl get nodes -o wide | cat; then
        print_error "Failed to get node information"
        return 1
    fi
    
    # Count nodes per pool
    local system_count
    local zone1_postgres_count
    local zone2_postgres_count
    
    system_count=$(kubectl get nodes --no-headers -l agentpool=system | wc -l)
    zone1_postgres_count=$(kubectl get nodes --no-headers -l agentpool=pgzone1 | wc -l)
    zone2_postgres_count=$(kubectl get nodes --no-headers -l agentpool=pgzone2 | wc -l)
    
    print_info "Actual node counts:"
    echo "   System nodes: $system_count"
    echo "   Postgres Zone 1 nodes: $zone1_postgres_count"
    echo "   Postgres Zone 2 nodes: $zone2_postgres_count"
    
    # Verify node counts match
    if [ "$system_count" -eq "$expected_system_count" ] && \
       [ "$zone1_postgres_count" -eq "$expected_zone1_count" ] && \
       [ "$zone2_postgres_count" -eq "$expected_zone2_count" ]; then
        print_success "Node distribution matches expected configuration"
        return 0
    else
        print_error "Node distribution does not match expected configuration"
        return 1
    fi
}

# Function to verify node readiness
verify_node_readiness() {
    print_info "Verifying node readiness..."
    if ! kubectl wait --for=condition=ready nodes --all --timeout=300s; then
        print_error "Not all nodes are ready"
        return 1
    fi
    print_success "All nodes are ready"
    return 0
}

# Function to verify zone labels
verify_zone_labels() {
    print_info "Verifying zone labels..."
    local nodes_with_zones
    nodes_with_zones=$(kubectl get nodes -o custom-columns=NAME:.metadata.name,ZONE:.metadata.labels."topology\.kubernetes\.io/zone" --no-headers | grep -v "<none>")
    
    if [ -z "$nodes_with_zones" ]; then
        print_error "No nodes have zone labels"
        return 1
    fi
    
    print_info "Nodes with zone labels:"
    echo "$nodes_with_zones"
    print_success "Zone labels verified"
    return 0
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
    if ! verify_node_distribution; then
        exit 1
    fi
    
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