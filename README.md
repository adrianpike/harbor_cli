harbor-cli
==========

This is the companion CLI tool to [harbor](http://github.com/adrianpike/harbor),
which is a routing layer and deployment tools for 12factor microservices.

The CLI is responsible for orchestration, control, and developer happiness, but
they truly work best in tandem.

I'd recommend you follow the README steps over in the main Harbor repository.

Installation and Quickstart
---------------------------

First, install the gem.

```bash
adrian$ gem install harbor-cli
```

Now, cd into the git repository for one of the services you want to deploy
with harbor, and initialize what's known as a Harborfile. You'll be walked
through the initial steps of getting up and running.

```bash
adrian$ harbor init
```
