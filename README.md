# Three tier app demo

This simply demo creates an AWS environment that contains:

  * A datastore
    * Using RDS Postgres database
    * Limited to intra CIDR block for access
  * A service that talks to a database - an EKS cluster
    * Using private networks for the worker nodes and cluster itself
  * Allows access for an external request - an ALB using the [ALB Ingress Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.3/)
    * Leveraging annotations to determine if it should be an internal or external ALB

With using [Terraform](https://www.terraform.io/)

In the end, it looks something like this

![Three Tier Image](/images/ThreeTier.svg)

## Gitpod

Opening this in Gitpod will get your Terraform init ran and tflint up and running

[![Open in Gitpod](https://gitpod.io/button/open-in-gitpod.svg)](https://gitpod.io/#https://github.com/martyjhenderson/three-tier)
