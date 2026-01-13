---
layout: post
title: "Add custom certs to Rancher Desktop"
description: "How to safely add keys for use with third party apt repos"
---

When using Rancher Desktop on MacOS, it seems like different commands may or may not leverage the host's certificate store. For example, `nerdctl pull` seems to use the host certs, but `nerdctl build` does not.

Rancher Desktop runs a LIMA Linux VM under the hood, custom certs can then be added to it via config files.

## Adding custom certs to Rancher Desktop's LIMA VM
1. Locate or create the config file for Rancher Desktop's LIMA VM. At the time of writing, https://docs.rancherdesktop.io/how-to-guides/provisioning-scripts states it is at `~/Library/Application\ Support/rancher-desktop/lima/_config/override.yaml` on MacOS.
2. Edit or create the file to include a section that adds your custom cert. For example:
   {% highlight yaml %}
   provision:
   - mode: system
     script: |
     #!/bin/sh
     set -o errexit -o nounset -o xtrace

     # Create the custom certificate file
     cat > /usr/local/share/ca-certificates/custom-cert.pem << 'EOF'
     -----BEGIN CERTIFICATE-----
     ... your custom cert content here ...
     -----END CERTIFICATE-----
     EOF

     # Update the certificate store
     /usr/sbin/update-ca-certificates
   {% endhighlight %}

This will run on every Rancher Desktop VM start and ensure the custom cert is added to the VM system's certificates.
