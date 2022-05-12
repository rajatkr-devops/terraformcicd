# variable codestar_connector_credentials {
#     type = string
# }
variable git_repository_name {
  description = "Name of the remote source repository"
   type        = string
}

variable "codecommit_repo_arn" {
  description = "The repo which will be monitored"
  type = string
}
variable "branch_to_monitor" {
  description = "Monitor changes on this branch of CodeCommit"
  type = string
}
# variable "tag" {
#   description = "Tags the resources with this name"
#   type = string
# }
