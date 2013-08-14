#!/bin/bash
#
# Name: g2p.sh.
#
# Parameters:
# 1: The abbreviated name of sample input and output data files.
#	E.g. xyz simultaneously means data/xyz.bnf and data/xyz.log.
# 2 .. 5: Use for anything. E.g.: -maxlevel debug.

perl -Ilib scripts/g2p.pl -marpas_bnf data/metag.bnf -n 1 -raw data/$1.tree -user_bnf data/$1.bnf $2 $3 $4 $5
