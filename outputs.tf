output "cloud_id" {
  description = "ID of the Cloud."
  value       = var.cloud.existing_cloud_id != null ? var.cloud.existing_cloud_id : yandex_resourcemanager_cloud.this[0].id
  depends_on  = [time_sleep.this]
}

output "cloud_name" {
  description = "The name of the Cloud."
  value       = var.cloud.existing_cloud_id != null ? data.yandex_resourcemanager_cloud.this[0].name : var.cloud.name
}

output "folders" {
  description = "Folder IDs and names, sorted by map key."
  value = [for key, folder in var.folders : {
    id   = yandex_resourcemanager_folder.this[key].id
    name = folder.name
  }]
}

output "groups" {
  description = "Group IDs and names, sorted by map key."
  value = [for key, group in var.groups : {
    id   = yandex_organizationmanager_group.this[key].id
    name = group.name
  }]
}
