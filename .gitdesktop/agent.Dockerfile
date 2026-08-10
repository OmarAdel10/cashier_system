# Custom agent container image for this repository.
#
# GitDesktop builds this into a per-repo image layered on its managed agent base, and runs
# containerized agent sessions (and the Test shell) for this repo inside it. It MUST start
# with `FROM gitdesktop-agent:latest`. Everything below is yours to add — but note the
# image is only ever (re)built after you review it and confirm, so a build runs your
# commands. Switch to `USER root` to install system packages, then back to `USER node`.
#
# Agent plugins & skills are vendored from the host under `.gitdesktop/opencode/`
# (agents/, skills/, commands/, AGENTS*.md, opencode.json) because the Docker build
# context is this repo — host paths like ~/.config/opencode are not reachable.
FROM gitdesktop-agent:latest
USER root
# git: required by npm to fetch git-sourced deps (superpowers plugin)
#        and useful for agent sessions; not present in the base image.
RUN apt-get update \
    && apt-get install -y --no-install-recommends git ca-certificates \
    && rm -rf /var/lib/apt/lists/*
USER node

# opencode global config: agents, skills, commands, instructions.
# NOTE: literal /home/node path (base image HOME); $HOME is not populated during
# the COPY stage, which would silently put files in /.config/opencode.
COPY --chown=node .gitdesktop/opencode/ /home/node/.config/opencode/

# Superpowers plugin for opencode (pinned v6.2.0).
# Pre-installed into the config dir so opencode skips its runtime bun-add at
# session start (it checks for node_modules in the config dir). The version is
# also pinned in .gitdesktop/opencode/opencode.json as a fallback install.
RUN cd /home/node/.config/opencode \
    && npm install --no-fund --no-audit "superpowers@git+https://github.com/obra/superpowers.git#v6.2.0"