# QuietChatter Infrastructure

This repository contains the Terraform-based Infrastructure as Code (IaC) for the quietchatter-project.

## Architecture Overview

The infrastructure is designed for a cost-effective Microservices Architecture (MSA) on AWS, focusing on minimizing operational costs by using ARM-based instances and consolidating persistence layers.

### Key Design Principles

1. Cost Efficiency:
    - Exclusively uses AWS t4g (ARM) series instances.
    - Uses a custom NAT Instance instead of a managed AWS NAT Gateway.
    - Consolidates PostgreSQL, Redpanda (Kafka replacement), and Redis onto a single Persistence Node.
2. Network Security:
    - VPC with Public and Private subnets.
    - All API nodes and databases are located in Private Subnets.
    - Ingress traffic is managed via an NGINX Reverse Proxy on the NAT instance in the public subnet.
3. Scalability:
    - Provisions 2 Public and 2 Private subnets across multiple Availability Zones (though initially only one set is actively used).

## Infrastructure Components

| Component | Instance Type | Location | Description |
| :--- | :--- | :--- | :--- |
| NAT / Ingress Node | t4g.nano | Public Subnet | Performs NAT for private subnets and runs NGINX for ingress routing. |
| API Gateway Node | t4g.micro | Private Subnet | Main entry point for microservices, receives traffic from NGINX. |
| Persistence Node | t4g.small | Private Subnet | Consolidated node running PostgreSQL, Redpanda, and Redis. |
| Microservices | t4g.micro | Private Subnet | Individual nodes for microservice-book, microservice-user, etc. |

## Project Structure

```text
infrastructure/
├── providers.tf       # AWS provider configuration
├── variables.tf       # Region and CIDR definitions
├── vpc.tf             # VPC, Subnets, and Routing
├── nat_ingress.tf     # NAT & NGINX Ingress Instance setup
├── security.tf        # Security Groups (Firewall rules)
├── api_gateway.tf     # API Gateway Instance setup
├── persistence.tf     # Consolidated Data Store Node setup
└── outputs.tf         # Useful resource IDs and IPs
```

## How to Validate

To check the syntax and see the execution plan without deploying:

```bash
# Initialize Terraform
terraform init

# Check syntax
terraform validate

# View the execution plan
terraform plan
```

Note: This repository is intended for infrastructure documentation and architectural validation. Actual deployment should be handled with caution.
