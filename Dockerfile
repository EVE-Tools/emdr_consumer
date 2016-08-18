FROM alpine:3.4

MAINTAINER zweizeichen@element-43.com

#
# Copy release to container and set command
#

# Add faster mirror and upgrade packages in base image, Erlang needs ncurses, erlzmq libstdc++
RUN printf "http://mirror.leaseweb.com/alpine/v3.4/main\nhttp://mirror.leaseweb.com/alpine/v3.4/community" > etc/apk/repositories && \
    apk update && \
    apk upgrade && \
    apk add ncurses-libs libstdc++ && \
    rm -rf /var/cache/apk/*

# Copy build
WORKDIR /emdr_consumer
COPY dist .

# Copy vm.args as erlzmq2 needs to have SMP enabled
COPY rel/vm.args vm.args
ENV VMARGS_PATH=/emdr_consumer/vm.args

CMD ["bin/emdr_consumer", "foreground"]
