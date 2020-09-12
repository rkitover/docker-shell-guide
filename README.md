<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->


- [Using Docker for Testing and Development on any Linux Distribution](#using-docker-for-testing-and-development-on-any-linux-distribution)
  - [What is Docker?](#what-is-docker)
  - [Install Docker or Podman](#install-docker-or-podman)
  - [Configure Docker](#configure-docker)
  - [Configure Podman](#configure-podman)
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
internet.

### What is Docker?

Docker is a container system, it runs a linux system as a filesystem (image)
using your existing linux operating system, like a chroot or FreeBSD jail. On
other OSes, it shares a lightweight linux virtual machine between your
different linux containers.

### Install Docker or Podman

The first step is to install `docker` or `podman`. Use your distribution
package.  On Windows or Mac, use the installer from the docker hub.

Create an account with docker here:

https://hub.docker.com/

This is where you search for images.

The advantage of `podman` is that it doesn't require root access, otherwise the
command-line interface is the same. Podman is only available for Linux, so on
Windows or MacOS use Docker.

The script presented here will automatically prefer `podman` if it is available.

You may also want to add this to your `~/.bashrc` if using podman:

```bash
alias docker=podman
```

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

### Configure Podman

After installing the `podman` distribution package, make sure these files exist:

```
/etc/containers/policy.json
/etc/containers/registries.conf
```

If they do not, copy the sample files or download them:

```bash
sudo mkdir -p /etc/containers
sudo curl -L -o /etc/containers/registries.conf https://raw.githubusercontent.com/projectatomic/registries/master/registries.fedora
sudo curl -L -o /etc/containers/policy.json https://raw.githubusercontent.com/containers/skopeo/master/default-policy.json
```

For more information on `podman` installation see:

https://podman.io/getting-started/installation.html

Make sure you have the files:

```
/etc/subuid
/etc/subgid
```

both files should have a line like the following:

```
rkitover:100000:65536
```

here `rkitover` is my username, replace it with yours.

Create the files if they don't exist and re-login to your DE or reboot.

Next, make sure you made a Docker Hub account and log into it:

```bash
podman login docker.io
```

Otherwise, the usage is the same as with docker, just use `podman` instead of
`docker` in the examples that follow.

There are some differences, for example with uid mapping, but the script takes
care of that for you.

Also committing the image is slower with `podman` than with `docker`, and there
are currently issue with terminal handling in shells started with `podman
exec`.

### Docker Images

Now that you have taken care of the preliminaries, I will describe how to run
shells in arbitrary linux distributions. For the purposes of this guide, I am
using my username `rkitover`, which you will substitute for your own.

The example distribution I will use is Ubuntu 20.04 "Focal".

The name of this image on the hub is `ubuntu:focal`, when you search for images
on the docker hub you will see the name you need to use.

You can use `docker pull` to load an image into your store, or run an image name
directly and it will be automatically downloaded, you will use the latter
option.

### Initial Setup

We need to create the environment to use from our shell launcher script.

Open a root shell in the image like so:

```bash
docker run --name focal -h focal --detach-keys="ctrl-@" -it ubuntu:focal bash -l
```

`docker` will download the image and open a root shell.

What this command does:

- The container name is set to `focal`.

- The hostname of the container in the docker virtual network is set to `focal`.

- The hotkey to detach from the shell is set to `CTRL-2`.

- The `-i` option means you want an interactive session.

- The `-t` option allocates a tty.

- `ubuntu:focal` is the image name on the docker hub, local image names will be
  checked first. The `:focal` part is the "tag", often a version or codename etc..

- The rest is the command to run, in this case a `bash` login shell.

Now you are going to do some setup to use the image as a development/testing
environment. You would do something similar for other distributions, depending
on your needs and the needed commands.

```bash
useradd rkitover # for windows add: -g 0
apt update
apt -y upgrade
apt -y install bash-completion vim tmux tree git build-essential cmake ripgrep sudo locales
echo 'rkitover ALL = (ALL) NOPASSWD: ALL' > /etc/sudoers.d/rkitover
locale-gen en_US.UTF-8
locale-gen ru_RU.UTF-8
```

That should be good, add your user, install some packages (most importantly sudo
and locales), add yourself to sudo, generate locales.

If you are not using bash as your shell, install your shell as well, as that is
what the script uses for your environment.

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
52ef73929c74        ubuntu:focal        "bash -l"           13 minutes ago      Exited (0) 2 seconds ago                       focal
```

this shows that you had a container named `focal` running using the image
`ubuntu:focal` and that it has exited.

You are going to save the modified image in your namespace and remove the
container.

```bash
docker commit focal rkitover/ubuntu:focal
docker rm focal
```

Now running `docker ps -a` again will show an empty table.

You can run one-shot shells and have the exited container by automatically
removed, just pass `--rm` as one of the options.

### Some Environment Tweaks for Docker

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

alias ls="ls -h --color=auto --hide='ntuser.*' --hide='NTUSER.*'"
```

### The `docker-shell` script (Linux)

See below for Windows powershell script.

Put the following script in your `~/bin` or wherever you keep such things:

```bash
mkdir -p ~/bin
cd ~/bin
curl -LO 'https://raw.githubusercontent.com/rkitover/docker-shell-guide/master/docker-shell'
chmod +x docker-shell
```

**NOTE:** If you have both `docker` and `podman` installed, the script will
automatically use `podman`, if you want to use `docker` instead, add this to
your `~/.bashrc`:

```bash
export DOCKER=docker
```

you can also set this variable to the specific `docker` or `podman` executable
you want to use, the necessary adjustments will be made for `podman`.

This is the script:

```bash
#!/bin/sh

VERSION=0.2

main() {
    find_docker

    while [ $# -gt 0 ]; do
        case "$1" in
            --version)
                echo "${0##*/} $VERSION"
                exit 0
                ;;
            --name)
                shift
                name=$1
                shift
                ;;
            --name=*)
                name=${1##--name=}
                shift
                ;;
            -*)
                shift
                ;;
            *)
                image=$1
                shift
                break
                ;;
        esac
    done

    : ${name:=$(echo "$image" | sed 's,[/:],_,g')}

    # Default to starting a shell, otherwise run command.
    if [ $# -eq 0 ]; then
        set -- "${SHELL:-/bin/bash}" -l
    fi

    : ${XDG_RUNTIME_DIR:=/run/user/$(id -u)}

    target=$USER/"$image"

    if container_exists $name; then
        target=$name
    fi

    set -- \
        -e SHELL="${SHELL:-/bin/bash}" \
        -e LANG="${LANG:-C}" \
        -e DISPLAY="$DISPLAY" \
        -e XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
        -w "$HOME" \
        --detach-keys="ctrl-@" \
        -it -u $USER \
        $extra_args \
        $target \
        "$@"

    # If running, exec another shell in the container.
    if container_exists $name; then
        exec $docker exec "$@"
    fi

    # Otherwise launch a new container.
    $docker run --name "$name" -h "$name" \
        -v /tmp/.X11-unix:/tmp/.X11-unix \
        -v "$XDG_RUNTIME_DIR":"$XDG_RUNTIME_DIR" \
        --device=/dev/dri \
        -v "$HOME":"$HOME" \
        $run_extra_args \
        "$@"

    if container_exists $name -f "status=exited"; then
        $docker commit "$name" $USER/"$image"

        $docker rm "$name"
    fi
}

container_exists() {
    _name=$1
    shift
    [ -n "$($docker ps -q -a -f "name=$_name" "$@" 2>/dev/null)" ]
}

find_docker() {
    extra_args=
    run_extra_args=

    if [ -z "$DOCKER" ] && command -v podman >/dev/null; then
        docker=podman
    else
        docker=${DOCKER:-docker}
    fi

    case "$($docker --version)" in
        *podman*)
            # Thanks to stevenwhately for this solution, from:
            # https://github.com/containers/libpod/issues/2898#issuecomment-485291659
            user_id_real=$(id -u)
            max_uid_count=65536
            max_minus_uid=$((max_uid_count - user_id_real))
            uid_plus_one=$((user_id_real + 1))

            extra_args="--privileged"

            if [ $user_id_real -lt 65536 ]; then
                run_extra_args="--uidmap $user_id_real:0:1 --uidmap 0:1:$user_id_real --uidmap $uid_plus_one:$uid_plus_one:$max_minus_uid"
            else
                run_extra_args="--uidmap $user_id_real:0:1 --uidmap 0:1:65536"
            fi
            ;;
    esac
}

main "$@"
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

This gives you the `docker-shell` alias, which works like the unix script.

I highly recommend using the powershell-core or powershell-preview and
microsoft-windows-terminal chocolatey packages for this or anything else having
to do with powershell.

Your images should work mostly fine if you followed the instructions above, you
may need to make some tweaks in `~/.bashrc` etc. since on Windows your profile
folder will be mounted as root.

You also don't get X11 support until I figure out how that works and if it's
feasible.

### Entering the Environment

Now try it out, run:

```bash
docker-shell ubuntu:focal
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
docker attach ubuntu_focal
```

If you use this feature, you will have to commit your image and clean up the
container yourself as described previously.

Instead of a shell, you can launch an app from your image, for example:

```bash
docker-shell ubuntu:focal firefox
```

to run a firefox instance from your ubuntu image.

You can commit images to any tag or prefix with this script, and they will be
stored under your user namespace. E.g.:

```bash
docker-shell development/ubuntu:focal
```

in this case during initial setup you would commit the image to
`$USER/development/ubuntu:focal`.

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
docker image prune -f
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
