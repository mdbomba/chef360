locals {
  subnet_count = max(length(var.public_subnet_cidrs), length(var.private_subnet_cidrs))

  selected_azs = length(var.availability_zones) > 0 ? var.availability_zones : slice(
    data.aws_availability_zones.available.names,
    0,
    local.subnet_count,
  )

  topology_nodes = {
    single_node = {
      "node-01" = {
        hostname         = "${var.name_prefix}-node-01"
        role             = "controller-frontend-backend"
        instance_type    = var.single_node_instance_type
        root_volume_size = 200
        subnet_index     = 0
      }
    }

    hyperconverged_ha = {
      for index in range(3) : format("node-%02d", index + 1) => {
        hostname         = "${var.name_prefix}-${format("node-%02d", index + 1)}"
        role             = "controller-frontend-backend"
        instance_type    = var.hyperconverged_instance_type
        root_volume_size = 200
        subnet_index     = index
      }
    }

    tiered_ha = merge(
      {
        for index in range(3) : format("controller-backend-%02d", index + 1) => {
          hostname         = "${var.name_prefix}-${format("controller-backend-%02d", index + 1)}"
          role             = "controller-backend"
          instance_type    = var.tiered_backend_instance_type
          root_volume_size = 200
          subnet_index     = index
        }
      },
      {
        for index in range(3) : format("frontend-%02d", index + 1) => {
          hostname         = "${var.name_prefix}-${format("frontend-%02d", index + 1)}"
          role             = "frontend"
          instance_type    = var.tiered_frontend_instance_type
          root_volume_size = 50
          subnet_index     = index
        }
      },
    )

    hyperscale_ha = merge(
      {
        for index in range(3) : format("controller-%02d", index + 1) => {
          hostname         = "${var.name_prefix}-${format("controller-%02d", index + 1)}"
          role             = "controller"
          instance_type    = var.hyperscale_controller_instance_type
          root_volume_size = 50
          subnet_index     = index
        }
      },
      {
        for index in range(3) : format("frontend-%02d", index + 1) => {
          hostname         = "${var.name_prefix}-${format("frontend-%02d", index + 1)}"
          role             = "frontend"
          instance_type    = var.hyperscale_frontend_instance_type
          root_volume_size = 50
          subnet_index     = index
        }
      },
      {
        for index in range(3) : format("backend-%02d", index + 1) => {
          hostname         = "${var.name_prefix}-${format("backend-%02d", index + 1)}"
          role             = "backend"
          instance_type    = var.hyperscale_backend_instance_type
          root_volume_size = 200
          subnet_index     = index
        }
      },
    )
  }

  nodes            = local.topology_nodes[var.topology]
  multi_node       = var.topology != "single_node"
  primary_node_key = sort(keys(local.nodes))[0]

  admin_console_fqdn = var.domain_name == null ? null : "${var.admin_console_hostname}.${var.domain_name}"
  tenant_fqdn        = var.domain_name == null ? null : "${var.tenant_hostname}.${var.domain_name}"
  node_fqdns = var.domain_name == null ? {} : {
    for node_key, node in local.nodes : node_key => "${node.hostname}.${var.domain_name}"
  }
}
