variable "app_name" {
  description = "The name of the application"
  type        = string
  default     = "newselatest"
}

variable "environment" {
  description = "The environment name"
  type        = string
  default     = "test"
}

variable "region" {
  description = "The AWS region where the infrastructure will be deployed"
  default     = "us-east-1"
  type        = string
}


variable "default_ttl" {
  description = "The default TTL for the CDN"
  default     = 300
  type        = number
}
