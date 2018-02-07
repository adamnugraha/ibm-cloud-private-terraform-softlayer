provider "ibm" {
  bluemix_api_key    = "${var.ibm_bmx_api_key}"
  softlayer_username = "${var.ibm_sl_username}"
  softlayer_api_key  = "${var.ibm_sl_api_key}"
}
# resource "ibm_compute_ssh_key" "cam_public_key" {
#   label      = "${var.ssh_key_name}"
#   public_key = "${var.ssh_public_key}"
# }
resource "tls_private_key" "ssh" {
  algorithm = "RSA"

  provisioner "local-exec" {
    command = "cat > ${var.ssh_key_name} <<EOL\n${tls_private_key.ssh.private_key_pem}\nEOL"
  }
}
resource "ibm_compute_ssh_key" "ibm_public_key" {
  label = "${var.ssh_key_name}"
  public_key = "${tls_private_key.ssh.public_key_openssh}"
}
#Local variables
locals {
  master_datadisk = "${var.master["kubelet_lv"] + var.master["docker_lv"] + var.master["registry_lv"] + var.master["etcd_lv"] + 1}"
  proxy_datadisk = "${var.proxy["kubelet_lv"] + var.proxy["docker_lv"] + 1}"
  management_datadisk = "${var.management["kubelet_lv"] + var.management["docker_lv"] + var.management["management_lv"] + 1}"
  worker_datadisk = "${var.worker["kubelet_lv"] + var.worker["docker_lv"] + 1}"
}

data "template_file" "createfs_master" {
  template = "${file("${path.module}/scripts/createfs_master.sh.tpl")}"
  vars {
    kubelet_lv = "${var.master["kubelet_lv"]}"
    docker_lv = "${var.master["docker_lv"]}"
    etcd_lv = "${var.master["etcd_lv"]}"
    registry_lv = "${var.master["registry_lv"]}"
  }
}
data "template_file" "createfs_proxy" {
  template = "${file("${path.module}/scripts/createfs_proxy.sh.tpl")}"
  vars {
    kubelet_lv = "${var.proxy["kubelet_lv"]}"
    docker_lv = "${var.proxy["docker_lv"]}"
  }
}
data "template_file" "createfs_management" {
  template = "${file("${path.module}/scripts/createfs_management.sh.tpl")}"
  vars {
    kubelet_lv = "${var.management["kubelet_lv"]}"
    docker_lv = "${var.management["docker_lv"]}"
    management_lv = "${var.management["management_lv"]}"
  }
}
data "template_file" "createfs_worker" {
  template = "${file("${path.module}/scripts/createfs_worker.sh.tpl")}"
  vars {
    kubelet_lv = "${var.worker["kubelet_lv"]}"
    docker_lv = "${var.worker["docker_lv"]}"
  }
}

# Create Master Node
resource "ibm_compute_vm_instance" "master" {
  count                = "${var.master["nodes"]}"
  datacenter           = "${var.datacenter}"
  domain               = "${var.domain}"
  hostname             = "${format("%s-%s-%01d", lower(var.instance_prefix), lower(var.master["name"]),count.index + 1) }"
  os_reference_code    = "${var.os_reference}"
  cores                = "${var.master["cpu_cores"]}"
  memory               = "${var.master["memory"]}"
  disks                = ["${var.master["disk_size"]}","${local.master_datadisk}"]
  local_disk           = "${var.master["local_disk"]}"
  network_speed        = "${var.master["network_speed"]}"
  hourly_billing       = "${var.master["hourly_billing"]}"
  private_network_only = "${var.master["private_network_only"]}"
  ssh_key_ids = ["${ibm_compute_ssh_key.ibm_public_key.id}"]
  #post_install_script_uri = "https://raw.githubusercontent.com/pjgunadi/ibm-cloud-private-terraform-softlayer/master/scripts/createfs_master.sh"

  connection {
    user = "${var.ssh_user}"
    private_key = "${tls_private_key.ssh.private_key_pem}"
    host = "${self.ipv4_address}"
  }

  provisioner "file" {
    content = "${data.template_file.createfs_master.rendered}"
    destination = "/tmp/createfs.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/createfs.sh; sudo /tmp/createfs.sh"
    ]
  }
}
# Create Proxy Node
resource "ibm_compute_vm_instance" "proxy" {
  count                = "${var.proxy["nodes"]}"
  datacenter           = "${var.datacenter}"
  domain               = "${var.domain}"
  hostname             = "${format("%s-%s-%01d", lower(var.instance_prefix), lower(var.proxy["name"]),count.index + 1) }"
  os_reference_code    = "${var.os_reference}"
  cores                = "${var.proxy["cpu_cores"]}"
  memory               = "${var.proxy["memory"]}"
  disks                = ["${var.proxy["disk_size"]}","${local.proxy_datadisk}"]
  local_disk           = "${var.proxy["local_disk"]}"
  network_speed        = "${var.proxy["network_speed"]}"
  hourly_billing       = "${var.proxy["hourly_billing"]}"
  private_network_only = "${var.proxy["private_network_only"]}"
  ssh_key_ids = ["${ibm_compute_ssh_key.ibm_public_key.id}"]
  #post_install_script_uri = "https://raw.githubusercontent.com/pjgunadi/ibm-cloud-private-terraform-softlayer/master/scripts/createfs_proxy.sh"

  connection {
    user = "${var.ssh_user}"
    private_key = "${tls_private_key.ssh.private_key_pem}"
    host = "${self.ipv4_address}"
  }

  provisioner "file" {
    content = "${data.template_file.createfs_proxy.rendered}"
    destination = "/tmp/createfs.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/createfs.sh; sudo /tmp/createfs.sh",
    ]
  }
}
# Create Management Node
resource "ibm_compute_vm_instance" "management" {
  count                = "${var.management["nodes"]}"
  datacenter           = "${var.datacenter}"
  domain               = "${var.domain}"
  hostname             = "${format("%s-%s-%01d", lower(var.instance_prefix), lower(var.management["name"]),count.index + 1) }"
  os_reference_code    = "${var.os_reference}"
  cores                = "${var.management["cpu_cores"]}"
  memory               = "${var.management["memory"]}"
  disks                = ["${var.management["disk_size"]}","${local.management_datadisk}"]
  local_disk           = "${var.management["local_disk"]}"
  network_speed        = "${var.management["network_speed"]}"
  hourly_billing       = "${var.management["hourly_billing"]}"
  private_network_only = "${var.management["private_network_only"]}"
  ssh_key_ids = ["${ibm_compute_ssh_key.ibm_public_key.id}"]
  #post_install_script_uri = "https://raw.githubusercontent.com/pjgunadi/ibm-cloud-private-terraform-softlayer/master/scripts/createfs_management.sh"

  connection {
    user = "${var.ssh_user}"
    private_key = "${tls_private_key.ssh.private_key_pem}"
    host = "${self.ipv4_address}"
  }

  provisioner "file" {
    content = "${data.template_file.createfs_management.rendered}"
    destination = "/tmp/createfs.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/createfs.sh; sudo /tmp/createfs.sh"
    ]
  }
}
# Create Worker Node
resource "ibm_compute_vm_instance" "worker" {
  count                = "${var.worker["nodes"]}"
  datacenter           = "${var.datacenter}"
  domain               = "${var.domain}"
  hostname             = "${format("%s-%s-%01d", lower(var.instance_prefix), lower(var.worker["name"]),count.index + 1) }"
  os_reference_code    = "${var.os_reference}"
  cores                = "${var.worker["cpu_cores"]}"
  memory               = "${var.worker["memory"]}"
  disks                = ["${var.worker["disk_size"]}","${local.worker_datadisk}","${var.worker["glusterfs"]}"]
  local_disk           = "${var.worker["local_disk"]}"
  network_speed        = "${var.worker["network_speed"]}"
  hourly_billing       = "${var.worker["hourly_billing"]}"
  private_network_only = "${var.worker["private_network_only"]}"
  ssh_key_ids = ["${ibm_compute_ssh_key.ibm_public_key.id}"]
  #post_install_script_uri = "https://raw.githubusercontent.com/pjgunadi/ibm-cloud-private-terraform-softlayer/master/scripts/createfs_worker.sh"

  connection {
    user = "${var.ssh_user}"
    private_key = "${tls_private_key.ssh.private_key_pem}"
    host = "${self.ipv4_address}"
  }

  provisioner "file" {
    content = "${data.template_file.createfs_worker.rendered}"
    destination = "/tmp/createfs.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/createfs.sh; sudo /tmp/createfs.sh"
    ]
  }
}
#Create Gluster Node
resource "ibm_compute_vm_instance" "gluster" {
  count                = "${var.gluster["nodes"]}"
  datacenter           = "${var.datacenter}"
  domain               = "${var.domain}"
  hostname             = "${format("%s-%s-%01d", lower(var.instance_prefix), lower(var.gluster["name"]),count.index + 1) }"
  os_reference_code    = "${var.os_reference}"
  cores                = "${var.gluster["cpu_cores"]}"
  memory               = "${var.gluster["memory"]}"
  disks                = ["${var.gluster["disk_size"]}","${var.gluster["glusterfs"]}"]
  local_disk           = "${var.gluster["local_disk"]}"
  network_speed        = "${var.gluster["network_speed"]}"
  hourly_billing       = "${var.gluster["hourly_billing"]}"
  private_network_only = "${var.gluster["private_network_only"]}"
  ssh_key_ids = ["${ibm_compute_ssh_key.ibm_public_key.id}"]
}

module "icpprovision" {
  source = "github.com/pjgunadi/terraform-module-icp-deploy"
  //Connection IPs
  icp-ips = "${concat(ibm_compute_vm_instance.master.*.ipv4_address, ibm_compute_vm_instance.proxy.*.ipv4_address, ibm_compute_vm_instance.management.*.ipv4_address, ibm_compute_vm_instance.worker.*.ipv4_address)}"
  boot-node = "${element(ibm_compute_vm_instance.master.*.ipv4_address, 0)}"

  //Configuration IPs
  icp-master = ["${ibm_compute_vm_instance.master.*.ipv4_address_private}"]
  icp-worker = ["${ibm_compute_vm_instance.worker.*.ipv4_address_private}"]
  #icp-proxy =  ["${ibm_compute_vm_instance.proxy.*.ipv4_address_private}"]
  icp-proxy =  ["${ibm_compute_vm_instance.master.*.ipv4_address_private}"] #Combined Proxy with Master
  icp-management = ["${ibm_compute_vm_instance.management.*.ipv4_address_private}"]

  icp-version = "${var.icp_version}"

  icp_source_server = "${var.icp_source_server}"
  icp_source_user = "${var.icp_source_user}"
  icp_source_password = "${var.icp_source_password}"
  image_file = "${var.icp_source_path}"

  # Workaround for terraform issue #10857
  # When this is fixed, we can work this out automatically
  cluster_size  = "${var.master["nodes"] + var.worker["nodes"] + var.proxy["nodes"] + var.management["nodes"]}"

  icp_configuration = {
    "cluster_name"              = "${var.cluster_name}"
    "network_cidr"              = "${var.network_cidr}"
    "service_cluster_ip_range"  = "${var.cluster_ip_range}"
    "ansible_user"              = "${var.ssh_user}"
    "ansible_become"            = "${var.ssh_user == "root" ? false : true}"
    "default_admin_password"    = "${var.icpadmin_password}"
    "calico_ipip_enabled"       = "true"
    "docker_log_max_size"       = "10m"
    "docker_log_max_file"       = "10"
    "cluster_access_ip"         = "${element(ibm_compute_vm_instance.master.*.ipv4_address, 0)}"
  #  "proxy_access_ip"           = "${element(ibm_compute_vm_instance.proxy.*.ipv4_address, 0)}"
    "proxy_access_ip"           = "${element(ibm_compute_vm_instance.master.*.ipv4_address, 0)}" #combined proxy with master
  }

  #Gluster
  #Gluster and Heketi nodes are set to worker nodes for demo. Use separate nodes for production
  install_gluster = "${var.install_gluster}"
  gluster_size = "${var.worker["nodes"]}" 
  gluster_ips = ["${ibm_compute_vm_instance.worker.*.ipv4_address}"] 
  gluster_svc_ips = ["${ibm_compute_vm_instance.worker.*.ipv4_address_private}"]
  device_name = "/dev/xvde" #update according to the device name provided by cloud provider
  heketi_ip = "${ibm_compute_vm_instance.worker.0.ipv4_address}" 
  heketi_svc_ip = "${ibm_compute_vm_instance.worker.0.ipv4_address_private}"
  cluster_name = "${var.cluster_name}.icp"

  generate_key = true
  #icp_pub_keyfile = "${tls_private_key.ssh.public_key_openssh}"
  #icp_priv_keyfile = "${tls_private_key.ssh.private_key_pem"}"
  
  ssh_user  = "${var.ssh_user}"
  ssh_key   = "${tls_private_key.ssh.private_key_pem}"
} 
