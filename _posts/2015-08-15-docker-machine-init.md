---
layout: post
title: "Scripting docker-machine init"
# date:   2015-05-18 17:49:00
description: "Setting up docker-machine env vars for use in a shell script"
---

When using a non Linux machine, Docker can not run locally and must instead be run in a VM. For windows and mac systems this was done via `boot2docker` that would launch a VM in Virtualbox, and provided some env vars via `$(boot2docker shellinit)` so that interaction with the docker daemon in the VM was as seamless as possible. When running docker in a shell script, the env vars could be initialized[^boot2dockerscript]:

[^boot2dockerscript]: http://sosedoff.com/2015/05/19/boot2docker-autoexport.html

{% highlight bash %}
if [ $(hash boot2docker 2>/dev/null ; echo $?) -eq 0 ]
then
  if [ $(ps aux | grep [b]oot2docker-vm -c) -eq 1 ]
  then
    echo "Boot2Docker is running. Loading shell init scripts automatically."
    $(boot2docker shellinit 2>/dev/null)
  fi
fi
{% endhighlight %}

As of docker 1.8, `boot2docker` is deprecated in favor of the more general `docker-machine`. To automate env var initialization so that docker commands can be used in a script I've been using

{% highlight bash %}
if [ $(hash docker-machine 2>/dev/null ; echo $?) -eq 0 ]
then
  DOCKER_MACHINE_NAME=$(docker-machine ls --filter driver=virtualbox --filter state=Running -q)
  if [ -z "$DOCKER_MACHINE_NAME" ]
  then
    echo "docker-machine doesn't seem to be running or has no loaded machines. Perhaps run:
    docker-machine start ..."
    exit 1
  else
    echo "docker-machine is running. Loading shell init scripts automatically."
    eval "$(docker-machine env $DOCKER_MACHINE_NAME 2>/dev/null)"
    DOCKER_IP=$(docker-machine ip $DOCKER_MACHINE_NAME)
  fi
else
  echo "docker-machine can not be found. Attempting to use local docker host"
  DOCKER_IP=127.0.0.1
fi

docker ps
{% endhighlight %}

Unlike with `boot2docker` we do not know what the VM might be named to check if it's running. Instead we use `docker-machine ls` to find a running virtualbox VM and grab its name for future use. This can easily be extended to check if the virtualbox VM is simply not running and automatically boot it or even use a different docker-machine driver all together.

You can find an example of this in action in the [source for this blog](https://github.com/frosforever/frosforever.github.io/blob/master/jekyll_docker.sh).

