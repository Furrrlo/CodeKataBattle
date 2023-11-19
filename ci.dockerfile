FROM ghcr.io/xu-cheng/texlive-full:latest

## install java and set up a puml command 
RUN apk upgrade && apk add --no-cache \
        openjdk11-jre \
        # These are needed otherwise we get a java.lang.UnsatisfiedLinkError: no fontmanager in system library path
        fontconfig ttf-dejavu freetype
RUN mkdir /opt/plantuml && \
        wget -O /opt/plantuml/plantuml-mit.jar "https://github.com/plantuml/plantuml/releases/download/v1.2023.12/plantuml-mit-1.2023.12.jar" && \
        echo '#!/bin/sh' | tee /opt/plantuml/puml && \
        echo 'java -jar /opt/plantuml/plantuml-mit.jar -headless "$@"' | tee -a /opt/plantuml/puml && \
        chmod +x /opt/plantuml/puml && \
        link /opt/plantuml/puml /usr/local/bin/puml