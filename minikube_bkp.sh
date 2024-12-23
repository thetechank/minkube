
#!/bin/bash

# Name of the Minikube profile
PROFILE_NAME="minikube-ha"
# Number of control plane nodes and worker nodes to add
CONTROL_PLANE_COUNT=3
WORKER_COUNT=2
CNI=cilium

# Function to taint control plane nodes
function taint_control_planes() {
  echo "Tainting control plane nodes to make them unschedulable..."
  kubectl get nodes -o json | jq -r '.items[] | select(.metadata.labels["node-role.kubernetes.io/control-plane"] == "") | .metadata.name' | while read -r node; do
    kubectl taint nodes "$node" node-role.kubernetes.io/control-plane=:NoSchedule --overwrite
  done
}

# Start Minikube with HA setup
minikube start \
  --profile "$PROFILE_NAME" \
  --nodes "$CONTROL_PLANE_COUNT" \
  --ha \
  --cni "$CNI"

if [ $? -ne 0 ]; then
  echo "Failed to start Minikube cluster with HA setup. Exiting."
  exit 1
fi

# Export kubeconfig for kubectl access
# export KUBECONFIG=$(minikube kubeconfig --profile "$PROFILE_NAME")

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
