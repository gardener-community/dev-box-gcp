resource "google_compute_network" "dev-network" {
  name                     = var.name
  auto_create_subnetworks  = false
  enable_ula_internal_ipv6 = false
}

resource "google_compute_subnetwork" "dev-subnetwork" {
  name   = var.name
  region = var.region

  network          = google_compute_network.dev-network.id
  stack_type       = "IPV4_IPV6"
  ip_cidr_range    = "10.0.0.0/22"
  ipv6_access_type = "EXTERNAL"
}

resource "google_compute_firewall" "ssh" {
  name    = "${var.name}-ssh"
  network = google_compute_network.dev-network.name

  source_ranges = var.source_ranges
  allow {
    protocol = "icmp"
  }
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  target_tags = ["allow-ssh"]
}

resource "google_compute_firewall" "ports-ipv4" {
  name    = "${var.name}-ports-ipv4"
  network = google_compute_network.dev-network.name

  source_ranges = ["0.0.0.0/0"]
  allow {
    protocol = "icmp"
  }
  allow {
    protocol = "tcp"
    ports    = ["80","443","6222","6443","8132","8443"]
  }

}

resource "google_compute_firewall" "ports-ipv6" {
  name    = "${var.name}-ports-ipv6"
  network = google_compute_network.dev-network.name

  source_ranges = ["::/0"]
  # ICMPv6
  allow {
    protocol = "58"
  }
  allow {
    protocol = "tcp"
    ports    = ["80","443","6222","6443","8132","8443"]
  }

}