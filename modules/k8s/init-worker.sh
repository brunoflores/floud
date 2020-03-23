#!/usr/bin/env bash

KUBE_LIB_DIR=/var/lib/kubernetes
KUBELET_LIB_DIR=/var/lib/kubelet
ATTRIBUTES_API="http://metadata.google.internal/computeMetadata/v1/instance/attributes"
BOOTSTRAP_TOKEN=$(curl -s -H "Metadata-Flavor: Google" "${ATTRIBUTES_API}/bootstrap-token")
KUBE_API=$(curl -s -H "Metadata-Flavor: Google" "${ATTRIBUTES_API}/kube-api")
POD_CIDR=$(curl -s -H "Metadata-Flavor: Google" \
    "http://metadata.google.internal/computeMetadata/v1/instance/attributes/pod-cidr")

# Disable swap
sudo swapoff -a

echo "apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority: ${KUBE_LIB_DIR}/ca.pem
    server: https://${KUBE_API}:6443
  name: bootstrap
contexts:
- context:
    cluster: bootstrap
    user: kubelet-bootstrap
  name: bootstrap
current-context: bootstrap
preferences: {}
users:
- name: kubelet-bootstrap
  user:
    token: ${BOOTSTRAP_TOKEN}" > $KUBELET_LIB_DIR/bootstrap-kubeconfig

# Create the `bridge` network configuration file
cat <<EOF | sudo tee /etc/cni/net.d/10-bridge.conf
{
    "cniVersion": "0.3.1",
    "name": "bridge",
    "type": "bridge",
    "bridge": "cnio0",
    "isGateway": true,
    "ipMasq": true,
    "ipam": {
        "type": "host-local",
        "ranges": [
          [{"subnet": "${POD_CIDR}"}]
        ],
        "routes": [{"dst": "0.0.0.0/0"}]
    }
}
EOF

# Create the `loopback` network configuration file
cat <<EOF | sudo tee /etc/cni/net.d/99-loopback.conf
{
    "cniVersion": "0.3.1",
    "name": "lo",
    "type": "loopback"
}
EOF

# Configure containerd
sudo mkdir -p /etc/containerd
cat << EOF | sudo tee /etc/containerd/config.toml
[plugins]
  [plugins.cri.containerd]
    snapshotter = "overlayfs"
    [plugins.cri.containerd.default_runtime]
      runtime_type = "io.containerd.runtime.v1.linux"
      runtime_engine = "/usr/local/bin/runc"
      runtime_root = ""
EOF
cat <<EOF | sudo tee /etc/systemd/system/containerd.service
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target

[Service]
ExecStartPre=/sbin/modprobe overlay
ExecStart=/bin/containerd
Restart=always
RestartSec=5
Delegate=yes
KillMode=process
OOMScoreAdjust=-999
LimitNOFILE=1048576
LimitNPROC=infinity
LimitCORE=infinity

[Install]
WantedBy=multi-user.target
EOF

# Configure the Kubelet
cat <<EOF | sudo tee /var/lib/kubelet/kubelet-config.yaml
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
  x509:
    clientCAFile: "${KUBE_LIB_DIR}/ca.pem"
authorization:
  mode: Webhook
clusterDomain: "cluster.local"
clusterDNS:
  - "10.32.0.10"
podCIDR: "${POD_CIDR}"
resolvConf: "/run/systemd/resolve/resolv.conf"
runtimeRequestTimeout: "15m"
serverTLSBootstrap: true
EOF
cat <<EOF | sudo tee /etc/systemd/system/kubelet.service
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/kubernetes/kubernetes
After=containerd.service
Requires=containerd.service

[Service]
ExecStart=/usr/local/bin/kubelet \\
  --config=/var/lib/kubelet/kubelet-config.yaml \\
  --container-runtime=remote \\
  --container-runtime-endpoint=unix:///var/run/containerd/containerd.sock \\
  --image-pull-progress-deadline=2m \\
  --kubeconfig=${KUBELET_LIB_DIR}/kubeconfig \\
  --bootstrap-kubeconfig=${KUBELET_LIB_DIR}/bootstrap-kubeconfig \\
  --cert-dir=${KUBELET_LIB_DIR} \\
  --network-plugin=cni \\
  --cni-conf-dir=/etc/cni/net.d \\
  --register-node=true \\
  --cloud-provider=gce \\
  --cloud-config=/etc/kubernetes/cloud-config \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Start: Containerd
# Ref https://v1-15.docs.kubernetes.io/docs/setup/production-environment/container-runtimes/#containerd
# https://kubernetes.io/docs/tasks/administer-cluster/dns-debugging-resolution/
cat << EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF
cat << EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
sudo modprobe overlay
sudo modprobe br_netfilter
sudo sysctl --system
# End: Containerd

sudo systemctl daemon-reload

sudo systemctl enable containerd
sudo systemctl start containerd

sudo systemctl enable kubelet
sudo systemctl start kubelet

sudo systemctl enable kube-proxy
sudo systemctl start kube-proxy
