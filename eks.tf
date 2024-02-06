resource "aws_vpc" "example" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.example.id
}


resource "aws_route_table" "private-subnet-route-table" {
  vpc_id = aws_vpc.example.id
  route {
     gateway_id = aws_internet_gateway.igw.id
     cidr_block     = "0.0.0.0/0"
  }
}
resource "aws_route_table_association" "association1" {
  subnet_id      = aws_subnet.example1.id
  route_table_id = aws_route_table.private-subnet-route-table.id
}
resource "aws_route_table_association" "association2" {
  subnet_id      = aws_subnet.example2.id
  route_table_id = aws_route_table.private-subnet-route-table.id
}

resource "aws_subnet" "example1" {
  vpc_id            = aws_vpc.example.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-northeast-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "example2" {
  vpc_id            = aws_vpc.example.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-northeast-1c"
  map_public_ip_on_launch = true
}



resource "aws_eks_cluster" "example" {
  name     = "my-cluster"
  role_arn = aws_iam_role.example.arn

  enabled_cluster_log_types = ["api", "audit"]

  vpc_config {
    subnet_ids = [aws_subnet.example1.id, aws_subnet.example2.id]
  }

  access_config {
    authentication_mode                         = "CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.example-AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.example-AmazonEKSServicePolicy,
    aws_cloudwatch_log_group.example
  ]

   
}


resource "aws_iam_role" "example" {
  name = "eksClusterRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "example-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.example.name
}

resource "aws_iam_role_policy_attachment" "example-AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.example.name
}

resource "aws_iam_role_policy_attachment" "example-AmazonEKSVPCResourceController" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.example.name
}

resource "aws_cloudwatch_log_group" "example" {
  name              = "/aws/eks/my-cluster/cluster"
  retention_in_days = 7

}


resource "aws_iam_role" "eks_node_group_role" {
  name = "eks-node-group-example"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "example-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_group_role.name
}

resource "aws_iam_role_policy_attachment" "example-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_group_role.name
}

resource "aws_iam_role_policy_attachment" "example-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_group_role.name
}

resource "aws_eks_node_group" "example" {
  cluster_name    = aws_eks_cluster.example.name 
  node_group_name = "example-node-group"
  node_role_arn = aws_iam_role.eks_node_group_role.arn

  subnet_ids = [
   aws_subnet.example1.id, aws_subnet.example2.id
  ]

  capacity_type = "ON_DEMAND" # 或 "SPOT"，根据需求选择

  scaling_config {
    desired_size = 1
    min_size = 1
    max_size = 2
  }
}

