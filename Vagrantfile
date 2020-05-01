# -*- mode: ruby -*-
# vi: set ft=ruby :

VAGRANTFILE_API_VERSION = "2"

# Install vagrant hostsupdater if needed
required_plugins = %w( vagrant-hostsupdater )
required_plugins.each do |plugin|
    exec "vagrant plugin install #{plugin};vagrant #{ARGV.join(" ")}" unless Vagrant.has_plugin? plugin || ARGV[0] == 'plugin'
end

@docker_network = 'vagrant_nw';
@hostname = 'symfony-starter.test';
@aliases = [
    "traefik.#{@hostname}",
    "mails.#{@hostname}"
]

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
    config.vm.box = "bungerous/alpine64"

    config.vm.hostname = @hostname
    config.hostsupdater.aliases = @aliases

    config.vm.provider "virtualbox" do |v|
        v.memory = 2048
        v.cpus = 2

        # Allow symlinks on the shared folder
        v.customize ["setextradata", :id, "VBoxInternal2/SharedFoldersEnableSymlinksCreate/v-root", "1"]

        # Share host VPN connections with guest
        v.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
    end

    # Shared folder over NFS
    config.vm.synced_folder ".", "/vagrant", type: "nfs", mount_options: ['rw', 'vers=3', 'udp', 'fsc', 'nolock', 'actimeo=2']

    config.vm.network "private_network", ip: "192.168.35.10"

    config.ssh.forward_agent = true

    config.trigger.before :up do |trigger|
        trigger.info = "Generating SSL certificates..."
        trigger.run = { path: "vagrant/trigger/generate_certs.sh", args: "#{@hostname} #{@aliases.join(' ')}" }
    end

    # Install custom scripts
    config.vm.provision :shell, inline: "ln -sf /vagrant/vagrant/bin/* /usr/local/bin/"

    # Docker provisioning
    config.vm.provision "docker" do |d|

        # Create a custom docker network as soon as Docker has been installed
        d.post_install_provision :shell, inline: "docker network list | grep -q #{@docker_network} || docker network create #{@docker_network}"

        d.run "traefik", image: "traefik:2.2",
        args: %W[
            -v '/var/run/docker.sock:/var/run/docker.sock:ro'
            -v '/vagrant/docker/traefik/certs:/etc/ssl/app'
            -v '/vagrant/docker/traefik/configuration:/configuration:ro'
            --env-file /vagrant/docker/traefik/env.list

            --network #{@docker_network}

            --label 'treafik.docker.network=#{@docker_network}'
            --label 'traefik.http.routers.traefik.rule=Host(`traefik.#{@hostname}`)'
            --label 'traefik.http.routers.traefik.service=api@internal'
            --label 'traefik.http.routers.traefik.entrypoints=https'
            --label 'traefik.http.routers.traefik.tls=true'

            --label "traefik.http.routers.https-redirect.entrypoints=http"
            --label "traefik.http.routers.https-redirect.rule=HostRegexp(`{any:.*}`)"
            --label "traefik.http.routers.https-redirect.middlewares=https-redirect"
            --label "traefik.http.middlewares.https-redirect.redirectscheme.scheme=https"

            -p 80:80
            -p 443:443
        ].join(' ')

        d.run "nginx", image: "nginx:1.17-alpine", args: %W[
            -v '/vagrant/docker/nginx/default.conf:/etc/nginx/conf.d/default.conf:ro'
            -v '/vagrant:/usr/share/nginx/html'

            --network #{@docker_network}

            --label 'traefik.http.routers.app_http.rule=Host(`#{@hostname}`)'
            --label 'traefik.http.routers.app_http.entrypoints=http'

            --label 'traefik.http.routers.app_https.rule=Host(`#{@hostname}`)'
            --label 'traefik.http.routers.app_https.entrypoints=https'
            --label 'traefik.http.routers.app_https.tls=true'
        ].join(' ')

        d.build_image "/vagrant", args: "--target development -t='app'"
        d.run "app", args: %W[
            -v '/vagrant/docker/app/php.ini-development:/usr/local/etc/php/php.ini:ro'
            -v '/vagrant:/var/www/html'
            --mount source=applogs,target=/var/log/symfony
            --env-file /vagrant/docker/app/env.list

            --network #{@docker_network}
        ].join(' ')

        d.run "postgres", image: "postgres:12-alpine", args: %W[
            --network #{@docker_network}
            --mount source=pgdata,target=/var/lib/postgresql/data
            --env-file /vagrant/docker/postgres/env.list
            --shm-size=256MB
            -p 5432:5432
        ].join(' ')

        d.run "mailhog", image: "mailhog/mailhog:latest", args: %W[
            --network #{@docker_network}
            --label 'traefik.http.routers.mailhog.rule=Host(`mails.#{@hostname}`)'
            --label 'traefik.http.routers.mailhog.entrypoints=https'
            --label 'traefik.http.routers.mailhog.tls=true'
            --label 'traefik.http.services.mailhog.loadbalancer.server.port=8025'
        ].join(' ')
    end

    # Install the project's dependencies
    config.vm.provision :shell, inline: "docker exec -i app composer install"

    # After a Vagrant reload, some containers fail to start due to our NFS mount not being fully initialized.
    # We should be able to make the docker service depend on the NFS service, but I haven't yet
    # figured out how to make that work reliably.
    # So, in the meantime we'll have to make do with this simple workaround:
    config.vm.provision "shell", inline: "sudo service docker restart", run: "always"
end