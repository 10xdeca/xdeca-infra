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

variable "kamatera_ip" {
  description = "Kamatera VPS IP address"
  type        = string
  default     = "103.125.218.210"
}

variable "domain" {
  description = "Base domain"
  type        = string
  default     = "enspyr.co"
}
