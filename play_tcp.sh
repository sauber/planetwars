#!/usr/bin/perl
# This script runs three games on the TCP server, good for practice..

unless (-x "tools/tcp") {
    system("gcc -O2 -o tools/tcp tools/tcp.c");
}

#die "Please set an arbitrary username and password below.\n";

for (1..3) {
    system("./tools/tcp 72.44.46.68 995 sauber ./MyBot.pl");
    sleep 5;
}
