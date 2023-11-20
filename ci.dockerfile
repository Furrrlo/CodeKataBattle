FROM ghcr.io/xu-cheng/texlive-full:20231101

## install java
RUN apk upgrade && apk add --no-cache openjdk11-jdk
## force the use of what I just installed
## see https://gitlab.alpinelinux.org/alpine/aports/-/blob/0bfc8df7c611c1b9e3b5fcde598fa6865b8d8af9/community/java-common/java-common.trigger
RUN ln -sfn /usr/lib/jvm/java-11-openjdk /usr/lib/jvm/forced-jvm && \
        ln -sfn /usr/lib/jvm/forced-jvm /usr/lib/jvm/default-jvm
## test java
RUN java -version
## set up a puml command 
RUN mkdir /opt/plantuml && \
        wget -O /opt/plantuml/plantuml-mit.jar "https://github.com/plantuml/plantuml/releases/download/v1.2023.12/plantuml-mit-1.2023.12.jar" && \
        echo '#!/bin/sh' | tee /opt/plantuml/puml && \
        echo 'java -jar /opt/plantuml/plantuml-mit.jar -headless "$@"' | tee -a /opt/plantuml/puml && \
        chmod +x /opt/plantuml/puml && \
        link /opt/plantuml/puml /usr/local/bin/puml
## test puml
RUN puml -version
## install inkscape for svg handling
RUN apk upgrade && apk add --no-cache inkscape
