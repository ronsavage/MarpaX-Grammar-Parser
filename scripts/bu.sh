#!/bin/bash

cp ~/perl5/perlbrew/perls/perl-5.14.2/lib/site_perl/5.14.2/Data/TreeDumper/Renderer/Marpa.pm renderer

git commit -am"$1"

bu.perl.sh MarpaX-Grammar-Parser x
