<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**  *generated with [DocToc](https://github.com/thlorenz/doctoc)*

- [Using Docker for Testing and Development on any Linux Distribution](#using-docker-for-testing-and-development-on-any-linux-distribution)
  - [What is Docker?](#what-is-docker)
  - [Install Docker](#install-docker)
  - [Configure Docker](#configure-docker)
  - [Docker Images](#docker-images)
  - [Initial Setup](#initial-setup)
  - [Some Environment Tweaks for Docker](#some-environment-tweaks-for-docker)
  - [The `docker-shell` script (Linux)](#the-docker-shell-script-linux)
  - [The docker-shell powershell module (Windows)](#the-docker-shell-powershell-module-windows)
  - [Entering the Environment](#entering-the-environment)
  - [Deflating images](#deflating-images)
  - [Miscellaneous](#miscellaneous)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## Using Docker for Testing and Development on any Linux Distribution

I will describe how to use docker to help you run shells in arbitrary linux
distributions, preserving your changes.

I will try to keep this short, there is a lot of information about Docker on the
internet of course.

### What is Docker?

Docker is a container system, it runs a linux system as a filesystem (image)
using your existing linux operating system. On other OSes, it shares a
lightweight linux virtual machine between your different linux containers.

### Install Docker

The first step is to install docker. Use your distribution package. On Windows
or Mac, use the installer from the docker hub.

Create an account with docker here:

https://hub.docker.com/

This is where you search for images.

### Configure Docker

On linux, you will want to add yourself to the `docker` group and
reboot/relogin, and enable the docker service:

```bash
sudo usermod -a -G docker $USER
sudo systemctl enable --now docker.service
```

**WARNING:** This is considered insecure, for an alternative installation
method using sudo see:

https://docs.docker.com/install/linux/linux-postinstall/

Once you are logged back in, use the:

```bash
docker login
```

command to log into the hub. You may need the `docker-credential-helpers`
package to store your password.

On Windows and Mac you will want to use the GUI to configure things like RAM and
CPU count for your virtual machine and log into the hub. Be generous with your
allotment, but keep in mind that the docker VM generally needs fewer resources
than a traditional VM.

On Windows you will also need to share the `C` drive, or whichever drive has
your profile directory, as that will be your linux home directory.

### Docker Images

Now that you have taken care of the preliminaries, I will describe how to run
shells in arbitrary linux distributions. For the purposes of this guide, I am
using my username `rkitover`, which you will substitute for your own.

The example distribution I will use is Ubuntu 19.04 "Disco".

The name of this image on the hub is `ubuntu:disco`, when you search for images
on the docker hub you will see the name you need to use.

You can use `docker pull` to load an image into your store, or run an image name
directly and it will be automatically downloaded, you will use the latter
option.

### Initial Setup

We need to create the environment to use from our shell launcher script.

Open a root shell in the image like so:

```bash
docker run --name disco -h disco --detach-keys="ctrl-@" -it ubuntu:disco bash -l
```

docker will download the image and open a root shell.

What this command does:

- the container name is set to `disco`

- the hostname of the container in the docker virtual network is set to `disco`

- the hotkey to detach from the shell is set to `CTRL-2`

- the `-i` option means you want an interactive session

- the `-t` option allocates a tty

- `ubuntu:disco` is the image name on the docker hub, local image names will be
  checked first. The `:disco` part is the "tag", often a version or codename etc..

- the rest is the command to run, in this case a `bash` login shell

Now you are going to do some setup to use the image as a development/testing
environment. You would do something similar for other distributions, depending
on your needs and the needed commands.

```bash
useradd rkitover # for windows add: -g 0
apt update
apt -y upgrade
apt -y install vim tmux tree git build-essential cmake silversearcher-ag sudo locales
cd /etc/sudoers.d
echo 'rkitover ALL = NOPASSWD: ALL' > rkitover
cd
locale-gen en_US.UTF-8
locale-gen ru_RU.UTF-8
```

That should be good, add your user, install some packages (most importantly sudo
and locales), add yourself to sudo, generate locales.

Make sure your `UID` is the same as on the host, generally `1000`.

On Windows you will want to pass `-g 0` to `useradd` because your profile
directory will be mounted as root.

Notice that you did not set up a home directory, that's because you are going to
use the docker volumes feature to mount your existing host home directory inside
the image. And this is why your UID needs to match.

Now you will need to save your set up image.

Docker is primarily used by building images from scripts called Dockerfiles, to
run canned services, in this case you are doing something entirely different.

Run:

```bash
docker ps -a
```

You will see something like this:

```
CONTAINER ID        IMAGE               COMMAND             CREATED             STATUS                     PORTS               NAMES
52ef73929c74        ubuntu:disco        "bash -l"           13 minutes ago      Exited (0) 2 seconds ago                       disco
```

this shows that you had a container named `disco` running using the image
`ubuntu:disco` and that it has exited.

You are going to save the modified image in your namespace and remove the
container.

```bash
docker commit disco rkitover/ubuntu:disco
docker rm disco
```

Now running `docker ps -a` again will show an empty table.

### Some Environment Tweaks for Docker

You need to make some changes to your host `$HOME` configuration (your profile
directory on Windows, same as `~` in powershell) for shells in docker to work
properly. These changes are harmless.

Edit your `~/.bash_profile`, at the top put:

```bash
export SHELL=/bin/bash
export LANG=en_US.UTF-8
```

or whatever locale you want and set up in the previous step.

Make sure it has something like this in the middle:

```bash
. ~/.bashrc
```

at the bottom put:

```bash
cd ~
```

You may need to add logic to your `~/.bashrc` to detect if you are running in
some container and adjust your aliases and such accordingly. For example I have
this:

```bash
if ! grep -q docker /proc/1/cgroup; then
    alias tmux='systemd-run --quiet --scope --user tmux'
fi
```

For Windows I suggest adding the following:

```bash
# Remove background colors from dircolors.
eval "$(
    dircolors -p | \
    sed 's/ 4[0-9];/ 01;/; s/;4[0-9];/;01;/g; s/;4[0-9] /;01 /' > /tmp/dircolors_$$ && \
    dircolors /tmp/dircolors_$$ && \
    rm /tmp/dircolors_$$
)"

if [ "$(uname -s)" = Linux ]; then
    [ -d /run/tmux ] || sudo mkdir -m 0777 /run/tmux

    rm -f ~/.viminfo # cannot write to msys2/cygwin viminfo
fi
```

### The `docker-shell` script (Linux)

See below for Windows powershell script.

Put the following script in your `~/bin` or wherever you keep such things:

```bash
mkdir -p ~/bin
cd ~/bin
curl -LO 'https://gist.githubusercontent.com/rkitover/fdf8bc9ca55248752507336d580f7dbb/raw/c2238caf8954cfecb231f0daba52edbfbaf32b7e/docker-shell'
chmod +x docker-shell
```

```bash
#!/bin/sh

image=$1
shift

name=$(echo "$image" | sed 's,[/:],_,g')

container_exists() {
    [ -n "$(docker ps -q -a -f "name=$name" "$@" 2>/dev/null)" ]
}

set -- \
    -e DISPLAY="$DISPLAY" \
    -e XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
    "$@"

# If running, exec another shell in the container.
if container_exists; then
    exec docker exec \
        --detach-keys="ctrl-@" \
        "$@" \
        -it -u $USER "$name" bash -l
fi

# Otherwise launch a new container.
docker run --name "$name" -h "$name" \
    "$@" \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    -v /run/user/$(id -u):/run/user/$(id -u) \
    --device=/dev/dri \
    -v "$HOME":"$HOME" \
    --detach-keys="ctrl-@" \
    -it -u $USER $USER/"$image" bash -l

# After the main shell exits, commit image and remove container.
if container_exists -f "status=exited"; then
    docker commit "$name" $USER/"$image"

    docker rm "$name"
fi
```

Some notes:

- the `-e` option sets an environment variable in the shell session

- the `-v` option binds a directory on your host to the container, like a bind
  mount

- the `--device` option passes through a host device, this particular setup will
  allow running X apps with GPU acceleration on many setups, more on that later

### The docker-shell powershell module (Windows)

Quick install:

```powershell
mkdir ~/source/repos
cd ~/source/repos
git clone https://github.com/rkitover/docker-shell-guide.git
cd
echo "`r`nImport-Module ~/source/repos/docker-shell-guide/docker-shell.psm1" >> $profile
```

then launch a new shell.

Here is the source:

```powershell
function TestContainerExists {
    $name,$args = $args
    (docker ps -q -a -f "name=$name" $args 2>$null | measure -line).lines -gt 0
}

function OpenDockerShell {
    $image,$args = $args

    $name = $image -replace '[/:]','_'

# If running, exec another shell in the container.
    if (TestContainerExists $name) {
        docker exec `
            "--detach-keys=ctrl-@" `
            $args `
            -it -u $env:UserName $name bash -l
        return
    }

# Otherwise launch a new container.
    docker run --name $name -h $name `
        $args `
        -v "$((Get-Item ~).FullName):/home/$env:UserName" `
        --detach-keys="ctrl-@" `
        -it -u $env:UserName "$env:UserName/$image" bash -l

# After the main shell exits, commit image and remove container.
    if (TestContainerExists $name -f "status=exited") {
        docker commit $name "$env:UserName/$image"

        docker rm $name
    }
}

Set-Alias -name docker-shell -val OpenDockerShell

Export-ModuleMember -Function OpenDockerShell -Alias docker-shell
```

please no rotten tomatoes, I am just learning powershell and this is all a work
in progress.

This gives you the `docker-shell` alias, which works like the unix script.

I highly recommend using the powershell-preview and microsoft-windows-terminal
chocolatey packages for this or anything else having to do with powershell.

Your images should work mostly fine if you followed the instructions above, you
may need to make some tweaks in `~/.bashrc` etc. since on Windows your profile
folder will be mounted as root.

You also don't get X11 support until I figure out how that works and if it's
feasible.

### Entering the Environment

Now try it out, run:

```bash
docker-shell ubuntu:disco
```

you should get a bash shell in your new Ubuntu environment if everything went
well, with a working locale and sudo.

Running the command again in another terminal while this shell is
active will run another shell in the same container.

Once the first shell exits, the image will be committed and the container will
be removed.

You can pass any other arguments to the script, they will be passed to `docker
run` for the first shell and to `docker exec` for subsequent shells.

If you detach with `CTRL-2`, then you can attach again with:

```bash
docker attach disco
```

If you use this feature, you will have to commit your image and clean up the
container yourself as described previously.

You can commit images to any tag or prefix with this script, and they will be
stored under your user namespace. E.g.:

```bash
docker-shell development/ubuntu:bionic
```

in this case during initial setup you would commit the image to
`$USER/development/ubuntu:bionic`.

### Deflating images

This section based on: https://tuhrig.de/flatten-a-docker-container-or-image/

Docker images are overlays, and if you do something like an OS upgrade in an
image, instead of just recreating the image based on a newer image from the
hub, which is a completely valid alternative, you image size will grow much
much bigger. You can see your image sizes with `docker image list`.

To remove intermediate images and greatly reduce your image size, follow this
procedure:

- Start a shell in an image, I will use `fedora:latest` as an example.

- In another terminal, export the image:

```bash
docker export fedora_latest | gzip -c > image.tar.gz
```

- Exit the shell in the image to remove the container.

- Then replace your image with it:

```bash
gunzip -c image.tar.gz | docker import - rkitover/fedora:latest
rm image.tar.gz
```

- Check again in `docker image list` and you will see that the image size is
  drastically reduced, often in half or more.

### Miscellaneous

You may want to install a cron job to clean up dangling images and dead
containers, something like this:

```bash
#!/bin/sh

docker inspect -f '{{if not .State.Running}}{{.Id}} {{ end }}' $(docker ps -aq) | grep -Ev '^$' | \
    xargs docker rm >/dev/null 2>&1
  

docker image prune -f >/dev/null 2>&1
```

To use GPU acceleration for X11 apps, install the `mesa-utils` package or
equivalent, and more on that here:

http://wiki.ros.org/docker/Tutorials/Hardware%20Acceleration
