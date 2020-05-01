# Symfony Starter

A template for starting a new Symfony project. Runs inside a minimal Vagrant box, provisioned with Docker!

## Requirements
- Virtualbox >= v6.0
- Vagrant >= v.2.2.6
- [mkcert](https://mkcert.dev)

## Usage
Simply click the green button above that says "Use this template", and you'll be prompted to create a new repository based on this one.

Once done, clone your newly created project and open up the `Vagrantfile` to modify the `@hostname` variable to a domain of your liking. Run `vagrant up` and your project should be available to hack on in a few minutes!

### Running Composer and Symfony commands
Because our project lives inside a Docker container we can't just execute `bin/console` or `composer` like we normally would.

Instead, we have to invoke those commands like `docker exec -it app bin/console cache:clear` or `docker exec -it app composer dumpautoload`.

Typing all of this on a regular basis gets quite cumbersome, so we've provided some wrapper scripts to improve the developer experience.
Running Symfony commands can be done by using `sfc`, short for "Symfony console", so for example: `sfc cache:clear`

Same for composer: `composer` invokes composer inside the app container.