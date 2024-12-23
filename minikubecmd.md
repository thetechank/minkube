# Minikube Commands

## Create HA Cluster

When minikube creates HA Cluster it does not mark master node as unschedulable.
Hence add taints and then add worker node

[Multinode](https://minikube.sigs.k8s.io/docs/tutorials/multi_node/)
[HA](https://minikube.sigs.k8s.io/docs/tutorials/multi_control_plane_ha_clusters/)

```shell
minikube start --ha -p testHA
kubectl taint nodes minikube node-role.kubernetes.io/master:NoSchedule

minikube node add --worker
```

Use the [shell file](./minikube.sh)

```shell
./minikube.sh --profile my-cluster --control-plane 5 --worker 3 --cni flannel
```

Basic commands for management

```shell
# list profiles
minikube profile list

# set profile
minikube profile <profilename>

#status
minikube -p ha1 status

#operate
minikibe start -p ha1

minikube stop -p v1.16

minikube delete -p v1.16

```
