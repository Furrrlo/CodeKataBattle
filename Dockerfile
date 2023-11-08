FROM mcr.microsoft.com/devcontainers/base:ubuntu

ARG USERNAME=vscode

## install TinyTeX
# - https://yihui.org/tinytex/faq/#faq-5
# - https://yihui.org/tinytex/faq/#faq-6
# - https://yihui.org/tinytex/faq/#faq-8
RUN wget -O- "https://yihui.org/tinytex/install-bin-unix.sh" | sh -s - --admin --no-path && \
        mv ~/.TinyTeX /opt/TinyTeX && \
        /opt/TinyTeX/bin/*/tlmgr option sys_bin /usr/local/bin/ && \
        /opt/TinyTeX/bin/*/tlmgr path add && \
        chown -R root:staff /opt/TinyTeX && \
        chmod -R g+w /opt/TinyTeX && \
        chmod -R g+wx /opt/TinyTeX/bin && \
        # Set the SGID bit so that any newly created file/directory is still of the staff group 
        find /opt/TinyTeX -type d -exec chmod g+s {} + && \
        # make `/usr/local/bin` owned by group `staff` and group-writable, so that `tlmgr path add` succeeds without root privileges
        # NOTE: as [per Debian wiki][(https://wiki.debian.org/SystemGroups#Other_System_Groups), this is the intended behaviour
        chown :staff /usr/local/bin && chmod g+w /usr/local/bin

## Add user to staff group so that they can use tlmgr without root privileges
RUN usermod -a -G staff ${USERNAME}

# Because of umask stuff the user wouldn't be able to run `tlmgr install/remove` successfully 
# see https://github.com/rstudio/tinytex/issues/415#issuecomment-1543810749
# this is the shit-fix where I just make it owner of the folder (makes some of the stuff done previously useless but whatevs)
RUN chown -R ${USERNAME}: /opt/TinyTeX

##  Install latexindent and put it on path
RUN mkdir /opt/latexindent && \
        wget -O /opt/latexindent/latexindent "https://github.com/cmhughes/latexindent.pl/releases/download/V3.23.3/latexindent-linux" && \
        chmod +x /opt/latexindent/latexindent && \
        link /opt/latexindent/latexindent /usr/local/bin/latexindent

## Install chktex
RUN apt update && apt install -y chktex

## Install texliveonfly
RUN apt update && \
        # libfontconfig needed for xetex
        apt install -y libfontconfig && \
        # Link python3 <-> python otherwise texliveonfly won't work
        link /usr/bin/python3 /usr/bin/python
# drop user so that created files will have the correct owner (see the shit-fix above)
USER ${USERNAME} 
RUN tlmgr install tlmgr install texliveonfly && tlmgr path add
USER root

## Bunch of stuff that texliveonfly fails to auto-install
RUN apt update && apt install -y ghostscript
# drop user so that created files will have the correct owner (see the shit-fix above)
USER ${USERNAME} 
RUN tlmgr install \ 
                collection-langeuropean \ 
                babel-english \ 
                epstopdf \ 
        && tlmgr path add
USER root