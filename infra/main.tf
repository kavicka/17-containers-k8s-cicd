# Platform layer owned by Terraform: the namespace, its guard rails and the app configuration.
# The workloads themselves are applied with kustomize (k8s/), so app releases don't need a Terraform run.

resource "kubernetes_namespace_v1" "rag" {
  metadata {
    name   = var.namespace
    labels = { "app.kubernetes.io/part-of" = "rag-clinical" }
  }
}

# Hard ceiling for the whole namespace: a runaway deployment can't starve the rest of the cluster.
resource "kubernetes_resource_quota_v1" "rag" {
  metadata {
    name      = "rag-quota"
    namespace = kubernetes_namespace_v1.rag.metadata[0].name
  }
  spec {
    hard = {
      "requests.cpu"           = "4"
      "requests.memory"        = "8Gi"
      "limits.memory"          = "12Gi"
      "persistentvolumeclaims" = "5"
      "pods"                   = "20"
    }
  }
}

# Defaults for any container that forgets to declare resources (otherwise the quota would reject it).
resource "kubernetes_limit_range_v1" "rag" {
  metadata {
    name      = "rag-defaults"
    namespace = kubernetes_namespace_v1.rag.metadata[0].name
  }
  spec {
    limit {
      type            = "Container"
      default         = { memory = "256Mi" }
      default_request = { cpu = "50m", memory = "64Mi" }
    }
  }
}

# Non-secret configuration. Secrets (Azure key, …) would go to a kubernetes_secret_v1 fed from a secret store,
# never from a .tfvars file in git.
resource "kubernetes_config_map_v1" "rag" {
  metadata {
    name      = "rag-config"
    namespace = kubernetes_namespace_v1.rag.metadata[0].name
  }
  data = {
    QDRANT_URL   = "http://qdrant:6333"
    CHUNKING     = "section"
    LLM_PROVIDER = var.llm_provider
    LLM_MODEL    = var.llm_model
    OLLAMA_URL   = var.ollama_url
  }
}
