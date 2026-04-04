# terraform/modules/cognito/variables.tf
variable "name" {
  description = "User Pool name"
  type        = string
}

variable "domain_prefix" {
  description = "Cognito User Pool domain prefix"
  type        = string
}

variable "callback_urls" {
  description = "Allowed callback URLs"
  type        = list(string)
  default     = ["https://localhost/oauth2/idpresponse"]
}

variable "logout_urls" {
  description = "Allowed logout URLs"
  type        = list(string)
  default     = ["https://localhost"]
}
