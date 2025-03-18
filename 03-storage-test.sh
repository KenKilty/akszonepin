#!/bin/bash

# Exit on error
set -e

# Source common functions
source ./common.sh

# Function to clean up existing test resources
cleanup_existing() {
    print_info "Checking for existing test resources..."
    
    # List of resources to check and clean up
    local resources=(
        "pod/fio-pod-zone1"
        "pod/fio-pod-zone2"
        "pvc/fio-pvc-zone1"
        "pvc/fio-pvc-zone2"
    )
    
    for resource in "${resources[@]}"; do
        cleanup_resource "$resource" 30 || exit 1
    done
    
    print_success "Cleanup of existing resources completed"
}

# Function to create PVC
create_pvc() {
    local zone=$1
    local pvc_name="fio-pvc-zone${zone}"
    local storage_class="acstor-postgres-zone${zone}"
    
    print_info "Creating PVC ${pvc_name} with storage class ${storage_class}..."
    
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ${pvc_name}
  namespace: acstor
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: ${storage_class}
  resources:
    requests:
      storage: 100Gi
EOF
    
    # Wait for PVC to be created (not bound, since we're using WaitForFirstConsumer)
    print_info "Waiting for PVC ${pvc_name} to be created..."
    wait_with_progress "pvc/${pvc_name}" "Pending" 60 || exit 1
    print_success "PVC ${pvc_name} is created"
}

# Function to create FIO pod
create_fio_pod() {
    local zone=$1
    local pvc_name="fio-pvc-zone${zone}"
    local pod_name="fio-pod-zone${zone}"
    
    print_info "Creating FIO pod ${pod_name}..."
    
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: ${pod_name}
  namespace: acstor
spec:
  nodeSelector:
    topology.kubernetes.io/zone: westus3-${zone}
    agentpool: pgzone${zone}
  containers:
  - name: fio
    image: nixery.dev/shell/fio
    command: ["sleep"]
    args: ["infinity"]
    volumeMounts:
    - name: data
      mountPath: /volume
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: ${pvc_name}
EOF
    
    # Wait for pod to be ready
    print_info "Waiting for pod ${pod_name} to be ready..."
    wait_with_progress "pod/${pod_name}" "Ready" 60 || exit 1
    print_success "Pod ${pod_name} is ready"
    
    # Wait for PVC to be bound after pod is ready
    print_info "Waiting for PVC ${pvc_name} to be bound..."
    wait_with_progress "pvc/${pvc_name}" "Bound" 60 || exit 1
    print_success "PVC ${pvc_name} is bound"
}

# Function to run FIO test
run_fio_test() {
    local zone=$1
    local pod_name="fio-pod-zone${zone}"
    
    print_header "Running FIO test on Zone ${zone}"
    
    # Run FIO test and capture output
    kubectl exec -it ${pod_name} -- fio --name=benchtest \
        --size=800m \
        --filename=/volume/test \
        --direct=1 \
        --rw=randrw \
        --ioengine=libaio \
        --bs=4k \
        --iodepth=16 \
        --numjobs=8 \
        --time_based \
        --runtime=60 \
        --group_reporting \
        --output-format=json+ \
        --output=/volume/fio_results.json
    
    # Get the results
    print_info "FIO test results for Zone ${zone}:"
    kubectl exec -it ${pod_name} -- cat /volume/fio_results.json
}

# Function to clean up resources
cleanup() {
    local zone=$1
    local pod_name="fio-pod-zone${zone}"
    local pvc_name="fio-pvc-zone${zone}"
    
    print_info "Cleaning up resources for Zone ${zone}..."
    cleanup_resource "pod/${pod_name}" 30 || exit 1
    cleanup_resource "pvc/${pvc_name}" 30 || exit 1
}

# Main script execution
main() {
    print_header "Starting Storage Testing and Validation"

    # Step 1: Clean up any existing test resources
    cleanup_existing

    # Test Zone 1
    print_header "Testing Zone 1"
    create_pvc 1
    create_fio_pod 1
    run_fio_test 1
    cleanup 1

    # Test Zone 2
    print_header "Testing Zone 2"
    create_pvc 2
    create_fio_pod 2
    run_fio_test 2
    cleanup 2

    print_success "Storage testing and validation completed successfully"
}

# Run main function
main 