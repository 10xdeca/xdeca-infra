# OCI Configuration
variable "region" {
  description = "OCI region"
  type        = string
  default     = "ap-melbourne-1"
}

variable "tenancy_ocid" {
  description = "Tenancy OCID"
  type        = string
  default     = "ocid1.tenancy.oc1..aaaaaaaa53sr57ghje45q5lkvqunbxbh45imq4rfblzsqvf7vk7y4sjait2a"
}

variable "compartment_id" {
  description = "Compartment OCID (defaults to tenancy for free tier)"
  type        = string
  default     = "ocid1.tenancy.oc1..aaaaaaaa53sr57ghje45q5lkvqunbxbh45imq4rfblzsqvf7vk7y4sjait2a"
}

# Network Configuration (existing resources)
variable "vcn_id" {
  description = "Existing VCN OCID"
  type        = string
  default     = "ocid1.vcn.oc1.ap-melbourne-1.amaaaaaa2htpxkqahlygi2p7wpfw3hlj3ygbinv4zehq5ay232m2bxzxbn4a"
}

variable "subnet_id" {
  description = "Existing Subnet OCID"
  type        = string
  default     = "ocid1.subnet.oc1.ap-melbourne-1.aaaaaaaa3sxklspcjmiddzuvkq7mlunze2sfm6r6qd3wcb4wmyyrqqmoe24q"
}

variable "availability_domain" {
  description = "Availability domain"
  type        = string
  default     = "MNVQ:AP-MELBOURNE-1-AD-1"
}

# Instance Configuration
variable "instance_name" {
  description = "Display name for the instance"
  type        = string
  default     = "xdeca"
}

variable "instance_shape" {
  description = "Instance shape"
  type        = string
  default     = "VM.Standard.A1.Flex"
}

variable "instance_ocpus" {
  description = "Number of OCPUs (free tier max: 4)"
  type        = number
  default     = 4
}

variable "instance_memory_gb" {
  description = "Memory in GB (free tier max: 24)"
  type        = number
  default     = 24
}

variable "boot_volume_size_gb" {
  description = "Boot volume size in GB (free tier max: 200)"
  type        = number
  default     = 50
}

variable "image_id" {
  description = "Ubuntu 24.04 aarch64 image OCID"
  type        = string
  default     = "ocid1.image.oc1.ap-melbourne-1.aaaaaaaaa23ah7oxjhhgcwyd56t6ydtghl2ovzqytnokzrv4233wyqpp5rka"
}

# SSH Configuration
variable "ssh_public_key_path" {
  description = "Path to SSH public key"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

# Domain Configuration
variable "domain" {
  description = "Base domain for services"
  type        = string
  default     = "yourdomain.com"
}
