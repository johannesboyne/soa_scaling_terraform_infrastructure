# Main Terraform File
# -------------------
# Specify the provider and access details
provider "aws" {
    access_key = "${var.access_key}"
    secret_key = "${var.secret_key}"
    region = "${var.aws_region}"
}

# iam instance profile --------------------------------------------------------
# this role is needed to setup the ECS instances
resource "aws_iam_instance_profile" "ecsRole" {
    name = "ecsRole"
    roles = ["${aws_iam_role.role.name}"]
}
# this role is needed to setup the ECS services
resource "aws_iam_instance_profile" "ecsService" {
    name = "ecsServiceProfile"
    roles = ["${aws_iam_role.role_service.name}"]
}

# instance policy
resource "aws_iam_role_policy" "instance_policy" {
    name = "instance_policy"
    role = "${aws_iam_role.role.id}"
    policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:Describe*",
                "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
                "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
                "ec2:Describe*",
                "ec2:AuthorizeSecurityGroupIngress",
                "ecs:CreateCluster",
                "ecs:DeregisterContainerInstance",
                "ecs:DiscoverPollEndpoint",
                "ecs:Poll",
                "ecs:RegisterContainerInstance",
                "ecs:Submit*"
            ],
            "Resource": [
                "*"
            ]
        }
    ]
}
EOF
}
# service policy
resource "aws_iam_role_policy" "service_policy" {
    name = "service_policy"
    role = "${aws_iam_role.role_service.id}"
    policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "elasticloadbalancing:Describe*",
        "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
        "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
        "ec2:Describe*",
        "ec2:AuthorizeSecurityGroupIngress",
        "ecs:StartTask",
        "ecs:StopTask",
        "ecs:RegisterContainerInstance",
        "ecs:DeregisterContainerInstance",
        "ecs:DiscoverPollEndpoint",
        "ecs:Submit*",
        "ecs:StartTelemetrySession",
        "ecs:Poll"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

# instance role
# assume role statement is mandatory
resource "aws_iam_role" "role" {
    name = "ecsRole"
    assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}
# service role
# assume role statement is mandatory
resource "aws_iam_role" "role_service" {
    name = "ecsService"
    assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ecs.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

# security groups -------------------------------------------------------------
# used for the load balancers etc.
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
# four services -> four load balancers
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

  instances = ["${aws_instance.web_db.id}"]
}
resource "aws_elb" "db" {
  name = "terraform-db-elb"
  availability_zones = ["${var.aws_region}a"]
  security_groups = ["${aws_security_group.default.id}"]

  listener {
    instance_port = 81
    instance_protocol = "http"
    lb_port = 80
    lb_protocol = "http"
  }

  instances = ["${aws_instance.web_db.id}"]
}
resource "aws_elb" "api" {
  name = "terraform-api-elb"
  availability_zones = ["${var.aws_region}a"]
  security_groups = ["${aws_security_group.default.id}"]

  listener {
    instance_port = 80
    instance_protocol = "http"
    lb_port = 80
    lb_protocol = "http"
  }
}

# scaling ---------------------------------------------------------------------
resource "aws_autoscaling_group" "api" {
  availability_zones = ["${var.aws_region}a"]
  name = "api-terraform-example"
  max_size = 2
  min_size = 1
  health_check_grace_period = 300
  health_check_type = "ELB"
  desired_capacity = 1
  force_delete = true
  launch_configuration = "${aws_launch_configuration.api.name}"
  tag {
    key = "name"
    value = "api"
    propagate_at_launch = true
  }
  
}

# cluster ---------------------------------------------------------------------
# cluster A: web, db
resource "aws_ecs_cluster" "a" {
  name = "berlin"
}
# cluster B: api
resource "aws_ecs_cluster" "b" {
  name = "munich"
}

# instances -------------------------------------------------------------------
# autoscaling instances for the api
resource "aws_launch_configuration" "api" {
    name = "ECS ${aws_ecs_cluster.b.name}"
    image_id = "ami-5721df13"
    instance_type = "t2.micro"
    security_groups = ["${aws_security_group.default.id}"]
    iam_instance_profile = "${aws_iam_instance_profile.ecsRole.name}"
    # using the user_data field to attach the instance to an ecs cluster
    # and configuring the docker user if necessary
    user_data = "#!/bin/bash\necho 'ECS_CLUSTER=${aws_ecs_cluster.b.name}\nECS_ENGINE_AUTH_TYPE=dockercfg\nECS_ENGINE_AUTH_DATA={\"${var.registry}\": {\"auth\": \"${var.auth}\",\"email\": \"${var.email}\"}}' >> /etc/ecs/ecs.config"
}
# single instance for the web-app and the db
resource "aws_instance" "web_db" {
  ami = "ami-5721df13"
  instance_type = "t2.micro"
  availability_zone = "${var.aws_region}a"
  vpc_security_group_ids = ["${aws_security_group.default.id}"]
  iam_instance_profile = "${aws_iam_instance_profile.ecsRole.name}"
  tags {
    Name = "Web-and-DB"
  }
  user_data = "#!/bin/bash\nmkdir /data; mount /dev/xvdh /data; service docker restart; echo 'ECS_CLUSTER=${aws_ecs_cluster.a.name}\nECS_ENGINE_AUTH_TYPE=dockercfg\nECS_ENGINE_AUTH_DATA={\"${var.registry}\": {\"auth\": \"${var.auth}\",\"email\": \"${var.email}\"}}' >> /etc/ecs/ecs.config;"
}

# volumes ---------------------------------------------------------------------
resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/xvdh"
  # existing volume, because we don't want to loose any data
  # this is the only item not defined in this terraform script
  volume_id = "vol-df04493a"
  instance_id = "${aws_instance.web_db.id}"
  
}

# services --------------------------------------------------------------------
# webservice
resource "aws_ecs_service" "web" {
  name = "web"
  cluster = "${aws_ecs_cluster.a.id}"
  task_definition = "${aws_ecs_task_definition.webtask.arn}"
  desired_count = 1
  iam_role = "${aws_iam_role.role_service.arn}"

  load_balancer {
    elb_name = "${aws_elb.web.id}"
    container_name = "webtask"
    container_port = 1337
  }
}
# dbservice
resource "aws_ecs_service" "db" {
  name = "db"
  cluster = "${aws_ecs_cluster.a.id}"
  task_definition = "${aws_ecs_task_definition.dbtask.arn}"
  desired_count = 1
  iam_role = "${aws_iam_role.role_service.arn}"

  load_balancer {
    elb_name = "${aws_elb.db.id}"
    container_name = "dbtask"
    container_port = 1337
  }
}
# apiservice
resource "aws_ecs_service" "api" {
  name = "api"
  cluster = "${aws_ecs_cluster.b.id}"
  task_definition = "${aws_ecs_task_definition.apitask.arn}"
  desired_count = 1
  iam_role = "${aws_iam_role.role_service.arn}"

  load_balancer {
    elb_name = "${aws_elb.api.id}"
    container_name = "apitask"
    container_port = 1337
  }
}

# webtask
resource "aws_ecs_task_definition" "webtask" {
  family = "webtask"
  container_definitions = "${file("task-definitions/webtask.json")}"
}
# dbtask
resource "aws_ecs_task_definition" "dbtask" {
  family = "dbtask"
  container_definitions = "${file("task-definitions/dbtask.json")}"
  volume {
    name = "persistend_data"
    host_path = "/data/db"
  }
}
# apitask
resource "aws_ecs_task_definition" "apitask" {
  family = "apitask"
  container_definitions = "${file("task-definitions/apitask.json")}"
}

output "service: web" {
  value = "${aws_elb.web.dns_name}"
}
output "service: db" {
  value = "${aws_elb.db.dns_name}"
}
output "service: api" {
  value = "${aws_elb.api.dns_name}"
}
