#!/usr/bin/env perl

use strict;
use warnings;

use MarpaX::Grammar::Parser;

# -----------------------------------------------

my($parser) = MarpaX::Grammar::Parser -> new
(
	cooked_tree_file => 'share/stringparser.cooked.tree',
	marpa_bnf_file   => 'share/metag.bnf',
	no_attributes    => 1,
	user_bnf_file    => shift || 'share/stringparser.bnf',
);

die "Parse failed. \n" if ($parser -> run != 0);
