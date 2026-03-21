# Import pre-existing resources into Terraform state.
#
# Add import blocks here only for resources that already exist in AWS
# and need to be brought under Terraform management.
# Remove an import block once the resource is successfully in state.

import {
  to = module.alb_asg.aws_autoscaling_group.web
  id = "prod-web-asg"
}


