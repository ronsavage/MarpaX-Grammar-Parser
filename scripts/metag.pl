#!/usr/bin/env perl

#use 5.010;
use warnings;
use strict;

use Data::TreeDumper; # For DumpTree().
use Data::TreeDumper::Renderer::Marpa;

use English '-no_match_vars';

use MarpaX::Grammar::Parser::Dummy;
use Marpa::R2;

use Tree::DAG_Node;

# ------------------------------------------------

die "Usage: $0 grammar input\n" if scalar @ARGV != 2;

my($package)      = 'MarpaX::Grammar::Parser::Dummy';
my($grammar_file) = do { local $RS = undef; open my $fh, q{<}, $ARGV[0]; my $file = <$fh>; close $fh; \$file };
my($input_file)   = do { local $RS = undef; open my $fh, q{<}, $ARGV[1]; my $file = <$fh>; close $fh; \$file };
my($slg)          = Marpa::R2::Scanless::G -> new( { source => $grammar_file, bless_package => $package } );
my($slr)          = Marpa::R2::Scanless::R -> new( { grammar => $slg } );

$slr -> read($input_file);

# 2: Data::TreeDumper.DumpTree().
# Output to data/stringparser.treedumper.

my($root) = Tree::DAG_Node -> new
({
	attributes => {},
	name       => 'statements',
});

print DumpTree
(
	${$slr -> value},
	$ARGV[1], # Title is input bnf file name.
	#DISPLAY_OBJECT_TYPE  => 0, # Suppresses class names.
	DISPLAY_ROOT_ADDRESS => 1,
	#NO_PACKAGE_SETUP    => 1,  # No change in output.
	NO_WRAP              => 1,
	RENDERER             =>
	{
		NAME    => 'Marpa',
		package => $package,
		root    => $root,
	}
);

my($no_attributes) = 1;

print map{"$_\n"} @{$root -> tree2string({no_attributes => $no_attributes})};

# 3: Data::TreeDraw.draw().
# Output to data/stringparser.treedraw.
# Ignores nesting, even with unwrap_object option set.

# 4: Data::Printer.p().
# Output to data/stringparser.printer.
# Ignores nesting.

