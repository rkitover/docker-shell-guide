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
