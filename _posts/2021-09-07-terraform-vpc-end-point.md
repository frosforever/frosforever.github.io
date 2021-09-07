---
layout: post
title: "Terraform tips: Setting up cross account VPC endpoint service"
description: "Use client VPC endpoint for subnet AZ resolution"
---

I've recently been working a lot more with Terraform to stand up infrastructure in a multi AWS account environment. There are a number of assorted tips I'm collecting more as notes to myself than anything else. Perhaps it may be useful to someone else as well.

## Introduction

Sharing a VPC endpoint service across AWS accounts may cause an issue with corresponding subnet AZs not translating to the same actual AZ. That is, one AWS account's `us-east-1a` might not be the same physical underlying AZ as another's `us-east-1a` (and might perhaps be that account's `us-east-1b` for example).

### Server account

We start with 2 AWS providers, one for the server account and one for the client. Details on setting up the providers to use different account elided:

{% highlight terraform %}
provider "aws" {
  alias = "server"
}

data "aws_caller_identity" "server" {
  provider = aws.server
}

provider "aws" {
  alias = "client"
}

data "aws_caller_identity" "client" {
  provider = aws.client
}
{% endhighlight %}

In the `server` account we set a network load balancer that's placed in its `us-east-1a` and `us-east-1b` subnets, create a VPC endpoint service and allow the client account access to it:

{% highlight terraform %}
resource "aws_lb" "service" {
  name               = "Service-Privatelink"
  internal           = true
  load_balancer_type = "network"

  subnets = [
    data.aws_subnet.server["us_east_1a"].id,
    data.aws_subnet.server["us_east_1b"].id
  ]

  provider = aws.server
}

resource "aws_vpc_endpoint_service" "service" {
  acceptance_required        = true
  network_load_balancer_arns = [aws_lb.service.arn]

  provider = aws.server
}

resource "aws_vpc_endpoint_service_allowed_principal" "service_to_client" {
  vpc_endpoint_service_id = aws_vpc_endpoint_service.service.id
  principal_arn           = "arn:aws:iam::${data.aws_caller_identity.client.account_id}:root"

  provider = aws.server
}
{% endhighlight %}

### Client account

Next in the client account we attempt to create the `aws_vpc_endpoint` in the client's subnets that are in the same AZs as the service's NLB:
{% highlight terraform %}
resource "aws_vpc_endpoint" "service" {
  vpc_id            = aws_vpc.client.id
  service_name      = aws_vpc_endpoint_service.service.service_name
  vpc_endpoint_type = "Interface"

  subnet_ids = [
    data.aws_subnet.client["us_east_1a"].id,
    data.aws_subnet.client["us_east_1b"].id,
  ]

  provider = aws.client
}
{% endhighlight %}

However this may fail! AZ `us-east-1a` in the server account may not be the same as `us-east-1a` in the client account. For more details see this helpful [AWS support page](https://aws.amazon.com/premiumsupport/knowledge-center/interface-endpoint-availability-zone/) for more details on this.

## Solution

Instead we must find the service in the client account and use the AZs from _that_ `data.aws_vpc_endpoint_service` to attach the `aws_vpc_endpoint` to the same corresponding subnet:

{% highlight terraform %}
data "aws_vpc_endpoint_service" "service" {
  service_name      = aws_vpc_endpoint_service.service.service_name

  provider = aws.client
}

resource "aws_vpc_endpoint" "service" {
  vpc_id            = aws_vpc.client.id
  service_name      = aws_vpc_endpoint_service.service.service_name
  vpc_endpoint_type = "Interface"

  # Loop through available subnets and find the ones that correspond to the service's AZs
  subnet_ids = [
    for _, subnet in data.aws_subnet.client : subnet.id
    if contains(data.aws_vpc_endpoint_service.service.availability_zones, subnet.availability_zone)
  ]

  provider = aws.client
}
{% endhighlight %}
