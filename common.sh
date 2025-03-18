#!/bin/bash

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

# Function to wait with progress indicator
wait_with_progress() {
    local resource=$1
    local condition=$2
    local timeout=$3
    local start_time=$(date +%s)
    local dots=""
    local last_status=""
    
    while true; do
        # Special handling for Pending state
        if [ "${condition}" = "Pending" ]; then
            local current_state=$(kubectl get ${resource} -o jsonpath='{.status.phase}' 2>/dev/null)
            if [ "${current_state}" = "Pending" ]; then
                echo -e "\n"
                return 0
            fi
        else
            # For pods, get detailed status
            if [[ "${resource}" == pod/* ]]; then
                local pod_status=$(kubectl get ${resource} -o jsonpath='{.status.phase}' 2>/dev/null)
                local pod_conditions=$(kubectl get ${resource} -o jsonpath='{.status.conditions[*].type}' 2>/dev/null)
                local pod_events=$(kubectl get events --field-selector involvedObject.name=${resource#pod/} --sort-by='.lastTimestamp' -o jsonpath='{.items[-1].reason}:{.items[-1].message}' 2>/dev/null)
                
                # Only print if status has changed
                if [ "${pod_status}" != "${last_status}" ]; then
                    echo -e "\n${YELLOW}Pod Status: ${pod_status}${NC}"
                    if [ ! -z "${pod_conditions}" ]; then
                        echo -e "${YELLOW}Conditions: ${pod_conditions}${NC}"
                    fi
                    if [ ! -z "${pod_events}" ]; then
                        echo -e "${YELLOW}Latest Event: ${pod_events}${NC}"
                    fi
                    last_status="${pod_status}"
                fi
            fi
            
            if kubectl wait --for=condition=${condition} ${resource} --timeout=5s 2>/dev/null; then
                echo -e "\n"
                return 0
            fi
        fi
        
        # Update progress indicator
        dots="${dots}."
        if [ ${#dots} -gt 3 ]; then
            dots=""
        fi
        echo -ne "\r${YELLOW}Waiting for ${resource} to be ${condition}${dots}${NC}"
        
        # Check if timeout exceeded
        local current_time=$(date +%s)
        if [ $((current_time - start_time)) -ge $timeout ]; then
            echo -e "\n"
            print_error "Timeout waiting for ${resource} to be ${condition}"
            
            # Check for errors
            local error_msg=$(kubectl get ${resource} -o jsonpath='{.status.conditions[?(@.type=="Failed")].message}')
            if [ ! -z "$error_msg" ]; then
                print_error "Error details: ${error_msg}"
            fi
            
            # For pods, show events on timeout
            if [[ "${resource}" == pod/* ]]; then
                print_error "Pod events:"
                kubectl get events --field-selector involvedObject.name=${resource#pod/} --sort-by='.lastTimestamp' | tail -n 5
            fi
            
            return 1
        fi
        
        sleep 2
    done
}

# Function to clean up resources with progress indicator
cleanup_resource() {
    local resource=$1
    local timeout=${2:-30}
    
    if kubectl get ${resource} &>/dev/null; then
        print_info "Found existing ${resource}, removing..."
        kubectl delete ${resource} --ignore-not-found
        
        local start_time=$(date +%s)
        local dots=""
        
        while true; do
            if ! kubectl get ${resource} &>/dev/null; then
                echo -e "\n"
                print_success "${resource} deleted successfully"
                return 0
            fi
            
            # Update progress indicator
            dots="${dots}."
            if [ ${#dots} -gt 3 ]; then
                dots=""
            fi
            echo -ne "\r${YELLOW}Waiting for ${resource} to be deleted${dots}${NC}"
            
            # Check if timeout exceeded
            local current_time=$(date +%s)
            if [ $((current_time - start_time)) -ge $timeout ]; then
                echo -e "\n"
                print_error "Timeout waiting for ${resource} to be deleted"
                return 1
            fi
            
            sleep 2
        done
    fi
    return 0
} 