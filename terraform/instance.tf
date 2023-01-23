data "local_file" "ssh_key" {
  filename = pathexpand(var.ssh_key)
}

resource "google_compute_instance" "dev-box" {
  name           = var.name
  machine_type   = var.machine_type
  zone           = var.zone
  can_ip_forward = true
  desired_status = var.desired_status

  boot_disk {
    initialize_params {
      image = "projects/ubuntu-os-cloud/global/images/ubuntu-2204-jammy-v20220924"

      type  = "pd-ssd"
      size  = 100
    }
  }

  tags = ["allow-ssh"]

  network_interface {
    subnetwork = google_compute_subnetwork.dev-subnetwork.name
    stack_type = "IPV4_IPV6"
    access_config {}
  }

  metadata = {
    ssh-keys = "${var.user}:${data.local_file.ssh_key.content}"
  }

  metadata_startup_script = templatefile("${path.module}/startup_script.sh.tpl", {
    "user" = var.user
  })

  # required for some projects by organization policy
  shielded_instance_config {
    enable_secure_boot = true
  }
}
