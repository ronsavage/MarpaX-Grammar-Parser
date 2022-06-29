#!/bin/bash

PREFIX=Perl-modules/html/MarpaX/Grammar/
FILE=$PREFIX/Parser.html

# DR is doc_root. I run Debian, and DR's value is /run/shm/html.
# I work in a ramdisk and copy the result to hardisk (nowadays also made of ram chips).

mkdir -p $DR/$PREFIX
mkdir -p ~/savage.net.au/$PREFIX

pod2html.pl -i lib/MarpaX/Grammar/Parser.pm -o $DR/$FILE

cp $DR/$FILE ~/savage.net.au/$FILE
