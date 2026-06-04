# Terraform Reflection

One thing the Terraform plan caught that I might have missed clicking through the console was the exact inbound access required by the app. The Go service listens on TCP port 4444, and the security group now declares that rule next to the SSH rule Jenkins needs for deployment. In the console, it would be easy to launch the EC2 instance and forget the app port until `curl` hangs.

One thing that was more annoying in Terraform than in the console was wiring the SSH key pair. In the console, selecting or creating a key pair is a guided step; in Terraform, I had to pass the public half of the Jenkins deploy key as a variable so AWS can create `aws_key_pair` while Jenkins keeps using the matching private key credential.
