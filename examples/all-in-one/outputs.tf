output "cloud_id" {
  description = "ID of the Cloud."
  value       = module.cloud.cloud_id
}

output "cloud_name" {
  description = "The name of the Cloud."
  value       = module.cloud.cloud_name
}

output "folders" {
  description = "The name of the Сloud folders."
  value       = module.cloud.folders
}

output "groups" {
  description = "The name of the groups."
  value       = module.cloud.groups
}
