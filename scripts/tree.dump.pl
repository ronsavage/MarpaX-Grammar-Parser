#!/usr/bin/env perl

use strict;
use warnings;

use MarpaX::Grammar::Parser;
use MarpaX::Grammar::Parser::Utils;

use Getopt::Long;

use Pod::Usage;

# -----------------------------------------------

my($option_parser) = Getopt::Long::Parser -> new();

my(%option);

if ($option_parser -> getoptions
(
	\%option,
	'help',
	'marpa_bnf_file=s',
	'maxlevel=s',
	'minlevel=s',
	'raw_tree_file=s',
	'user_bnf_file=s',
) )
{
	pod2usage(1) if ($option{'help'});

	my($parser)    = MarpaX::Grammar::Parser -> new(%option);
	my($exit)      = $parser -> run;
	my($formatter) = MarpaX::Grammar::Parser::Utils -> new
						(
							logger   => $parser -> logger,
							raw_tree => $parser -> raw_tree,
						);
	$exit          = $formatter -> run;

	# Return 0 for success and 1 for failure.

	exit $exit;
}
else
{
	pod2usage(2);
}

__END__

=pod

=head1 NAME

tree.dump.pl - Print, as a hash, the raw tree built by calling L<MarpaX::Grammar::Parser>'s C<run()> method.

=head1 SYNOPSIS

This program prints its own interpretation of the raw tree.

Since the tree is of type L<Tree::DAG_Node>, you can also use that module's methods, such as
C<tree2string()>, to do the printing.

The raw tree, as output by Marpa, can also be written to a file with the -raw_tree_file option.

tree.dump.pl [options]

	Options:
	-help
	-marpa_bnf_file aMarpaBNFFileName
	-maxlevel logOption1
	-minlevel logOption2
	-raw_tree_file aTextFileName
	-user_bnf_file aUserBNFFileName

Exit value: 0 for success, 1 for failure. Die upon error.

=head1 OPTIONS

=over 4

=item o -help

Print help and exit.

=item o -marpa_bnf_file aMarpaBNFFileName

Specify the name of Marpa's own BNF file.

This file ships with L<Marpa::R2>'s file as share/metag.bnf.

See share/metag.bnf.

This option is passed to MarpaX::Grammar::Parser, but is not used by MarpaX::Grammar::Parser::Utils.

This option is mandatory.

Default: ''.

=item o -maxlevel logOption1

This option affects Log::Handler.

See the Log::handler docs.

Nothing is printed by default. Set C<maxlevel> to 'info' to get the hashref printed on STDOUT.

Default: 'notice'.

=item o -minlevel logOption2

This option affects Log::Handler.

See the Log::handler docs.

Default: 'error'.

No lower levels are used.

=item o -raw_tree_file aTextFileName

The name of the text file to write containing the grammar as a raw Marpa-style tree.

This option is passed to MarpaX::Grammar::Parser, but is not used by MarpaX::Grammar::Parser::Utils.

If '', the file is not written.

Default: ''.

=item o -user_bnf_file aUserBNFFileName

Specify the name of the file containing your Marpa::R2-style grammar.

See share/stringparser.bnf for a sample.

This option is passed to MarpaX::Grammar::Parser, but is not used by MarpaX::Grammar::Parser::Utils.

This option is mandatory.

Default: ''.

=back

=cut
