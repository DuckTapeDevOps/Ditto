// Spin up a single ECS Cluster and service with no load balancer
resource "aws_ecs_cluster" "multitwitch-api" {
  name = "${var.service_name}-cluster"
}

resource "aws_ecs_service" "multitwitch-api" {
  name            = "${var.service_name}-service"
  cluster         = aws_ecs_cluster.multitwitch-api.id
  launch_type     = "FARGATE"
  task_definition = aws_ecs_task_definition.multitwitch-api.arn
  desired_count   = 1

  load_balancer {
   target_group_arn = aws_alb_target_group.main.arn
   container_name   = "${var.service_name}"
   container_port   = var.container_port
 }

  network_configuration {
    subnets = [aws_subnet.private_a.id, aws_subnet.private_b.id]
    security_groups = [aws_security_group.zero_ingress.id]
    assign_public_ip = true //TODO: This fixed the Secrets Manager Issue
  }

  depends_on      = [aws_iam_role.demo_api_task_execution_role]
}

resource "aws_ecs_task_definition" "multitwitch-api" {
  family = "${var.service_name}-family"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn = aws_iam_role.demo_api_task_execution_role.arn
  task_role_arn =  aws_iam_role.task_role.arn
  network_mode = "awsvpc"
  cpu = 512
  memory = 1024
  container_definitions = jsonencode([
    {
      name      = var.service_name
      image     = var.api_image_url
      cpu       = 256
      memory    = 512
      essential = true
      logConfiguration = {
      logDriver = "awslogs",
      portMappings = [{
        protocol      = "tcp"
        containerPort = var.container_port
        hostPort      = var.container_port
      }]
      options = {
        awslogs-group = aws_cloudwatch_log_group.multitwitch-api.name ,
        awslogs-region = var.region,
        awslogs-stream-prefix = var.service_name
      }
    }
    }
  ])
}


// Creates the log group for fargate logs
resource "aws_cloudwatch_log_group" "multitwitch-api" {
  name = "/ecs/fargate_log_group/${var.service_name}"
}
