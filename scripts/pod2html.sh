#!/bin/bash

NAME=MarpaX/Grammar/Parser
export NAME

pod2html.pl -i lib/$NAME.pm       -o /dev/shm/html/Perl-modules/html/$NAME.html
pod2html.pl -i lib/$NAME/Utils.pm -o /dev/shm/html/Perl-modules/html/$NAME/Utils.html

NAME=Data/TreeDumper/Renderer/Marpa

pod2html.pl -i lib/$NAME.pm -o /dev/shm/html/Perl-modules/html/$NAME.html
