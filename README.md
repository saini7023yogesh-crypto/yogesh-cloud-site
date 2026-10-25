# Portfolio site on AWS, built with Terraform

A personal portfolio website hosted on AWS and managed entirely as code. It is my first hands-on cloud project, built after earning the AWS Certified Solutions Architect - Associate (SAA-C03) certification.

**Live site:** https://d2aldzz2qp5mzd.cloudfront.net

## Architecture

    Visitor -> CloudFront (HTTPS) -> private S3 bucket

- The S3 bucket is private (Block Public Access is on).
- CloudFront reads the bucket through Origin Access Control (OAC).
- A bucket policy allows only this one CloudFront distribution to read objects.
- Terraform state is stored in a separate, versioned S3 bucket with state locking.
- GitHub Actions validates the Terraform code on every push.

## What is in this repo

| Path | Purpose |
|---|---|
| main.tf | S3, CloudFront, OAC, bucket policy, and the page upload |
| site/index.html | The website |
| .github/workflows/ci.yml | CI: terraform fmt and validate |
| .gitignore | Keeps state files and secrets out of Git |

## Tools used

AWS (S3, CloudFront, IAM), Terraform, Git and GitHub, GitHub Actions, AWS CLI.

## How to deploy

    aws configure
    terraform init
    terraform plan
    terraform apply

To remove everything and stop all cost:

    terraform destroy

## Problems I ran into and how I solved them

| Problem | Cause | Fix |
|---|---|---|
| AccessDenied from CloudFront | Missing default root object and OAC setup | Set index.html as root object, attached OAC and bucket policy |
| Page shown as plain text | Wrong Content-Type on the object | Set content_type to text/html in Terraform |
| S3 CreateBucket denied | Organization Service Control Policy blocked the region | Read the error, switched to an allowed region (eu-north-1) |
| OIDC provider creation denied | Same SCP blocked iam:CreateOpenIDConnectProvider | Built CI that needs no AWS keys (fmt and validate only) |
| 301 error after changing region | Terraform default region did not match where the bucket lived | Fixed the default region in main.tf |

## Security notes

- No access keys or state files are stored in this repo.
- Terraform runs under an IAM user, not the root account.
- The bucket is never public.

## What I would add next

- Automated deploy through GitHub Actions (needs OIDC, which my account's policy currently blocks)
- Custom domain with Route 53 and ACM
- A second project: a multi-tier VPC