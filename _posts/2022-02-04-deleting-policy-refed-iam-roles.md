---
layout: post
title: "Careful deleting an IAM role referenced in resource based policies"
description: "Deleting and replacing an IAM role with the same name can have unexpected behavior in resource based policies"
---

Deleting an IAM role causes its references in policies to be replaced by by its RoleID.
This may cause an issue if one expects a new role with the same name to work with the existing polices.

## Details

We have a role name "Foo" referenced in a resource based policy (S3, Secrets etc) via its  ARN of `arn:aws:iam::123456789012:role/Foo`. If the role is deleted, the resource based policy will be updated to reference the role's ID instead of its ARN. If a new role is created with the same name `Foo`, the policy will not apply to it even though the ARN is the same! Instead the policy must be updated to once again reference the ARN.    
