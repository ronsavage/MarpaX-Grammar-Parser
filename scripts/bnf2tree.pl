#!/usr/bin/env perl

use strict;
use warnings;

use MarpaX::Grammar::Parser;

use Getopt::Long;

use Pod::Usage;

# -----------------------------------------------

my($option_parser) = Getopt::Long::Parser -> new();

my(%option);

if ($option_parser -> getoptions
(
	\%option,
	'cooked_tree_file=s',
	'help',
	'logger=s',
	'marpa_bnf_file=s',
	'maxlevel=s',
	'minlevel=s',
	'no_attributes=i',
	'raw_tree_file=s',
	'user_bnf_file=s',
) )
{
	pod2usage(1) if ($option{'help'});

	# Return 0 for success and 1 for failure.

	exit MarpaX::Grammar::Parser -> new(%option) -> run;
}
else
{
	pod2usage(2);
}

__END__

=pod

=head1 NAME

bnf2tree.pl - Convert a Marpa grammar into a tree using Tree::DAG_Node.

=head1 SYNOPSIS

bnf2tree.pl [options]

	Options:
	-cooked_tree_file aTextFileName
	-help
	-logger aLog::HandlerObject
	-maxlevel logOption1
	-minlevel logOption2
	-no_attributes Boolean
	-marpa_bnf_file aMarpaSLIF-DSLFileName
	-raw_tree_file aTextFileName
	-user_bnf_file aUserGrammarFileName

Exit value: 0 for success, 1 for failure. Die upon error.

=head1 OPTIONS

=over 4

=item o -cooked_tree_file aTextFileName

The name of the text file to write containing the grammar as a cooked tree.

If '', the file is not written.

Default: ''.

=item o -help

Print help and exit.

=item o -logger aLog::HandlerObject

By default, an object is created which prints to STDOUT.

Set this to '' to stop logging.

Default: undef.

=item o -marpa_bnf_file aMarpaSLIF-DSLFileName

Specify the name of Marpa's own SLIF-DSL file.

This file ships with L<Marpa::R2>, in the meta/ directory. It's name is metag.bnf.

A copy, as of Marpa::R2 V 2.066000, ships with L<MarpaX::Grammar::Parser>.

See data/metag.bnf.

This option is mandatory.

Default: ''.

=item o -maxlevel logOption1

This option affects Log::Handler.

See the Log::handler docs.

Default: 'info'.

=item o -minlevel logOption2

This option affects Log::Handler.

See the Log::handler docs.

Default: 'error'.

No lower levels are used.

=item o -no_attributes Boolean

Include (0) or exclude (1) attributes in the tree_file output.

Default: 0.

=item o -raw_tree_file aTextFileName

The name of the text file to write containing the grammar as a raw tree.

If '', the file is not written.

Default: ''.

=item o -user_bnf_file aUserGrammarFileName

Specify the name of the file containing your Marpa::R2-style grammar.

See data/stringparser.bnf for a sample.

This option is mandatory.

Default: ''.

=back

=cut
