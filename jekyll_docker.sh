#!/bin/bash -eu

# For mac to set docker env:
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

echo "******************

See site at: http://$DOCKER_IP:4000

************************"

docker run --rm -it --label=jekyll --label=pages --volume=`pwd`:/srv/jekyll -p 4000:4000 jekyll/jekyll:pages jekyll serve --force_polling --drafts
