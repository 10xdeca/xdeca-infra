output "instance_id" {
  description = "OCID of the instance"
  value       = oci_core_instance.xdeca.id
}

output "instance_public_ip" {
  description = "Public IP of the instance"
  value       = oci_core_instance.xdeca.public_ip
}

output "instance_private_ip" {
  description = "Private IP of the instance"
  value       = oci_core_instance.xdeca.private_ip
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh ubuntu@${oci_core_instance.xdeca.public_ip}"
}
