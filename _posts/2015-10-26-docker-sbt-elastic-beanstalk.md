---
layout: post
title: "Deploying docker based applications to elastic beanstalk from sbt-native-packager"
description: "Ensure that zipped docker native packagers run scripts have runnable permissions in the docker container"
---

# Introduction

AWS elastic beanstalk has been able to run [docker based applications](https://docs.aws.amazon.com/elasticbeanstalk/latest/dg/create_deploy_docker.html). Containers can either be pulled from a docker repository, after being built elsewhere, or based on an archive containing a Dockerfile and its associated files. The docker image is then build by the docker daemon on the elastic beanstalk service.

Using [sbt native packager](https://github.com/sbt/sbt-native-packager), one can deploy scala applications from sbt to a docker image. If using a docker repository to deploy to elastic beanstalk, one can simply use `docker:publish` to build and publish the image and then instruct elastic beanstalk to grab the image. You can also deploy the image by running `docker:stage`, creating a zip archive containing the created Dockerfile, files, a `Dockerrun.aws.json` and any other required extension configurations.

# The issue

The problem is native packager leverages a bash run script that's added to the docker image. There is a known issue that files can loose their runnable permission in a zip archive ([here](https://stackoverflow.com/questions/13185364/how-to-assign-execute-permission-to-a-sh-file-in-windows-to-be-executed-in-linu) [here](https://stackoverflow.com/questions/10735297/maintain-file-and-folder-permissions-inside-archives) and [here](https://superuser.com/questions/603068/unzipping-file-whilst-getting-correct-permissions)) When creating the zip bundle, the shell script will lose its runnable permission and the image will fail in elastic beanstalk.

# The solution

We want to ensure that the run script has execute permissions before we attempt to run it. We want to add the following to our Dockerfile before the `ENTRYPOINT` and `CMD` is run
{% highlight bash %}
RUN chmod +x runscript.sh
{% endhighlight %}

To do this we will modify the dockerfile created by native packager by flatMapping over the `dockerCommands` in `build.sbt` and adding the `chmod` before the `ENTRYPOINT` as follows:

{% highlight scala %}
dockerCommands <<= (dockerCommands, dockerEntrypoint) map { (com, ent) =>
  com.flatMap {
    case e : ExecCmd if e.cmd == "ENTRYPOINT" =>
      val chmodCommand = Seq("chmod", "+x") ++ ent
      Seq(ExecCmd("RUN", chmodCommand: _*), e)
    case e => Seq(e)
  }
}
{% endhighlight %}

Breaking that down, we flatMap over the existing `dockerCommands` and when we hit the `ENTRYPOINT` command, we insert another command before it that runs `chmod` on the `dockerEntrypoint`. Note that we don't hard code the run script itself, we simply depend on whatever it is set as.
