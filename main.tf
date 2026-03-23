#creates instance
resource "aws_instance" "main" {
    ami = local.ami_id
    instance_type = "t3.micro"
    subnet_id = local.private_subnet_id
    vpc_security_group_ids = [local.sg_id]

    tags = merge(
        {
            Name = "${var.project}-${var.environment}-${var.component}"
        },
        local.common_tags
    )
}

#configure component
resource "terraform_data" "main" {
    triggers_replace = [
        aws_instance.main.id
    ]

    connection {
        type = "ssh"
        user = "ec2-user"
        password = "DevOps321"
        host = aws_instance.main.private_ip
    }

    provisioner "file" {
        source = "bootstrap.sh"  #Local file path
        destination = "/tmp/bootstrap.sh"  #Destination path on the remote machine
    }

    provisioner "remote-exec" {
        inline = [
            "chmod +x /tmp/bootstrap.sh",
            "sudo sh /tmp/bootstrap.sh ${var.component} ${var.environment} ${var.app_version} "
        ]
    }
}

#To stop instance
resource "aws_ec2_instance_state" "main" {
  instance_id = aws_instance.main.id
  state       = "stopped"
  depends_on = [terraform_data.main]
}

#creates ami
resource "aws_ami_from_instance" "main" {
    name = "${var.project}-${var.environment}-${var.component}"
    source_instance_id = aws_instance.main.id
    depends_on = [aws_ec2_instance_state.main]

     tags = merge(
        {
            Name = "${var.project}-${var.environment}-${var.component}"
        },
        local.common_tags
    )
}

#creates LB target group
resource "aws_lb_target_group" "main" {
    name = "${var.project}-${var.environment}-${var.component}"
    port = local.port_number
    protocol = "HTTP"
    vpc_id = local.vpc_id 

    health_check {
        healthy_threshold = 2
        interval = 10
        matcher = "200-299"
        path = local.health_check_path
        port = local.port_number
        protocol  = "HTTP"
        timeout = 2
        unhealthy_threshold = 3
    }
}

#creates launch template
resource "aws_launch_template" "main" {
  name = "${var.project}-${var.environment}-${var.component}"
  image_id = aws_ami_from_instance.main.id

  #once autoscaling sees less traffic, it will terminate the instance  
  instance_initiated_shutdown_behavior = "terminate"
  instance_type = "t3.micro"
  vpc_security_group_ids = [local.sg_id]

  update_default_version = true

  #tags for instance created by launch template through auto scaling  
  tag_specifications {
    resource_type = "instance"

    tags = merge(
        {
            Name = "${var.project}-${var.environment}-${var.component}"
        },
        local.common_tags
    )
  }
  #tags for volume created by instances
  tag_specifications {
    resource_type = "volume"

    tags = merge(
        {
            Name = "${var.project}-${var.environment}-${var.component}"
        },
        local.common_tags
    )
  }
  #tags for launch template
    tags = merge(
        {
            Name = "${var.project}-${var.environment}-${var.component}"
        },
        local.common_tags
    )
}

#autoscaling
resource "aws_autoscaling_group" "main" {
    name = "${var.project}-${var.environment}-${var.component}"
    max_size = 10
    min_size = 1
    health_check_grace_period = 120
    health_check_type = "ELB"
    desired_capacity = 2
    force_delete = false

    launch_template {
        id = aws_launch_template.main.id
        version = "$Latest"
    }

    vpc_zone_identifier = [local.private_subnet_id]   
    target_group_arns = [aws_lb_target_group.main.arn]

    instance_refresh {
        strategy = "Rolling"
        preferences {
            min_healthy_percentage = 50
        }
        triggers = ["launch_template"]
    }

    dynamic "tag" {
     for_each = merge(
        {
            Name = "${var.project}-${var.environment}-${var.component}"
        },
        local.common_tags
     )
     content {  
        key = tag.key
        value = tag.value
        propagate_at_launch = true
     }   
    }   

    #within 15mins autoscaling should be succesful
    timeouts {
        delete = "15m"
    }
}

#autoscaling policy
resource "aws_autoscaling_policy" "main" {
  name = "${var.project}-${var.environment}-${var.component}"
  autoscaling_group_name = aws_autoscaling_group.main.name
  policy_type = "TargetTrackingScaling"
  estimated_instance_warmup = 120

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 70.0
  }

}  

#lb listener rule
#this depends on target group
#if frontend, frontend-dev.daws-88s.online
# else -> *.backend-alb-dev.daws-88s.online

resource "aws_lb_listener_rule" "main" {
    listener_arn = local.alb_listener_arn
    priority = var.rule_priority

    action {
        type = "forward"
        target_group_arn = aws_lb_target_group.main.arn
    }
    condition {
        host_header {
            values = [local.host_header]
        }
    }
}

#delete the instance
resource "terraform_data" "main_delete" {
    triggers_replace = [
        aws_instance.main.id
    ]

    depends_on = [aws_autoscaling_policy.main]  
    
    #it executes in bastion
    provisioner "local-exec" {
        command = "aws ec2 terminate-instances --instance-ids ${aws_instance.main.id}"
    }
}