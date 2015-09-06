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
* *[Packer](https://packer.io/)*:
* *[Terraform](https://terraform.io/)*:
* *[Atlas](https://atlas.hashicorp.com/)*:

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

##Component

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

**Prerequisits**

*To give you an easy start I've created four individual docker images, one for each service from above: webpage, json api, upload service, company slackbot*

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


