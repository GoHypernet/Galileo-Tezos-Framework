# Build stage for Galileo IDE
FROM hypernetlabs/galileo-ide:linux as galileo-ide
	
# Final build stage for complete application
FROM tezos/tezos:latest-release

USER root

RUN apk update && \
    apk add git tmux vim zip curl wget unzip openssh bash \
    python3 python3-dev py-pip go \
    make gcc g++ libsecret-dev libx11-dev libxkbfile-dev supervisor && \
    wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.38.0/install.sh | bash && \
    apk add nodejs npm && \
	curl https://rclone.org/install.sh | bash 

# Configure Go
ENV GOROOT /usr/lib/go
ENV GOPATH /go
ENV PATH /go/bin:$PATH

RUN mkdir -p ${GOPATH}/src ${GOPATH}/bin

RUN go get -u github.com/bitnami/bcrypt-cli

COPY --chown=tezos .theia /home/tezos/.theia
COPY --chown=tezos .vscode /home/tezos/.vscode

# get the Caddy server executables and stuff
COPY --from=galileo-ide --chown=tezos /caddy/caddy /usr/bin/caddy
COPY --from=galileo-ide --chown=tezos /caddy/header.html /etc/assets/header.html
COPY --from=galileo-ide --chown=tezos /caddy/users.json /etc/gatekeeper/users.json
COPY --from=galileo-ide --chown=tezos /caddy/auth.txt /etc/gatekeeper/auth.txt
COPY --from=galileo-ide --chown=tezos /caddy/settings.template /etc/gatekeeper/assets/settings.template
COPY --from=galileo-ide --chown=tezos /caddy/login.template /etc/gatekeeper/assets/login.template
COPY --from=galileo-ide --chown=tezos /caddy/custom.css /etc/gatekeeper/assets/custom.cs
COPY --chown=tezos rclone.conf /home/tezos/.config/rclone/rclone.conf
COPY --chown=tezos Caddyfile /etc/

# get the galileo IDE
COPY --from=galileo-ide --chown=tezos /.galileo-ide /home/tezos/.galileo-ide

# edit the node configuration file for operating as a relay node
WORKDIR /home/tezos/.galileo-ide

# get superviserd
COPY supervisord.conf /etc/

# switch to non-root user
USER tezos

# set environment variable to look for plugins in the correct directory
ENV SHELL=/bin/bash \
    THEIA_DEFAULT_PLUGINS=local-dir:/theia/plugins
ENV USE_LOCAL_GIT true
ENV GALILEO_RESULTS_DIR /home/tezos

# set login credintials and write them to text file
ENV USERNAME "a"
ENV PASSWORD "a"
RUN sed -i 's,"username": "","username": "'"$USERNAME"'",1' /etc/gatekeeper/users.json && \
    sed -i 's,"hash": "","hash": "'"$(echo -n "$(echo $PASSWORD)" | bcrypt-cli -c 10 )"'",1' /etc/gatekeeper/users.json

ENTRYPOINT ["sh", "-c", "supervisord"]