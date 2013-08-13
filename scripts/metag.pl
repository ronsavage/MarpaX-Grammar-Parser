#!/usr/bin/env perl

#use 5.010;
use autodie;
use warnings;
use strict;

#use Data::Dumper::Concise;      # For Dumper().
use Data::TreeDumper;            # For DumpTree().
use Data::TreeDumper::Renderer::Marpa;
#use Data::TreeDraw;             # For draw().
#use Data::Printer colored => 1; # For p().

use English qw( -no_match_vars );

use Marpa::R2;

use Tree::DAG_Node;

# ------------------------------------------------

die "Usage: $0 grammar input\n" if scalar @ARGV != 2;

my($package)      = 'My_Nodes';
my($grammar_file) = do { local $RS = undef; open my $fh, q{<}, $ARGV[0]; my $file = <$fh>; close $fh; \$file };
my($input_file)   = do { local $RS = undef; open my $fh, q{<}, $ARGV[1]; my $file = <$fh>; close $fh; \$file };
my($slg)          = Marpa::R2::Scanless::G -> new( { source => $grammar_file, bless_package => $package } );
my($slr)          = Marpa::R2::Scanless::R -> new( { grammar => $slg } );

$slr -> read($input_file);

# 1: Data::Dumper::Concise.Dumper().
# Output to data/stringparser.dumper.

#print Dumper $slr -> value;

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

=pod

print draw
(
	${$slr -> value},
	{
		spaces        => 0,
		unwrap_object => 1,
	}
);

=cut

# 4: Data::Printer.p().
# Output to data/stringparser.printer.
# Ignores nesting.

#print p(${$slr -> value});

package My_Nodes;

sub new{return {};}

1;
