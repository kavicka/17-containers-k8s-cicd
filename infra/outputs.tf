output "namespace" {
  value = kubernetes_namespace_v1.rag.metadata[0].name
}
