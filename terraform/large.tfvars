node_pools = {
  vault     = { count = 2, node_count = 2, machine_type = "n1-standard-4" }
  consul    = { count = 2, node_count = 2, machine_type = "n1-standard-4" }
}
