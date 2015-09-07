(work in progress)

---

# A 100% codified, scaling (Micro-)Service-Oriented-Architecture (SOA) with Docker and Terraform

Props to the [hashicorp](https://hashicorp.com/) team for creating amazing tools.

_Disclaimer: I'm not a DevOps master nor ninja. Please, do not take everything as a best practice._

##Introduction

_What Is?_:

* *[Docker](https://www.Docker.com/)*:

> Docker is an open-source project that automates the deployment of applications inside software containers, by providing an additional layer of abstraction and automation of operating-system-level virtualization on Linux, Mac OS and Windows. [Wikipedia](https://en.wikipedia.org/wiki/Docker_(software))

* *[Terraform](https://terraform.io/)*:

> Terraform provides a common configuration to launch infrastructure — from physical and virtual servers to email and DNS providers. [Terraform.io](https://terraform.io/)

##Workflow

```
                                           
 ┌──────────────────┐  Local-Dev. Machine  
 │    1. Develop    │  Docker              
 └──────────────────┘                      
           │                               
           ▼                               
 ┌──────────────────┐  Packer (push build config.)  <- not needed for now
 │     2. Build     │  Atlas  (run cloud build)     <- but it will come!
 └──────────────────┘                      
           │                               
           ▼                               
 ┌ ─ ─ ─ ─ ┼ ─ ─ ─ ─                       
    Infrastructure  │  Terraform (setup infrastructure) 
 └ ─ ─ ─ ─ ┼ ─ ─ ─ ─                       
                                           
           ▼                               
 ┌──────────────────┐  Docker              
 │    3. Deploy     │  Terraform           
 └──────────────────┘                      
```

##Components

We'll build a two cluster, 3 service, scaled "web-application", running on the 
amazon cloud.
The services could be build with any technology and because we're using Docker
it really would not change *anything*.

*Terminilogy:* (AWS centric)

* ELB = Elastic Load Balancer
* ECS = Elastic Cloud Service
* ECS (Cluster) = A Cluster orchestrated by ECS
* Instance = An EC2 Instance
* Service = A ECS Cluster service
* EBS Volume = Elastic Block Storage Volume

###The (m)SOA, m for mini

* ELB (s A.x) -> www.ourwebapp.com (HTML Webpage)
* ELB (s A.y) -> db.ourwebapp.com (Database Service)
* ELB (s B.u) -> api.ourwebapp.com (JSON API)

```
                     ┌──────────────────────────────────────────────────┐                           
                     │                                                  │ Λ                         
  ┌─────────────┐    │                 ┌────────────┬──────────────┐    │╱ ╲                        
  │ ELB (s A.x) │────┼─────────────────┼────────────┼▶Service A.x  │    ╱   ╲                       
  ├─────────────┤    │                 │Instance A.1├──────────────┤   ╱ ┌─────────────────────────┐
  │ ELB (s A.y) │────┼─────────────────┼────────────┼▶Service A.y  │  ▕  │ EBS Volume (persistent) │
  └─────────────┘    │                 │            ├──────────────┘   ╲ └─────────────────────────┘
                     │                 │            │                   ╲   ╱                       
                     │                 └────────────┘                   │╲ ╱                        
                     │ECS (Cluster A)         1                         │ V                         
                     └────────────────────────┼─────────────────────────┘ ▲                         
                                              │                           │                         
                                              └───────────────────────────┘                         
                                                                                                    
                     ┌──────────────────────────────────────────────────┐                           
  ┌─────────────┐    │                 ┌────────────┬──────────────┐    │                           
  │ ELB (s B.u) │────┼─────────────────┼────────────┼▶Service B.u  │    │                           
  └─────────────┘    │                 │Instance B.1├──────────────┘    │                           
                     │                 │            │                   │                           
                     │                 └────────────┘                   │                           
                     │                              │                   │                           
                     │                 │Instance B.n                    │                           
                     │                              │                   │                           
                     │ECS (Cluster B)  └ ─ ─ ─ ─ ─ ─                    │                           
                     └──────────────────────────────────────────────────┘                           
```

Enough with the theory, let's dive into the code. We'll begin with the
codification of our AWS infrastructure with Terraform.

`Disclaimer: We're running on AWS and thus the following is AWS opinionated. Running the following terraform plans on your AWS infrastructure will cost money unless you're using an account that qualifies under the AWS free-tier.`

*To give you an easy start I've created four individual Docker images, one for each service from above: webpage, database api, api, company-bot*

####Annotated Terraform files

[terraform_files/main.tf](terraform_files/main.tf)

```
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
resource "aws_autoscaling_group" "api_bot" {
  availability_zones = ["${var.aws_region}a"]
  name = "api_bot-terraform-example"
  max_size = 2
  min_size = 1
  health_check_grace_period = 300
  health_check_type = "ELB"
  desired_capacity = 1
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
    name = "ECS ${aws_ecs_cluster.b.name}"
    image_id = "ami-5721df13"
    # prod -> t2.micro
    instance_type = "t2.micro"
    security_groups = ["${aws_security_group.default.id}"]
    iam_instance_profile = "${aws_iam_instance_profile.ecsRole.name}"
    # using the user_data field to attach the instance to an ecs cluster
    # and configuring the Docker user if necessary
    user_data = "#!/bin/bash\necho 'ECS_CLUSTER=${aws_ecs_cluster.b.name}\nECS_ENGINE_AUTH_TYPE=Dockercfg\nECS_ENGINE_AUTH_DATA={\"${var.registry}\": {\"auth\": \"${var.auth}\",\"email\": \"${var.email}\"}}' >> /etc/ecs/ecs.config"
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
  user_data = "#!/bin/bash\nmkdir /data; mount /dev/xvdh /data; service Docker restart; echo 'ECS_CLUSTER=${aws_ecs_cluster.a.name}\nECS_ENGINE_AUTH_TYPE=Dockercfg\nECS_ENGINE_AUTH_DATA={\"${var.registry}\": {\"auth\": \"${var.auth}\",\"email\": \"${var.email}\"}}' >> /etc/ecs/ecs.config;"
}

# volumes ---------------------------------------------------------------------
resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/xvdh"
  # existing volume, because we don't want to loose any data
  # this is the only item not defined in this terraform script
  volume_id = "vol-df04493a"
  instance_id = "${aws_instance.web_db.id}"
  
}

# cluster ---------------------------------------------------------------------
# cluster A: web, db
resource "aws_ecs_cluster" "a" {
  name = "berlin"
}
# cluster B: api, bot
resource "aws_ecs_cluster" "b" {
  name = "munich"
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
# bottask
resource "aws_ecs_task_definition" "bottask" {
  family = "bottask"
  container_definitions = "${file("task-definitions/bottask.json")}"
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
```

[terraform_files/variables.tf](terraform_files/variables.tf)

```
variable "aws_region" {
    description = "AWS region to launch servers."
    default = "us-west-1"
}
variable "access_key" {
    description = "AWS access key"
}
variable "secret_key" {
    description = "AWS secret key"
}
variable "registry" {
    description = "Docker registry"
    default = "https://index.Docker.io/v1/"
}
variable "auth" {
    description = "Docker auth token"
}
variable "email" {
    description = "Docker email"
}
```

[terraform_files/task-definitions/webtask.json](terraform_files/task-definitions/webtask.json)

```
[
  {
    "name": "webtask",
    "image": "johannesboyne/webexample",
    "cpu": 120,
    "memory": 90,
    "essential": true,
    "portMappings": [
      {
        "containerPort": 1337,
        "hostPort": 80
      }
    ],
    "environment" : [
      { "name" : "PORT", "value" : "1337" }
    ],
    "command": []
  }
]
```

[terraform_files/task-definitions/dbtask.json](terraform_files/task-definitions/dbtask.json)

```
[
  {
    "name": "dbtask",
    "image": "johannesboyne/webexample",
    "cpu": 120,
    "memory": 90,
    "essential": true,
    "portMappings": [
      {
        "containerPort": 1337,
        "hostPort": 81
      }
    ],
    "mountPoints": [
      {
        "sourceVolume": "persistend_data",
        "containerPath": "/data/db",
        "readOnly": false
      }
    ],
    "environment" : [
      { "name" : "PORT", "value" : "1337" },
      { "name" : "SERVICE", "value" : "db" }
    ],
    "command": []
  }
]
```

[terraform_files/task-definitions/apitask.json](terraform_files/task-definitions/apitask.json)

```
[
  {
    "name": "apitask",
    "image": "johannesboyne/webexample",
    "cpu": 120,
    "memory": 90,
    "essential": true,
    "portMappings": [
      {
        "containerPort": 1337,
        "hostPort": 80
      }
    ],
    "environment" : [
      { "name" : "SERVICE", "value" : "api" },
      { "name" : "PORT", "value" : "1337" }
    ],
    "command": []
  }
]
```
####Running the commands

Now, let's begin with the magic, we can check whether the plan suits our needs,
by running `terraform plan` (your variables can either be set inline or inside
a `variables.tf` file).

Constructing our infrastructure is as easy as: `terraform apply` and destroying
it afterwards can be achieved by running: `terraform destroy`.

Running these commands takes some time, 1-2 minutes, depends on the AWS load.
Plus, wait a minute before accessing the services through the load-
balancers, because the instances have to be initiated and added before.

####Using Packer and Atlas

Right now, we only have used Terraform to codify our infrastructure and 
automatically set it up.
But, **what if you don't have pre-build Docker containers?** I've got you covered.

Packer and Atlas are a great team, because Packer is an absolutely great build
tool for all kind of images and containers (Vagrant, AMI, DigitalOcean, Docker, ...)
for various platforms.
Atlas is Hashicorp's version control system for infrastructures **and** additionally
it has got an implemented cloud-build service.
If you are running Docker on OS X you'll probably end using boot2Docker.
boot2Docker is *alright*, it bridges the gap because OS X is not Linux and thus 
one cannot easily run most Docker containers and Docker has not been ported 
(completely) anyways, but for sure it's not a great because it uses a VM.
This means, one has to run Docker containers in a VM on OS X.

Let me quote [Bryan Cantrill](https://github.com/bcantrill): https://www.youtube.com/watch?v=Ll50EFquwSo

> People are running OS containers in VMs - don't do this. God is angry that you're
doing this. God's like: What the hell? I dropped you containers there a while ago
and I had some other work to do, and I just came back and what the hell is this?

_(Actually this quote was made to emphasize the (solved) "problem" regarding security concerns with Docker containers, but it works here as well.)_

Packer and Atlas are here to save us. The `packer push` command pushes a packer
build file to the Atlas build service, which then generates our Docker images - fast
and without eating our development machine's resources.

But besides this awesome, easy, external Docker image build-service, using Packer
comes with another advantage: moving your infrastructure to another cloud provider 
or even to on-prem. becomes as easy as flipping a switch.

Because the Docker images where given, we didn't have to build these images ourselves, but 
I'll show you how a packer build file looks like, for a real world application, 
a **[keystone.js](http://keystonejs.com/) CMS**, in a second mini-tutorial on 
Packer, Atlas, Terraform and containers.

####Structuring a Terraform configuration

In a production environment one should probably use multiple files to describe the infrastructure.

##Troubleshooting

```
diffs didn't match during apply. This is a bug with Terraform and should be reported
```

`->` delete the `terraform.tfstate*` file(s).

