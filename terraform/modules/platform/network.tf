resource "aws_vpc" "this" {
  count                = var.enable_aws_resources ? 1 : 0
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${local.name}-vpc" }
}

resource "aws_internet_gateway" "this" {
  count  = var.enable_aws_resources ? 1 : 0
  vpc_id = aws_vpc.this[0].id

  tags = { Name = "${local.name}-igw" }
}

resource "aws_subnet" "public" {
  count                   = var.enable_aws_resources ? length(var.availability_zone_suffixes) : 0
  vpc_id                  = aws_vpc.this[0].id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = "${var.aws_region}${var.availability_zone_suffixes[count.index]}"
  map_public_ip_on_launch = false

  tags = { Name = "${local.name}-public-${count.index + 1}" }
}

resource "aws_subnet" "private" {
  count             = var.enable_aws_resources ? length(var.availability_zone_suffixes) : 0
  vpc_id            = aws_vpc.this[0].id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  availability_zone = "${var.aws_region}${var.availability_zone_suffixes[count.index]}"

  tags = { Name = "${local.name}-private-${count.index + 1}" }
}

resource "aws_route_table" "public" {
  count  = var.enable_aws_resources ? 1 : 0
  vpc_id = aws_vpc.this[0].id

  tags = { Name = "${local.name}-public" }
}

resource "aws_route" "public_internet" {
  count                  = var.enable_aws_resources ? 1 : 0
  route_table_id         = aws_route_table.public[0].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this[0].id
}

resource "aws_route_table_association" "public" {
  count          = var.enable_aws_resources ? length(aws_subnet.public) : 0
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[0].id
}

resource "aws_eip" "nat" {
  count  = var.enable_aws_resources && var.enable_nat_gateway ? var.nat_gateway_count : 0
  domain = "vpc"

  depends_on = [aws_internet_gateway.this]
  tags       = { Name = "${local.name}-nat-${count.index + 1}" }
}

resource "aws_nat_gateway" "this" {
  count         = var.enable_aws_resources && var.enable_nat_gateway ? var.nat_gateway_count : 0
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  depends_on = [aws_internet_gateway.this]
  tags       = { Name = "${local.name}-nat-${count.index + 1}" }
}

resource "aws_route_table" "private" {
  count  = var.enable_aws_resources ? length(var.availability_zone_suffixes) : 0
  vpc_id = aws_vpc.this[0].id

  tags = { Name = "${local.name}-private-${count.index + 1}" }
}

resource "aws_route" "private_nat" {
  count                  = var.enable_aws_resources && var.enable_nat_gateway ? length(aws_route_table.private) : 0
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[min(count.index, length(aws_nat_gateway.this) - 1)].id
}

resource "aws_route_table_association" "private" {
  count          = var.enable_aws_resources ? length(aws_subnet.private) : 0
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

resource "aws_security_group" "public_alb" {
  count       = var.enable_aws_resources ? 1 : 0
  name        = "${local.name}-public-alb"
  description = "Approved traffic to the public Backend ALB"
  vpc_id      = aws_vpc.this[0].id

  tags = { Name = "${local.name}-public-alb" }
}

resource "aws_vpc_security_group_ingress_rule" "public_alb" {
  for_each = var.enable_aws_resources ? toset(var.backend_ingress_cidrs) : toset([])

  security_group_id = aws_security_group.public_alb[0].id
  description       = "Approved Backend client"
  cidr_ipv4         = each.value
  from_port         = local.backend_listener_port
  to_port           = local.backend_listener_port
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "public_alb" {
  count = var.enable_aws_resources ? 1 : 0

  security_group_id            = aws_security_group.public_alb[0].id
  referenced_security_group_id = aws_security_group.backend[0].id
  from_port                    = local.backend_port
  to_port                      = local.backend_port
  ip_protocol                  = "tcp"
}

resource "aws_security_group" "backend" {
  count       = var.enable_aws_resources ? 1 : 0
  name        = "${local.name}-backend"
  description = "Spring Boot task traffic"
  vpc_id      = aws_vpc.this[0].id

  tags = { Name = "${local.name}-backend" }
}

resource "aws_vpc_security_group_ingress_rule" "backend_from_alb" {
  count = var.enable_aws_resources ? 1 : 0

  security_group_id            = aws_security_group.backend[0].id
  referenced_security_group_id = aws_security_group.public_alb[0].id
  from_port                    = local.backend_port
  to_port                      = local.backend_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "backend" {
  count = var.enable_aws_resources ? 1 : 0

  security_group_id = aws_security_group.backend[0].id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_security_group" "internal_alb" {
  count       = var.enable_aws_resources ? 1 : 0
  name        = "${local.name}-internal-alb"
  description = "Backend-only traffic to the internal AI Server ALB"
  vpc_id      = aws_vpc.this[0].id

  tags = { Name = "${local.name}-internal-alb" }
}

resource "aws_vpc_security_group_ingress_rule" "internal_alb_from_backend" {
  count = var.enable_aws_resources ? 1 : 0

  security_group_id            = aws_security_group.internal_alb[0].id
  referenced_security_group_id = aws_security_group.backend[0].id
  from_port                    = local.aiserver_port
  to_port                      = local.aiserver_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "internal_alb" {
  count = var.enable_aws_resources ? 1 : 0

  security_group_id            = aws_security_group.internal_alb[0].id
  referenced_security_group_id = aws_security_group.aiserver[0].id
  from_port                    = local.aiserver_port
  to_port                      = local.aiserver_port
  ip_protocol                  = "tcp"
}

resource "aws_security_group" "aiserver" {
  count       = var.enable_aws_resources ? 1 : 0
  name        = "${local.name}-aiserver"
  description = "FastAPI task traffic"
  vpc_id      = aws_vpc.this[0].id

  tags = { Name = "${local.name}-aiserver" }
}

resource "aws_vpc_security_group_ingress_rule" "aiserver_from_alb" {
  count = var.enable_aws_resources ? 1 : 0

  security_group_id            = aws_security_group.aiserver[0].id
  referenced_security_group_id = aws_security_group.internal_alb[0].id
  from_port                    = local.aiserver_port
  to_port                      = local.aiserver_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "aiserver" {
  count = var.enable_aws_resources ? 1 : 0

  security_group_id = aws_security_group.aiserver[0].id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_security_group" "database" {
  count       = var.enable_aws_resources ? 1 : 0
  name        = "${local.name}-database"
  description = "PostgreSQL access from isolated application services"
  vpc_id      = aws_vpc.this[0].id

  tags = { Name = "${local.name}-database" }
}

resource "aws_vpc_security_group_ingress_rule" "database_from_backend" {
  count = var.enable_aws_resources ? 1 : 0

  security_group_id            = aws_security_group.database[0].id
  referenced_security_group_id = aws_security_group.backend[0].id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "database_from_aiserver" {
  count = var.enable_aws_resources ? 1 : 0

  security_group_id            = aws_security_group.database[0].id
  referenced_security_group_id = aws_security_group.aiserver[0].id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
}
