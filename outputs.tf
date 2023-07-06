output "cloud_id" {
  description = "ID of the Cloud."
  value       = yandex_resourcemanager_cloud.this.id
}

output "cloud_name" {
  description = "The name of the Cloud."
  value       = yandex_resourcemanager_cloud.this.name
}
