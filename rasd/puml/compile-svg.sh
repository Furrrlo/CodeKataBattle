#!/bin/sh
wget -qO "$1.svg" "http://www.plantuml.com/plantuml/svg/$(puml -computeurl "$1.puml")"