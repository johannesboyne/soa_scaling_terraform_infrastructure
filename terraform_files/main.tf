# Main Terraform File
# -------------------
# Specify the provider and access details
provider "aws" {
    access_key = "${var.access_key}"
    secret_key = "${var.secret_key}"
    region = "${var.aws_region}"
}

# security groups -------------------------------------------------------------
resource "aws_security_group" "default" {
    name = "terraform_example"

    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        from_port = 81
        to_port = 81
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    # outbound internet access
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

# load balancers --------------------------------------------------------------
resource "aws_elb" "web" {
  name = "terraform-example-elb"
  availability_zones = ["${var.aws_region}a"]
  security_groups = ["${aws_security_group.default.id}"]

  listener {
    instance_port = 80
    instance_protocol = "http"
    lb_port = 80
    lb_protocol = "http"
  }

  instances = ["${aws_instance.community.id}"]
}
resource "aws_elb" "api" {
  name = "terraform-api-elb"
  availability_zones = ["${var.aws_region}a"]
  security_groups = ["${aws_security_group.default.id}"]

  listener {
    instance_port = 81
    instance_protocol = "http"
    lb_port = 80
    lb_protocol = "http"
  }

  instances = ["${aws_instance.community.id}"]
}
resource "aws_elb" "db" {
  name = "terraform-db-elb"
  availability_zones = ["${var.aws_region}a"]
  security_groups = ["${aws_security_group.default.id}"]

  listener {
    instance_port = 80
    instance_protocol = "http"
    lb_port = 80
    lb_protocol = "http"
  }
}
resource "aws_elb" "slackbot" {
  name = "terraform-slackbot-elb"
  availability_zones = ["${var.aws_region}a"]
  security_groups = ["${aws_security_group.default.id}"]

  listener {
    instance_port = 81
    instance_protocol = "http"
    lb_port = 80
    lb_protocol = "http"
  }
}
# scaling ---------------------------------------------------------------------
resource "aws_autoscaling_group" "api_bot" {
  availability_zones = ["${var.aws_region}a"]
  name = "api_bot-terraform-example"
  max_size = 2
  min_size = 1
  health_check_grace_period = 300
  health_check_type = "ELB"
  desired_capacity = 0
  force_delete = true
  launch_configuration = "${aws_launch_configuration.api_bot.name}"
  tag {
    key = "name"
    value = "api_bot"
    propagate_at_launch = true
  }
  
}
# instances -------------------------------------------------------------------
# autoscaling instances for the bot and api
resource "aws_launch_configuration" "api_bot" {
    name = "ECS ${aws_ecs_cluster.api.name}"
    image_id = "ami-b7f0f987"
    # prod -> t2.micro
    instance_type = "t2.micro"
    security_groups = ["${aws_security_group.default.id}"]
    key_name = "us-west-ecs"
    iam_instance_profile = "ecsInstanceRole"
    user_data = "#!/bin/bash\necho 'ECS_CLUSTER=${aws_ecs_cluster.api.name}\nECS_ENGINE_AUTH_TYPE=dockercfg\nECS_ENGINE_AUTH_DATA={\"${var.registry}\": {\"auth\": \"${var.auth}\",\"email\": \"${var.email}\"}}' >> /etc/ecs/ecs.config"
}
# single instance for the web-app and the db
resource "aws_instance" "web_db" {
  ami = "ami-b7f0f987"
  instance_type = "t2.micro"
  availability_zone = "${var.aws_region}a"
  vpc_security_group_ids = ["${aws_security_group.default.id}"]
  iam_instance_profile = "ecsInstanceRole"
  key_name = "us-west-ecs"
  tags {
    Name = "Web-and-DB"
  }
  user_data = "#!/bin/bash\nmkdir /data; mount /dev/xvdh /data; service docker restart; echo 'ECS_CLUSTER=${aws_ecs_cluster.cms.name}\nECS_ENGINE_AUTH_TYPE=dockercfg\nECS_ENGINE_AUTH_DATA={\"${var.registry}\": {\"auth\": \"${var.auth}\",\"email\": \"${var.email}\"}}' >> /etc/ecs/ecs.config;"
}

# volumes ---------------------------------------------------------------------
resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/xvdh"
  volume_id = "vol-cc9933d9" #existing volume, because we don't want to loose any data
  instance_id = "${aws_instance.web.id}"
  
}

# cluster ---------------------------------------------------------------------
resource "aws_ecs_cluster" "a" {
  name = "berlin"
}
resource "aws_ecs_cluster" "b" {
  name = "munich"
}

# services --------------------------------------------------------------------
resource "aws_ecs_service" "web" {
  name = "web"
  cluster = "${aws_ecs_cluster.web.id}"
  task_definition = "${aws_ecs_task_definition.webtask.arn}"
  desired_count = 1
  iam_role = "arn:aws:iam::419037307013:role/ecsServiceRole"

  load_balancer {
    elb_name = "${aws_elb.web.id}"
    container_name = "webtask"
    container_port = 1337
  }
}
resource "aws_ecs_service" "db" {
  name = "db"
  cluster = "${aws_ecs_cluster.cms.id}"
  task_definition = "${aws_ecs_task_definition.dbtask.arn}"
  desired_count = 1
  iam_role = "arn:aws:iam::419037307013:role/ecsServiceRole"

  load_balancer {
    elb_name = "${aws_elb.db.id}"
    container_name = "dbtask"
    container_port = 1337
  }
}


resource "aws_ecs_task_definition" "webtask" {
  family = "webtask"
  container_definitions = "${file("task-definitions/webtask.json")}"
  volume {
    name = "mongodbdata"
    host_path = "/data/db"
  }
}
resource "aws_ecs_task_definition" "apitask" {
  family = "apitask"
  container_definitions = "${file("task-definitions/apitask.json")}"
}
