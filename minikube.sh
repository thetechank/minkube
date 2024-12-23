
#!/bin/bash

# This script sets up a Minikube cluster. If the number of control plane nodes is less than 3,
# it uses a standard Minikube setup. For 3 or more control plane nodes, it sets up an HA cluster.
# Usage:
#   ./minikube.sh --profile <PROFILE_NAME> --control-plane <CONTROL_PLANE_COUNT> --worker <WORKER_COUNT> --cni <CNI_PLUGIN>

# Default values for parameters
PROFILE_NAME="minikube-ha"
CONTROL_PLANE_COUNT=3
WORKER_COUNT=2
CNI="cilium"

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --profile)
      PROFILE_NAME="$2"
      shift 2
      ;;
    --control-plane)
      CONTROL_PLANE_COUNT="$2"
      shift 2
      ;;
    --worker)
      WORKER_COUNT="$2"
      shift 2
      ;;
    --cni)
      CNI="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1"
      echo "Usage: $0 --profile <PROFILE_NAME> --control-plane <CONTROL_PLANE_COUNT> --worker <WORKER_COUNT> --cni <CNI_PLUGIN>"
      exit 1
      ;;
  esac
done

# Function to taint control plane nodes
function taint_control_planes() {
  echo "Tainting control plane nodes to make them unschedulable..."
  kubectl get nodes -o json | jq -r '.items[] | select(.metadata.labels["node-role.kubernetes.io/control-plane"] == "") | .metadata.name' | while read -r node; do
    kubectl taint nodes "$node" node-role.kubernetes.io/control-plane=:NoSchedule --overwrite
  done
}

if [ "$CONTROL_PLANE_COUNT" -lt 3 ]; then
  echo "Starting standard Minikube cluster with $CONTROL_PLANE_COUNT control plane node(s)..."
  minikube start \
    --profile "$PROFILE_NAME" \
    --nodes "$CONTROL_PLANE_COUNT" \
    --cni "$CNI"
else
  echo "Starting HA Minikube cluster with $CONTROL_PLANE_COUNT control plane nodes..."
  minikube start \
    --profile "$PROFILE_NAME" \
    --nodes "$CONTROL_PLANE_COUNT" \
    --ha \
    --cni "$CNI"
fi

if [ $? -ne 0 ]; then
  echo "Failed to start Minikube cluster. Exiting."
  exit 1
fi

# Export kubeconfig for kubectl access
export KUBECONFIG=$(minikube kubeconfig --profile "$PROFILE_NAME")

# Wait for the control plane nodes to be ready
echo "Waiting for control plane nodes to be ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=300s

# Taint control plane nodes
taint_control_planes

# Add worker nodes
for i in $(seq 1 "$WORKER_COUNT"); do
  echo "Adding worker node $i..."
  minikube node add --profile "$PROFILE_NAME" --worker || {
    echo "Failed to add worker node $i. Exiting."
    exit 1
  }
done

# Wait for worker nodes to be ready
echo "Waiting for worker nodes to be ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=300s

# Verify the cluster state
echo "Cluster nodes:"
kubectl get nodes -o wide
