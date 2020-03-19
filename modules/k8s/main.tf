locals {
  # Paths inside the VMs.
  kube_lib_dir      = "/var/lib/kubernetes"
  kubelet_lib_dir   = "/var/lib/kubelet"
  kubeproxy_lib_dir = "/var/lib/kube-proxy"
  etcd_dir          = "/etc/etcd"
}

resource "google_compute_subnetwork" "kubernetes" {
  name          = "kubernetes"
  network       = var.network
  ip_cidr_range = var.ip_cidr_range
  region        = var.region
}

resource "google_compute_firewall" "k8s-allow-internal" {
  name          = "k8s-allow-internal"
  network       = var.network
  source_ranges = ["10.240.0.0/24", "10.200.0.0/16"]

  allow {
    protocol = "tcp"
  }

  allow {
    protocol = "udp"
  }

  allow {
    protocol = "icmp"
  }
}

resource "google_compute_firewall" "k8s-allow-external" {
  name          = "k8s-allow-external"
  network       = var.network
  source_ranges = ["0.0.0.0/0"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  allow {
    protocol = "tcp"
    ports    = ["6443"]
  }

  allow {
    protocol = "icmp"
  }
}

resource "google_compute_firewall" "kubernetes-allow-health-check" {
  name    = "kubernetes-allow-health-check"
  network = var.network

  allow {
    protocol = "tcp"
  }

  source_ranges = [
    "209.85.152.0/22",
    "209.85.204.0/22",
    "35.191.0.0/16",
  ]
}

resource "google_compute_address" "kubernetes" {
  name   = "kubernetes"
  region = var.region
}

resource "google_compute_http_health_check" "kubernetes" {
  name        = "kubernetes"
  description = "Kubernetes Health Check"

  timeout_sec        = 1
  check_interval_sec = 1

  host         = "kubernetes.default.svc.cluster.local"
  request_path = "/healthz"
}

resource "google_compute_target_pool" "kubernetes-target-pool" {
  name = "kubernetes-target-pool"

  health_checks = [
    google_compute_http_health_check.kubernetes.name
  ]

  instances = [for i in range(var.controller_count) : "${var.zone}/${var.controller_prefix}${i}"]
}

resource "google_compute_forwarding_rule" "kubernetes-forwarding-rule" {
  name = "kubernetes-forwarding-rule"

  region     = var.region
  port_range = 6443
  target     = google_compute_target_pool.kubernetes-target-pool.self_link
  ip_address = google_compute_address.kubernetes.address
}

resource "google_compute_instance" "worker" {
  count = var.worker_count

  name           = "${var.worker_prefix}${count.index}"
  machine_type   = var.machine_type[var.environment]
  can_ip_forward = true

  scheduling {
    preemptible       = var.worker_preemptible
    automatic_restart = false
  }

  tags = var.worker_tags

  metadata = {
    user-data = <<-EOT
      #cloud-config
      output:
        init:
          output: "> /var/log/cloud-init.out"
          error: "> /var/log/cloud-init.err"
        config: "tee -a /var/log/cloud-config.log"
        final:
          - ">> /var/log/cloud-final.out"
          - "/var/log/cloud-final.err"
      write_files:
      - path: ${local.kube_lib_dir}/ca.pem
        permissions: 0644
        owner: root
        content: |
          ${indent(4, file("${var.secrets_dir}/ca.pem"))}
      - path: ${local.kubeproxy_lib_dir}/kubeconfig
        permissions: 0644
        owner: root
        content: |
          ${indent(4, file("${var.secrets_dir}/kube-proxy.kubeconfig"))}
      - path: ${local.kubeproxy_lib_dir}/kube-proxy-config.yaml
        permissions: 0644
        owner: root
        content: |
          kind: KubeProxyConfiguration
          apiVersion: kubeproxy.config.k8s.io/v1alpha1
          clientConnection:
            kubeconfig: "${local.kubeproxy_lib_dir}/kubeconfig"
          mode: "iptables"
          clusterCIDR: "10.200.0.0/16"
      - path: /etc/systemd/system/kube-proxy.service
        permissions: 0644
        owner: root
        content: |
          [Unit]
          Description=Kubernetes Kube Proxy
          Documentation=https://github.com/kubernetes/kubernetes

          [Service]
          ExecStart=/usr/local/bin/kube-proxy \
            --config=${local.kubeproxy_lib_dir}/kube-proxy-config.yaml
          Restart=on-failure
          RestartSec=5

          [Install]
          WantedBy=multi-user.target
    EOT
    # `kube-api` is being interpolated with `https://${}:6443` at bootstrap time.
    # See the worker bootstrap script.
    kube-api        = google_compute_address.kubernetes.address
    bootstrap-token = var.bootstrap_token
    startup-script  = file("${var.bootstrap_dir}/init-worker.sh")
    pod-cidr        = "10.200.${count.index}.0/24"
    disk-image      = var.k8s_image
  }

  boot_disk {
    initialize_params {
      image = var.k8s_image
      size  = var.boot_disk_size[var.environment]
    }
  }

  network_interface {
    network    = var.network
    subnetwork = google_compute_subnetwork.kubernetes.name
    network_ip = "10.240.0.2${count.index}"
    access_config {}
  }

  service_account {
    scopes = var.service_account_scopes
  }
}

resource "google_compute_instance" "controller" {
  count = var.controller_count

  name           = "${var.controller_prefix}${count.index}"
  machine_type   = var.machine_type[var.environment]
  can_ip_forward = true

  tags = var.controller_tags

  metadata = {
    user-data      = <<-EOT
      #cloud-config
      output:
        init:
          output: "> /var/log/cloud-init.out"
          error: "> /var/log/cloud-init.err"
        config: "tee -a /var/log/cloud-config.log"
        final:
          - ">> /var/log/cloud-final.out"
          - "/var/log/cloud-final.err"
      write_files:
      - path: ${local.kube_lib_dir}/admin.kubeconfig
        permissions: 0644
        owner: root
        content: |
          ${indent(4, file("${var.secrets_dir}/admin.kubeconfig"))}
      - path: ${local.kube_lib_dir}/kube-scheduler.kubeconfig
        permissions: 0644
        owner: root
        content: |
          ${indent(4, file("${var.secrets_dir}/kube-scheduler.kubeconfig"))}
      - path: ${local.kube_lib_dir}/kube-controller-manager.kubeconfig
        permissions: 0644
        owner: root
        content: |
          ${indent(4, file("${var.secrets_dir}/kube-controller-manager.kubeconfig"))}
      - path: ${local.kube_lib_dir}/encryption-config.yaml
        permissions: 0644
        owner: root
        content: |
          ${indent(4, file("${var.secrets_dir}/encryption-config.yaml"))}
      - path: ${local.kube_lib_dir}/service-account.pem
        permissions: 0644
        owner: root
        content: |
          ${indent(4, file("${var.secrets_dir}/service-account.pem"))}
      - path: ${local.kube_lib_dir}/service-account-key.pem
        permissions: 0644
        owner: root
        content: |
          ${indent(4, file("${var.secrets_dir}/service-account-key.pem"))}
      - path: ${local.etcd_dir}/kubernetes.pem
        permissions: 0644
        owner: root
        content: |
          ${indent(4, file("${var.secrets_dir}/kubernetes.pem"))}
      - path: ${local.kube_lib_dir}/kubernetes.pem
        permissions: 0644
        owner: root
        content: |
          ${indent(4, file("${var.secrets_dir}/kubernetes.pem"))}
      - path: ${local.etcd_dir}/kubernetes-key.pem
        permissions: 0644
        owner: root
        content: |
          ${indent(4, file("${var.secrets_dir}/kubernetes-key.pem"))}
      - path: ${local.kube_lib_dir}/kubernetes-key.pem
        permissions: 0644
        owner: root
        content: |
          ${indent(4, file("${var.secrets_dir}/kubernetes-key.pem"))}
      - path: ${local.kube_lib_dir}/ca-key.pem
        permissions: 0644
        owner: root
        content: |
          ${indent(4, file("${var.secrets_dir}/ca-key.pem"))}
      - path: ${local.etcd_dir}/ca.pem
        permissions: 0644
        owner: root
        content: |
          ${indent(4, file("${var.secrets_dir}/ca.pem"))}
      - path: ${local.kube_lib_dir}/ca.pem
        permissions: 0644
        owner: root
        content: |
          ${indent(4, file("${var.secrets_dir}/ca.pem"))}
    EOT
    startup-script = file("${var.bootstrap_dir}/init-controller.sh")
    disk-image     = var.k8s_image
  }

  boot_disk {
    initialize_params {
      image = var.k8s_image
      size  = var.boot_disk_size[var.environment]
    }
  }

  network_interface {
    network    = var.network
    subnetwork = google_compute_subnetwork.kubernetes.name
    network_ip = "10.240.0.1${count.index}"
    access_config {}
  }

  service_account {
    scopes = var.service_account_scopes
  }
}

resource "google_compute_route" "kubernetes" {
  count = var.worker_count

  name        = "kubernetes-route-10-200-${count.index}-0-24"
  network     = var.network
  next_hop_ip = "10.240.0.2${count.index}"
  dest_range  = "10.200.${count.index}.0/24"
}
