# Terraform Reflection

One thing the Terraform plan caught that I might have missed clicking through the console was the exact inbound access required by the app. The Go service listens on TCP port 4444, and the security group now declares that rule next to the SSH rule Jenkins needs for deployment. In the console, it would be easy to launch the EC2 instance and forget the app port until `curl` hangs.

One thing that was more annoying in Terraform than in the console was wiring the SSH key pair. In the console, selecting or creating a key pair is a guided step; in Terraform, I had to pass the public half of the Jenkins deploy key as a variable so AWS can create `aws_key_pair` while Jenkins keeps using the matching private key credential.

## Security Group Lockdown

A concrete failure mode enabled by allowing SSH from `0.0.0.0/0` is automated brute-force traffic against port 22 from the public internet. Even if the instance only accepts key-based login, every exposed SSH daemon becomes a target for credential stuffing, vulnerability scans, and log noise that can hide a real attack.

The inconvenience introduced by the narrower rule is that SSH and Jenkins deploys only work from the allowed public IP. If my laptop or Jenkins agent moves to a different network, Terraform has to update `ssh_cidr_blocks` before I can connect or deploy again.
