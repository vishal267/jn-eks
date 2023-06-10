variable "kubernetes_external_dns_namespace" {
  description = "Namespace to release ExternalDNS into"
  type        = string
  default     = "external-dns-route53"
}

variable "helm_external_dns_chart_version" {
  description = "Helm chart version to use for ExternalDNS"
  type        = string
  default     = ""
}

variable "cluster_name" {
  description = "cluster Name"
  type        = string
  default     = "externaldnspoc"
}

variable "cluster_version" {
  description = "cluster version"
  type        = string
  default     = "1.25"
}

variable "aws_region" {
  description = "aws region"
  type        = string
  default     = "us-east-1"
}

variable "s3_backend_bucket" {
  description = "s3 backend bucket name"
  type        = string
  default     = "jn-webapp-tf"
}