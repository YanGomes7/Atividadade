terraform {
  required_providers {
    libvirt = { source = "dmacvicar/libvirt", version = "0.7.6" }
    local   = { source = "hashicorp/local", version = "~> 2.0" }
  }
}

variable "libvirt_uri" {
  default = "qemu:///system"
}

variable "base_image" {
  description = "Imagem cloud Ubuntu (qcow2). URL ou caminho local."
  default     = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
}

variable "public_key_path" {
  default = "~/.ssh/id_rsa.pub"
}

variable "private_key_path" {
  default = "~/.ssh/id_rsa"
}

variable "pool_path" {
  default = "/var/lib/libvirt/images/avaliacao"
}

provider "libvirt" {
  uri = var.libvirt_uri
}

resource "libvirt_pool" "pool" {
  name = "avaliacao"
  type = "dir"
  path = var.pool_path
}

resource "libvirt_volume" "base" {
  name   = "ubuntu-base.qcow2"
  pool   = libvirt_pool.pool.name
  source = var.base_image
  format = "qcow2"
}

locals {
  vms = ["vm1", "vm2"]
}

resource "libvirt_volume" "disk" {
  for_each       = toset(local.vms)
  name           = "${each.key}.qcow2"
  pool           = libvirt_pool.pool.name
  base_volume_id = libvirt_volume.base.id
  size           = 12884901888 # 12 GB
}

resource "libvirt_cloudinit_disk" "init" {
  for_each = toset(local.vms)
  name     = "${each.key}-init.iso"
  pool     = libvirt_pool.pool.name
  user_data = templatefile("${path.module}/cloud_init.yaml", {
    hostname = each.key
    ssh_key  = trimspace(file(pathexpand(var.public_key_path)))
  })
}

resource "libvirt_domain" "vm" {
  for_each  = toset(local.vms)
  name      = each.key
  memory    = 2048
  vcpu      = 2
  cloudinit = libvirt_cloudinit_disk.init[each.key].id

  network_interface {
    network_name   = "default"
    wait_for_lease = true
  }

  disk {
    volume_id = libvirt_volume.disk[each.key].id
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }
}

# Gera o inventory do Ansible com os IPs das VMs QEMU
resource "local_file" "inventory" {
  filename = "${path.module}/../ansible/inventory"
  content  = <<-EOT
    [vm1]
    ${libvirt_domain.vm["vm1"].network_interface[0].addresses[0]} ansible_user=ubuntu ansible_ssh_private_key_file=${var.private_key_path} ansible_ssh_common_args='-o StrictHostKeyChecking=no'

    [vm2]
    ${libvirt_domain.vm["vm2"].network_interface[0].addresses[0]} ansible_user=ubuntu ansible_ssh_private_key_file=${var.private_key_path} ansible_ssh_common_args='-o StrictHostKeyChecking=no'

    [all:vars]
    vm1_ip=${libvirt_domain.vm["vm1"].network_interface[0].addresses[0]}
    vm2_ip=${libvirt_domain.vm["vm2"].network_interface[0].addresses[0]}
  EOT
}

output "vm1_ip" {
  value = libvirt_domain.vm["vm1"].network_interface[0].addresses[0]
}

output "vm2_ip" {
  value = libvirt_domain.vm["vm2"].network_interface[0].addresses[0]
}
