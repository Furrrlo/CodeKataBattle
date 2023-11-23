#!/bin/bash
set -euxo pipefail

texfile=${@:$#} # last parameter 
args=${*%${!#}} # all parameters except the last

pdflatex $args "\def\emitpumldiagrams{}\input{$texfile}"
