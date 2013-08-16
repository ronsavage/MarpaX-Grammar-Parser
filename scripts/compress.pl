#!/usr/bin/env perl

use strict;
use warnings;

use MarpaX::Grammar::Parser;

# -----------------------------------------------

my($parser) = MarpaX::Grammar::Parser -> new
(
	marpa_bnf_file => 'data/metag.bnf',
	user_bnf_file  => 'data/stringparser.bnf',
);

die "Parse failed. \n" if ($parser -> run != 0);

$parser -> compress_tree;
