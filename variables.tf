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
    Activation buffer after binding a new cloud to billing, before folders, cloud IAM assignments and cloud_id consumers.
    Defaults to 180s; use 0s to disable the buffer. Existing clouds are not delayed. This is not an API readiness probe.
  EOF
  nullable    = false
  type        = string
  default     = "180s"
}

variable "folders" {
  description = <<EOF
    (Optional) Map of Cloud Folders, indexed by stable Terraform resource keys.
    For more information see https://cloud.yandex.com/en/docs/resource-manager/concepts/resources-hierarchy#folder
  
    Configuration attributes:
      name        - (Required) The name of the Folder.
      description - (Optional) A description of the Folder.
      labels      - (Optional) A set of key/value label pairs to assign to the Folder.
  EOF
  nullable    = false
  type = map(object({
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
  validation {
    condition = alltrue([
      for key in keys(var.folders) : trimspace(key) != "" && length(regexall(":", key)) == 0
    ])
    error_message = "Folder key must not be blank or contain a colon (:)."
  }
  default = {}
}

variable "groups" {
  description = <<EOF
    (Optional) Map of Organization Groups, indexed by stable Terraform resource keys.
    For more information see https://cloud.yandex.com/en/docs/organization/manage-groups.

    Configuration attributes:
      name           - (Required) The name of the group. Must be unique in each object.
      description    - (Optional) A description of the group.
      manage_members - (Optional) Whether to manage declared group memberships. Defaults to false and must be known at plan time.
      members        - (Optional) Set of managed member IDs. Required when manage_members is true; use [] for an empty managed set. Omit otherwise.
      cloud_roles    - (Optional) List of cloud roles for the group.
      folder_roles   - (Optional) Map of folder keys to sets of roles for the group. Each key must exist in folders.
  EOF
  nullable    = false
  type = map(object({
    name           = string
    description    = optional(string)
    manage_members = optional(bool, false)
    members        = optional(set(string))
    cloud_roles    = optional(set(string), [])
    folder_roles   = optional(map(set(string)), {})
  }))

  # Get a list of group names from each group object.
  # Compare the length of the list with the length of the unique values in the list.
  # They must be equal.
  validation {
    condition     = length([for group in var.groups : group.name]) == length(distinct([for group in var.groups : group.name]))
    error_message = "Attribute \"name\" must be unique."
  }
  validation {
    condition = alltrue([
      for key in keys(var.groups) : trimspace(key) != "" && length(regexall(":", key)) == 0
    ])
    error_message = "Group key must not be blank or contain a colon (:)."
  }
  validation {
    condition = alltrue([
      for group in var.groups : group.manage_members ? group.members != null : group.members == null
    ])
    error_message = "Set manage_members = true and provide members (use [] for an empty managed set); otherwise omit members or set it to null."
  }
  validation {
    condition = alltrue(flatten([
      for group in var.groups : [
        for folder_key in keys(group.folder_roles) : trimspace(folder_key) != ""
      ]
    ]))
    error_message = "Folder keys in folder_roles must not be blank."
  }
  validation {
    condition = alltrue(flatten([
      for group in var.groups : [
        for roles in values(group.folder_roles) : roles != null
      ]
    ]))
    error_message = "Role sets in folder_roles must not be null. Use an empty set to assign no roles."
  }
  default = {}
}
