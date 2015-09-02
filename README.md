# A 100% codified, scaling (Micro-)Service-Oriented-Architecture (SOA) with docker, Packer, Terraform and Atlas

Fair enough, enough with the buzzword-bingo but seriously, this post will be buzzword *packed*.
And that's O.K. since docker, Packer, Terraform and Atlas are simply great.
Props to the [HASHICORP](https://hashicorp.com/) team for creating these amazing tools.

_Disclaimer: I'm not a DevOps master nor ninja. Please, do not take everything as a best practice._

##Introduction

One sentence _What Is?_:

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
 ┌──────────────────┐  Packer              
 │     2. Build     │  Atlas               
 └──────────────────┘                      
           │                               
           ▼                               
 ┌ ─ ─ ─ ─ ┼ ─ ─ ─ ─                       
    Infrastructure  │  Terraform           
 └ ─ ─ ─ ─ ┼ ─ ─ ─ ─                       
                                           
           ▼                               
 ┌──────────────────┐  docker              
 │    3. Deploy     │  Terraform           
 └──────────────────┘                      
```

##Component

We'll build a two cluster, 4 service, scaled "web-application / service".
The services could be build with any technology and because we're using docker
it really would not change *anything*.

*Terminilogy:*

* ELB = Elastic Load Balancer
* ECS = Elastic Cloud Service
* ECS (Cluster) = A Cluster orchestrated by ECS
* Instance = An EC2 Instance
* Service = A ECS Cluster service
* EBS Volume = Elastic Block Storage Volume

###The (m)SOA

* ELB (s A.x) -> www.ourwebapp.com (HTML Webpage)
* ELB (s A.y) -> api.ourwebapp.com (JSON API)
* ELB (s B.u) -> upload.ourwebapp.com (Upload Service)
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

Enough with the theory, let's dive into some code. We'll begin with the
codification of our AWS infrastructure with Terraform.
