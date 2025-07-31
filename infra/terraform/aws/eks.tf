#
# QuantumArb 2.0 - Terraform AWS EKS Cluster
#
# File: infra/terraform/aws/eks.tf
#
# Description:
# This Terraform configuration provisions an Amazon EKS (Elastic Kubernetes Service)
# cluster within the VPC created in main.tf.
#
# This setup includes:
# - An IAM Role for the EKS Cluster itself to manage AWS resources.
# - An IAM Role for the EKS Worker Nodes to allow them to join the cluster.
# - The EKS Cluster control plane.
# - A managed Node Group, which are the EC2 instances that will run our pods.
#   These nodes are placed in the private subnets for security.
#

# --- 1. IAM Role for EKS Cluster ---
resource "aws_iam_role" "eks_cluster_role" {
  name = "QuantumArb-EKS-ClusterRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

# --- 2. IAM Role for EKS Worker Nodes ---
resource "aws_iam_role" "eks_node_role" {
  name = "QuantumArb-EKS-NodeRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

# Attach required policies for worker nodes
resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "ec2_container_registry_read_only" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_role.name
}


# --- 3. EKS Cluster ---
resource "aws_eks_cluster" "quantum_arb_cluster" {
  name     = "QuantumArb-Cluster"
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    # The cluster control plane will be able to communicate with pods in these subnets
    subnet_ids = [aws_subnet.private_subnet_1.id, aws_subnet.public_subnet_1.id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
  ]

  tags = {
    Name = "QuantumArb-EKS-Cluster"
  }
}

# --- 4. EKS Managed Node Group ---
# These are the EC2 instances that will run our containerized applications (pods).
resource "aws_eks_node_group" "private_nodes" {
  cluster_name    = aws_eks_cluster.quantum_arb_cluster.name
  node_group_name = "QuantumArb-PrivateNodes"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  # Place worker nodes in the private subnet for security
  subnet_ids      = [aws_subnet.private_subnet_1.id]

  # For HFT, selecting compute-optimized instances is crucial.
  # c5n instances are optimized for networking.
  instance_types = ["c5n.large"]

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  update_config {
    max_unavailable = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.ec2_container_registry_read_only,
  ]

  tags = {
    Name = "QuantumArb-EKS-WorkerNode"
  }
}
