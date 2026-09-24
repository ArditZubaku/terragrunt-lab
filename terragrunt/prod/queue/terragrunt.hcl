include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

include "unit" {
  path = "${get_repo_root()}/terragrunt/_units/queue.hcl"
}
