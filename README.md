(work in progress)

---

# A 100% codified, scaling (Micro-)Service-Oriented-Architecture (SOA) with docker, Packer, Terraform and Atlas

Fair enough, enough with the buzzword-bingo but seriously, this README will be buzzword *packed*.
And that's O.K. since docker, Packer, Terraform and Atlas are simply great.
Props to the [HASHICORP](https://hashicorp.com/) team for creating these amazing tools.

_Disclaimer: I'm not a DevOps master nor ninja. Please, do not take everything as a best practice._

##Introduction

_What Is?_:

* *[docker](https://www.docker.com/)*:

> Docker is an open-source project that automates the deployment of applications inside software containers, by providing an additional layer of abstraction and automation of operating-system-level virtualization on Linux, Mac OS and Windows. [Wikipedia](https://en.wikipedia.org/wiki/Docker_(software))

* *[Packer](https://packer.io/)*:

> Packer is a tool for creating machine and container images for multiple platforms from a single source configuration. [Packer.io](http://packer.io)

* *[Terraform](https://terraform.io/)*:

> Terraform provides a common configuration to launch infrastructure — from physical and virtual servers to email and DNS providers. [Terraform.io](https://terraform.io/)

* *[Atlas](https://atlas.hashicorp.com/)*:

> Atlas unites HashiCorp development and infrastructure management tools to create a version control system for infrastructure. [Atlas](https://atlas.hashicorp.com/)

##Workflow

```
                                           
 ┌──────────────────┐  Local-Dev. Machine  
 │    1. Develop    │  docker              
 └──────────────────┘                      
           │                               
           ▼                               
 ┌──────────────────┐  Packer (push build config.)
 │     2. Build     │  Atlas  (run cloud build)
 └──────────────────┘                      
           │                               
           ▼                               
 ┌ ─ ─ ─ ─ ┼ ─ ─ ─ ─                       
    Infrastructure  │  Terraform (setup infrastructure) 
 └ ─ ─ ─ ─ ┼ ─ ─ ─ ─                       
                                           
           ▼                               
 ┌──────────────────┐  docker              
 │    3. Deploy     │  Terraform           
 └──────────────────┘                      
```

##Components

We'll build a two cluster, 4 service, scaled "web-application".
The services could be build with any technology and because we're using docker
it really would not change *anything*.

*Terminilogy:*

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
* ELB (s B.v) -> slackbot.ourwebapp.com (Company Slackbot)

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
  ├─────────────┤    │                 │Instance B.1├──────────────┤    │                           
  │ ELB (s B.v) │────┼─────────────────┼────────────┼▶Service B.v  │    │                           
  └─────────────┘    │                 ├────────────┴──────────────┘    │                           
                     │                              │                   │                           
                     │                 │Instance B.n                    │                           
                     │                              │                   │                           
                     │ECS (Cluster B)  └ ─ ─ ─ ─ ─ ─                    │                           
                     └──────────────────────────────────────────────────┘                           
```

Enough with the theory, let's dive into the code. We'll begin with the
codification of our AWS infrastructure with Terraform.

`Disclaimer: We're running on AWS and thus the following is AWS opinionated. Running the following terraform plans on your AWS infrastructure will cost money if you're not using an account that qualifies under the AWS free-tier.`

*To give you an easy start I've created four individual docker images, one for each service from above: webpage, database api, api, company-bot*

####Annotated Terraform files

[terraform_files/main.tf](terraform_files/main.tf)

```
```

[terraform_files/variables.tf](terraform_files/variables.tf)

```
```

[terraform_files/task-definitions/webtask.json](terraform_files/task-definitions/webtask.json)

```
```

[terraform_files/task-definitions/dbtask.json](terraform_files/task-definitions/dbtask.json)

####Running the commands

Now, let's begin with the magic, we can check whether the plan suits our needs,
by running `terraform plan` (your variables can either be set inline or inside
a `variables.tf` file).

Constructing our infrastructure is as easy as: `terraform apply` and destroying
it afterwards can be achieved by running: `terraform destroy`.

####Using Packer and Atlas

Right now, we only have used Terraform to codify our infrastructure and 
automatically set it up.
But, **what if you don't have pre-build docker containers?** I've got you covered.

Packer and Atlas are a great team, because Packer is an absolutely great build
tool for all kind of images and containers (Vagrant, AMI, DigitalOcean, Docker, ...)
for various platforms.
Atlas is Hashicorp's version control system for infrastructures **and** additionally
it has got an implemented cloud-build service.
If you are running docker on OS X you'll probably end using boot2docker.
boot2docker is *all right*, it bridges the gap because OS X is not Linux and thus 
one cannot easily run most docker containers and docker has not been ported 
(completely) anyways, but for sure it's not a great because it uses a VM.
This means, one has to run docker containers in a VM on OS X.

Let me quote [Bryan Cantrill](https://github.com/bcantrill): https://www.youtube.com/watch?v=Ll50EFquwSo

> People are running OS containers in VMs - don't do this. God is angry that you're
doing this. God's like: What the hell? I dropped you containers there a while ago
and I had some other work to do, and I just came back and what the hell is this?

_(Actually this quote was made to emphasize the (solved) "problem" regarding security concerns with docker containers, but it works here as well.)_

Packer and Atlas are here to save us. The `packer push` command pushes a packer
build file to the Atlas build service, which than generates our docker images - fast
and without eating our development machines resources.

But besides this awesome, easy, external docker image build-service, using Packer
comes with another advantage: moving your infrastructure to another cloud provider 
or even to on-prem. becomes as easy as flipping a switch.

Because the docker images where given, we didn't had to build these images but 
I'll show you how a packer build file looks like for a real world application 
a **[keystone.js](http://keystonejs.com/) CMS** in a second mini-tutorial on 
Packer, Atlas, Terraform and containers.

####Structuring a Terraform configuration

In a production environment one should probably use multiple files to describe the infrastructure.

##Troubleshooting

```
diffs didn't match during apply. This is a bug with Terraform and should be reported
```

`->` delete the `terraform.tfstate*` file(s).
