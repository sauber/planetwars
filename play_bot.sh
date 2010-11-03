#!/bin/bash
java -jar tools/PlayGame.jar maps/map7.txt 1000 1000 log.txt \
    "perl MyBot.pl" \
    "java -jar example_bots/RandomBot.jar" \
    | java -jar tools/ShowGame.jar
