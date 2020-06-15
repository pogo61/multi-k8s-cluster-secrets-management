node_pools = {
  vault     = { count = 1, node_count = 1, machine_type = "n1-standard-2" }
  consul    = { count = 1, node_count = 1, machine_type = "n1-standard-2" }
}

