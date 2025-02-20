---
layout: post
title: "Safely adding apt repo keys"
description: "How to safely add keys for use with third party apt repos"
---

When adding third party repos to `apt` we must also add the remote repo's keys to be trusted. However, the long standing method of using `apt-key adv --recv-keys` is now deprecated as it allows the added key to be used for _all_ repos and not just the single third party one that we'd like to add. 

Here's an alternative method that should isolate the key per repo. We'll take adding [ubuntu packages for R](https://cran.r-project.org/bin/linux/ubuntu/fullREADME.html) as an example.

Previous unsafe way. Do not use:

{% highlight shell %}
# Fetch the key by ID and add to apt as a trusted key. This will throw a deprecation warning
apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys E298A3A825C0D65DFD57CBB651716619E084DAB9

# Add the debian repo to apt sources
echo "deb https://cloud.r-project.org/bin/linux/ubuntu jammy-cran40/" | tee /etc/apt/sources.list.d/cran-cloudr.list

# Install as you normally would
apt-get update && apt-get install -y r-base-core 
{% endhighlight %}

Updated safer way:

{% highlight shell %}
# Use gpg to fetch the repo key
gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys E298A3A825C0D65DFD57CBB651716619E084DAB9

# Export the key to a file that can be referenced
gpg --export E298A3A825C0D65DFD57CBB651716619E084DAB9 > /etc/apt/keyrings/cran-cloudr.gpg

# At this point we no longer need the key on our keyring and can optionally remove it
gpg --batch --delete-keys --yes E298A3A825C0D65DFD57CBB651716619E084DAB9

# Add the debian repo with its signing key to apt sources
echo "deb [signed-by=/etc/apt/keyrings/cran-cloudr.gpg] https://cloud.r-project.org/bin/linux/ubuntu jammy-cran40/" | tee /etc/apt/sources.list.d/cran-cloudr.list

# Install as you normally would
apt-get update && apt-get install -y r-base-core 
{% endhighlight %}
