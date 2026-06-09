# Copyright 2022 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Definition of local variables
locals {
  base_apis = [
    "container.googleapis.com",
    "monitoring.googleapis.com",
    "cloudtrace.googleapis.com",
    "cloudprofiler.googleapis.com"
  ]

  memorystore_apis = ["redis.googleapis.com"]
  cluster_name     = google_container_cluster.my_cluster.name
}

# Enable Google Cloud APIs
module "enable_google_apis" {
  source  = "terraform-google-modules/project-factory/google//modules/project_services"
  version = "~> 18.0"

  project_id                  = var.gcp_project_id
  disable_services_on_destroy = false

  activate_apis = concat(
    local.base_apis,
    var.memorystore ? local.memorystore_apis : []
  )
}

# Create GKE cluster
resource "google_container_cluster" "my_cluster" {
  name     = var.name
  location = var.region

  enable_autopilot = true

  ip_allocation_policy {
  }

  depends_on = [
    module.enable_google_apis
  ]
}

# Get GKE credentials using PowerShell
resource "null_resource" "get_credentials" {
  provisioner "local-exec" {
    interpreter = ["PowerShell", "-Command"]

    command = <<-EOT
      gcloud container clusters get-credentials ${local.cluster_name} --region ${var.region} --project ${var.gcp_project_id}
    EOT
  }

  depends_on = [
    google_container_cluster.my_cluster
  ]
}

# Apply Kubernetes manifests
resource "null_resource" "apply_deployment" {
  provisioner "local-exec" {
    interpreter = ["PowerShell", "-Command"]

    command = "kubectl apply -k ${var.filepath_manifest} -n ${var.namespace}"
  }

  depends_on = [
    null_resource.get_credentials
  ]
}

# Wait for resources to become ready
resource "null_resource" "wait_conditions" {
  provisioner "local-exec" {
    interpreter = ["PowerShell", "-Command"]

    command = <<-EOT
      kubectl wait --for=condition=Available apiservice/v1beta1.metrics.k8s.io --timeout=180s
      kubectl wait --for=condition=Ready pods --all -n ${var.namespace} --timeout=280s
    EOT
  }

  depends_on = [
    null_resource.apply_deployment
  ]
}
