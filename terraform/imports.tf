# Import pre-existing resources into Terraform state.
#
# These blocks are no-ops when the resource is already in state, so they are
# safe to leave permanently. They prevent ResourceAlreadyExistsException on
# apply when a resource was created outside of the current state (e.g. by a
# prior deploy that lost its state, or by manual creation).

import {
  to = module.monitoring.aws_cloudwatch_log_group.nginx_access
  id = "/aws/ec2/${var.environment}/nginx/access"
}

import {
  to = module.monitoring.aws_cloudwatch_log_group.nginx_error
  id = "/aws/ec2/${var.environment}/nginx/error"
}
