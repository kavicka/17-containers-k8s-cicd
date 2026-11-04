variable "kubeconfig" {
  type    = string
  default = "~/.kube/config"
}

variable "kube_context" {
  type    = string
  default = "kind-rag"
}

variable "namespace" {
  type    = string
  default = "rag"
}

variable "llm_provider" {
  description = "fake (CI smoke tests) | ollama | bedrock | azure_openai"
  type        = string
  default     = "fake"
  validation {
    condition     = contains(["fake", "ollama", "bedrock", "azure_openai"], var.llm_provider)
    error_message = "llm_provider must be one of fake, ollama, bedrock, azure_openai."
  }
}

variable "llm_model" {
  type    = string
  default = "qwen3:4b"
}

variable "ollama_url" {
  type    = string
  default = "http://host.docker.internal:11434"
}
