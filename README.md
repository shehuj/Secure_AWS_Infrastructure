# Secure_AWS_Infrastructure
secure AWS Infrastructure with Terraform, Ansible and github actions

prod-infra/
├── .github/
│   └── workflows/
│       ├── terraform-plan.yml
│       ├── terraform-apply.yml
│       └── ansible-deploy.yml
├── terraform/
│   ├── backend.tf
│   ├── provider.tf
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── modules/
│       ├── vpc/
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       ├── ec2/
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       └── oidc_role/
│           ├── main.tf
│           ├── variables.tf
│           └── outputs.tf
├── ansible/
│   ├── inventory/
│   │   └── aws_ec2.yml
│   ├── playbooks/
│   │   └── webserver.yml
│   └── ansible.cfg
├── README.md
└── .gitignore