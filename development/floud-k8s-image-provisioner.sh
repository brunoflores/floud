#!/usr/bin/env bash

####################################################################
#                                                                  #
# This VM image is shared between the control plane and all nodes. #
#                                                                  #
####################################################################

# Start: package manager
sudo apt-get update
# nginx is used to proxy HTTP health checks
sudo apt-get install -y nginx
# Following list is used by the nodes
sudo apt-get -y install socat conntrack ipset
# End: package manager

# PKI Infrastructure
wget -q --show-progress --https-only --timestamping \
    "https://storage.googleapis.com/kubernetes-the-hard-way/cfssl/linux/cfssl" \
    "https://storage.googleapis.com/kubernetes-the-hard-way/cfssl/linux/cfssljson"
chmod +x cfssl cfssljson
sudo mv cfssl cfssljson /usr/local/bin/

# etcd
wget -q --show-progress --https-only --timestamping \
    "https://github.com/etcd-io/etcd/releases/download/v3.4.0/etcd-v3.4.0-linux-amd64.tar.gz"
tar -xvf etcd-v3.4.0-linux-amd64.tar.gz
sudo mv etcd-v3.4.0-linux-amd64/etcd* /usr/local/bin/
sudo mkdir -p /etc/etcd /var/lib/etcd

# Kubernetes Control Plane
sudo mkdir -p /etc/kubernetes/config
sudo mkdir -p /var/lib/kubernetes
wget -q --show-progress --https-only --timestamping \
    "https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kube-apiserver" \
    "https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kube-controller-manager" \
    "https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kube-scheduler" \
    "https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kubectl"
chmod +x kube-apiserver kube-controller-manager kube-scheduler kubectl
sudo mv kube-apiserver kube-controller-manager kube-scheduler kubectl /usr/local/bin/

# Kubernetes Nodes
wget -q --show-progress --https-only --timestamping \
    "https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.15.0/crictl-v1.15.0-linux-amd64.tar.gz" \
    "https://github.com/opencontainers/runc/releases/download/v1.0.0-rc8/runc.amd64" \
    "https://github.com/containernetworking/plugins/releases/download/v0.8.2/cni-plugins-linux-amd64-v0.8.2.tgz" \
    "https://github.com/containerd/containerd/releases/download/v1.2.9/containerd-1.2.9.linux-amd64.tar.gz" \
    "https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kubectl" \
    "https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kube-proxy" \
    "https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kubelet"
# Create installation dirs
sudo mkdir -p \
    /etc/cni/net.d \
    /opt/cni/bin \
    /var/lib/kubelet \
    /var/lib/kube-proxy \
    /var/lib/kubernetes \
    /var/run/kubernetes
# Install
mkdir containerd
tar -xvf crictl-v1.15.0-linux-amd64.tar.gz
tar -xvf containerd-1.2.9.linux-amd64.tar.gz -C containerd
sudo mv containerd/bin/* /bin/
sudo tar -xvf cni-plugins-linux-amd64-v0.8.2.tgz -C /opt/cni/bin/
sudo mv runc.amd64 runc
chmod +x crictl kubectl kube-proxy kubelet runc
sudo mv crictl kubectl kube-proxy kubelet runc /usr/local/bin/
sudo mkdir -p /etc/containerd
