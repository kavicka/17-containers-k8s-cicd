terraform {
  required_version = ">= 1.6"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.35"
    }
  }
}

# Talks to whatever cluster the kubeconfig context points at: kind locally and in CI, EKS in step 18.
provider "kubernetes" {
  config_path    = var.kubeconfig
  config_context = var.kube_context
}
