# Import pre-existing resources into Terraform state.
#
# Add import blocks here only for resources that already exist in AWS
# and need to be brought under Terraform management.
# Remove an import block once the resource is successfully in state.

import {
  to = module.vpc.aws_cloudwatch_log_group.vpc_flow_logs[0]
  id = "/aws/vpc/${var.environment}-flow-logs"
}

import {
  to = module.alb_asg.aws_autoscaling_group.web
  id = "${var.environment}-web-asg"
}
