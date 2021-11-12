# What is this?
An abomination.

This Docker container allows running full blown LXC containers inside Docker. Why you would do this is up to you. I just hope you really know what you are doing. Usually it's the other way round but if all you got is a docker enabled host, then this is your solution. (Or your demise)

# Word of warning
Docker is not meant to run single applications per container. Running an entire Linux inside a container is exactly not what Docker was meant for. However that doesn't mean that you can't. I actually know surprisingly little about cgroups and namespaces, which are used by both Docker and LXC to provide isolation. The container itself must be run with `--privileged` and needs `-v /sys/fs/cgroup:/sys/fs/cgroup:ro` mounted (I don't know why, but systemd really hates it if you don't). The internet will tell you that you should never run your containers with `--privileged`. Certain payloads will require privileged permissions to function. LXC is one of them. You can read up on the implications yourself.

It is important to note that the actual LXC container is NOT in a privileged state. Only the LXC wrapper needs to be privileged, the lxc container is run unprivileged with an actual user id different from `0`. From my understanding, this makes the LXC container itself as powerfull as any other docker container, IF we ignore the possibility of someone taking over the wrapper somehow.

I don't know how accurate these assumptions are. If you are more experienced with cgroups and namespaces, tell me please. Otherwise, use at your own risk.

# Instructions
I believe that if you are going to use this piece of art, you will know how to make use of it. There are currently a few things missing, like automatic SSH key deployment and proper network setup for probably a lot of LXC images. Documentation is coming! (In case the last commit is multiple years old: It's not coming, sorry)

In the meantime, take this basic example which should hopefully net you a Ubuntu container
```bash
docker build -t lxcatastrophe:latest
docker run --privileged \
	-v /sys/fs/cgroup:/sys/fs/cgroup:ro \
	-e "DIST_NAME=ubuntu" -e "DIST_FLAVOUR=edge" \
	lxcatastrophe:latest
```

# Technical details
Technically, this image contains a wrapper which will simply call `lxc-create` to create a preconfigured container and run it as an unprivileged LXC container. To behave as close as possible like a real Docker container, the wrapper will bridge it's own interface (which it was given by the Docker daemon) to the created container and then pass it's own network configuration to the container, rendering itself unreachable from the docker network. For all intents and purposes, this will make the LXC container impersonate the wrapper when it comes to port forwardings.

# Credits
The basic concept was taken from https://github.com/micw/docker-lxc
Big thanks for creating this container. Otherwise it would have been impossible to figure out how to do this, Google search results are complete garbage since `lxc` and `docker` are usually used exactly the other way. Also if you are reading this and are the kind of person that posts "X is not meant to be used for Y" underneath genuine questions, I hope you clog your toilet. Answer the question or ignore it.