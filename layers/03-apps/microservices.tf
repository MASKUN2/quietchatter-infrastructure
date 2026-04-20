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

  user_data = base64encode(templatefile("${path.module}/templates/microservices_user_data.sh.tftpl", {
    aws_region      = var.aws_region
    s3_bucket_name  = data.terraform_remote_state.base.outputs.infra_assets_bucket_name
    controlplane_ip = data.terraform_remote_state.platform.outputs.controlplane_private_ip
    service_image   = each.value.image_var
    instance_name   = "quietchatter-${each.key}-node"
    loki_url        = data.terraform_remote_state.base.outputs.grafana_cloud_logs_url
    loki_user       = data.terraform_remote_state.base.outputs.grafana_cloud_user
    db_host         = data.terraform_remote_state.platform.outputs.controlplane_private_ip
    db_username     = data.terraform_remote_state.base.outputs.db_username
    app_name        = each.key
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name    = "quietchatter-${each.key}-node"
      Service = each.key
    }
  }

  # Ensure instances are replaced on user_data change
  update_default_version = true
}

# Auto Scaling Group for Microservices
resource "aws_autoscaling_group" "microservice" {
  for_each = var.microservices

  name                = "quietchatter-${each.key}-asg"
  vpc_zone_identifier = data.terraform_remote_state.base.outputs.private_subnet_ids
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

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 0
    }
    triggers = ["tag"]
  }

  tag {
    key                 = "Name"
    value               = "quietchatter-${each.key}-asg-node"
    propagate_at_launch = true
  }
}
