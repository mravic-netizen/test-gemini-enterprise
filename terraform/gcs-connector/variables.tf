variable "project_id" {
  description = "The Google Cloud Project ID"
  type        = string
}

variable "location" {
  description = "The location for Discovery Engine resources"
  type        = string
  default     = "us"
}

variable "organization_id" {
  description = "The Google Cloud Organization ID"
  type        = string
}