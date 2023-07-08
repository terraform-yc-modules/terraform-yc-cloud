output "cloud_id" {
  description = "ID of the Cloud."
  value       = yandex_resourcemanager_cloud.this.id
}

output "cloud_name" {
  description = "The name of the Cloud."
  value       = yandex_resourcemanager_cloud.this.name
}

output "folders" {
  description = "The name of the Сloud folders."
  value = [for folder in var.folders : {
    id   = yandex_resourcemanager_folder.this[folder.name].id
    name = folder.name
  }]
}

output "groups" {
  description = "The name of the groups."
  value = [for group in var.groups : {
    id   = yandex_organizationmanager_group.this[group.name].id
    name = group.name
  }]
}
