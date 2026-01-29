provider "google" {
  project = var.project_id
  region  = var.region
}

resource "google_container_cluster" "gke" {
  name     = "harness-cluster"
  location = var.zone
  remove_default_node_pool = true
  initial_node_count       = 1

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }
}

resource "google_container_node_pool" "primary_nodes" {
  name       = "primary-node-pool"
  location   = var.zone
  cluster    = google_container_cluster.gke.name

  node_config {
    machine_type = "e2-standard-2"
    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  autoscaling {
    min_node_count = 2
    max_node_count = 4
  }

  initial_node_count = 2
}

resource "google_artifact_registry_repository" "repo" {
  location      = var.region
  repository_id = "harness-repo"
  format        = "DOCKER"
}
