variable "namecheap_username" {
  description = "Namecheap username"
  type        = string
  sensitive   = true
}

variable "namecheap_api_key" {
  description = "Namecheap API key"
  type        = string
  sensitive   = true
}

variable "lightsail_ip" {
  description = "AWS Lightsail VPS IP address"
  type        = string
  default     = "13.54.159.183"
}

variable "domain" {
  description = "Base domain"
  type        = string
  default     = "enspyr.co"
}
