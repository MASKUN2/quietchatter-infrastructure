# Launch Template for Microservices
resource "aws_launch_template" "microservice" {
  for_each = var.microservices

  name_prefix   = "quietchatter-${each.key}-lt-"
  image_id      = var.ami_id
  instance_type = "t4g.micro"

  vpc_security_group_ids = [data.terraform_remote_state.base.outputs.microservices_sg_id]

  iam_instance_profile {
    name = data.terraform_remote_state.base.outputs.ssm_profile_name
  }

  user_data = base64encode(templatefile("${path.module}/templates/user_data.sh.tftpl", {
    aws_region                  = var.aws_region
    grafana_api_key_secret_name = data.terraform_remote_state.base.outputs.grafana_api_key_secret_name
    alloy_config                = templatefile("${path.module}/templates/config.alloy.tftpl", {
                                     instance_name = "quietchatter-${each.key}-node"
                                     loki_url      = var.grafana_cloud_logs_url
                                     loki_user     = data.terraform_remote_state.base.outputs.grafana_cloud_user
                                  })
    docker_compose_config       = templatefile("${path.module}/templates/docker-compose.microservice-${each.key}.yaml.tftpl", {
                                     controlplane_ip = var.controlplane_private_ip
                                     service_image   = each.value.image_var
                                     db_host         = var.controlplane_private_ip
                                     db_username     = var.db_username
                                     db_password     = var.db_password
                                     kafka_brokers   = "${var.controlplane_private_ip}:19092"
                                   })
  }))

tag_specifications {
  resource_type = "instance"
  tags = {
    Name    = "quietchatter-${each.key}-node"
    Service = each.key
  }
}
}

# Auto Scaling Group for Microservices
resource "aws_autoscaling_group" "microservice" {
  for_each = var.microservices

  name                = "quietchatter-${each.key}-asg"
  vpc_zone_identifier = [data.terraform_remote_state.base.outputs.private_subnet_ids[0], data.terraform_remote_state.base.outputs.private_subnet_ids[1]]
  desired_capacity    = 1
  min_size            = 1
  max_size            = 1

  mixed_instances_policy {
    instances_distribution {
      on_demand_base_capacity                  = 0
      on_demand_percentage_above_base_capacity = 0
      spot_allocation_strategy                 = "price-capacity-optimized"
    }

    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.microservice[each.key].id
        version            = "$Latest"
      }

      override {
        instance_type = "t4g.micro"
      }
      override {
        instance_type = "t4g.small"
      }
    }
  }

  tag {
    key                 = "Name"
    value               = "quietchatter-${each.key}-asg-node"
    propagate_at_launch = true
  }

  # Dependencies handled by user_data wait scripts across layers
  # depends_on = [
  #   aws_route.private_nat_route,
  #   aws_instance.controlplane
  # ]
}
