variable "organization_id" {
  description = <<EOF
    (Required) Yandex.Cloud Organization that the Cloud belongs to. If value is omitted, the default provider Organization ID is used.
    For more information see https://cloud.yandex.com/en/docs/organization/
  EOF
  type        = string
  default     = null
}

variable "cloud" {
  description = <<EOF
    (Required) Configuration of the Cloud.
    For more information see https://cloud.yandex.com/en/docs/resource-manager/concepts/resources-hierarchy#cloud.

    Configuration attributes:
      existing_cloud_id - (Required, unless using name) Allows to specify an existing Cloud ID. Conflicts with `name`.
      name              - (Required, unless using existing_cloud_id) The name of the Cloud. Conflicts with `existing_cloud_id`.
      description       - (Optional) Description of the Cloud.
      labels            - (Optional) A set of key/value label pairs to assign to the Cloud.

    At least one of `existing_cloud_id`, `name` must be specified.
  EOF
  nullable    = false
  type = object({
    existing_cloud_id = optional(string)
    name              = optional(string)
    description       = optional(string)
    labels            = optional(map(string))
  })
  validation {
    condition     = !(var.cloud.existing_cloud_id == null && var.cloud.name == null)
    error_message = "One of \"name\" or \"existing_cloud_id\" should be specified in \"cloud\"."
  }
  validation {
    condition     = !(var.cloud.existing_cloud_id != null && var.cloud.name != null)
    error_message = "Attributes \"name\" and \"existing_cloud_id\" conflicts. Only one of them should be used."
  }
  validation {
    condition     = !(var.cloud.name == null && var.cloud.description != null)
    error_message = "Cannot use attribute \"description\" when attribute \"name\" is not set."
  }
  validation {
    condition     = !(var.cloud.name == null && var.cloud.labels != null)
    error_message = "Cannot use attribute \"labels\" when attribute \"name\" is not set."
  }
  default = {}
}

variable "billing_account_id" {
  description = <<EOF
    (Required) ID of billing account to bind Cloud to.
    For more information see https://cloud.yandex.com/en/docs/billing/concepts/billing-account.
  EOF
  type        = string
  default     = null
}

variable "delay_after_cloud_create" {
  description = <<EOF
    Set a delay before creating folders after cloud creation.
    Temporary workaround until the issue of cloud creation by the Terraform provider is resolved.
  EOF
  nullable    = false
  type        = string
  default     = "180s"
}

variable "folders" {
  description = <<EOF
    (Optional) List of objects of the Cloud Folders.
    For more information see https://cloud.yandex.com/en/docs/resource-manager/concepts/resources-hierarchy#folder
  
    Configuration attributes:
      name        - (Required) The name of the Folder.
      description - (Optional) A description of the Folder.
      labels      - (Optional) A set of key/value label pairs to assign to the Folder.
  EOF
  nullable    = false
  type = list(object({
    name        = string
    description = optional(string)
    labels      = optional(map(string))
  }))

  # Get a list of folder names from each folder object.
  # Compare the length of the list with the length of the unique values in the list.
  # They must be equal.
  validation {
    condition     = length([for folder in var.folders : folder.name]) == length(distinct([for folder in var.folders : folder.name]))
    error_message = "Folder name must be unique."
  }
  default = []
}

variable "groups" {
  description = <<EOF
    (Optional) List of objects of the Organization Groups.
    For more information see https://cloud.yandex.com/en/docs/organization/manage-groups.

    Configuration attributes:
      name         - (Required) The name of the group. Must be unique in each object.
      description  - (Optional) A description of the group.
      members      - (Optional) List of group members.
      cloud_roles  - (Optional) List of cloud roles for the group.
      folder_roles - (Optional) List of objects with folder name and group roles for this folder.
    
    Objects in the `folder_roles` supports the following attributes:
      folder_name - (Required) The name of the folder.
      roles       - (Optional) List of roles for the group.
  EOF
  nullable    = false
  type = list(object({
    name        = string
    description = optional(string)
    members     = optional(set(string), [])
    cloud_roles = optional(set(string), [])
    folder_roles = optional(list(object({
      folder_name = string
      roles       = set(string)
    })), [])
  }))

  # Get a list of group names from each group object.
  # Compare the length of the list with the length of the unique values in the list.
  # They must be equal.
  validation {
    condition     = length([for group in var.groups : group.name]) == length(distinct([for group in var.groups : group.name]))
    error_message = "Attribute \"name\" must be unique."
  }

  # For each group object, get a list of folder names from each folder_roles object.
  # Compare the length of the list with the length of the unique values in the list.
  # They must be equal for each group object.
  validation {
    condition = alltrue(flatten([for group in var.groups :
      length([for folder_role in group.folder_roles : folder_role.folder_name]) == length(distinct([for folder_role in group.folder_roles : folder_role.folder_name]))
    ]))
    error_message = "Attribute \"folder_name\" in each \"folder_roles\" object must be unique."
  }
  default = []
}
