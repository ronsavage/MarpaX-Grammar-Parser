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
	'bind_attributes=i',
	'cooked_tree_file=s',
	'help',
	'logger=s',
	'marpa_bnf_file=s',
	'maxlevel=s',
	'minlevel=s',
	'raw_tree_file=s',
	'user_bnf_file=s',
) )
{
	pod2usage(1) if ($option{'help'});

	my($parser) = MarpaX::Grammar::Parser -> new(%option);
	my($exit)   = $parser -> run;
	$exit       = MarpaX::Grammar::Parser::Utils -> new -> run(raw_tree => $parser -> raw_tree);

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

tree.dump.pl - Help analyze the output of parsing metag.bnf.

=head1 SYNOPSIS

tree.dump.pl [options]

	Options:
	-bind_attributes Boolean
	-cooked_tree_file aTextFileName
	-help
	-logger aLog::HandlerObject
	-maxlevel logOption1
	-minlevel logOption2
	-marpa_bnf_file aMarpaSLIF-DSLFileName
	-raw_tree_file aTextFileName
	-user_bnf_file aUserSLIF-DSLFileName

Exit value: 0 for success, 1 for failure. Die upon error.

=head1 OPTIONS

=over 4

=item o -bind_attributes Boolean

Include (1) or exclude (0) attributes in the tree file(s) output.

Default: 0.

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

See share/metag.bnf.

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

=item o -raw_tree_file aTextFileName

The name of the text file to write containing the grammar as a raw tree.

If '', the file is not written.

Default: ''.

=item o -user_bnf_file aUserSLIF-DSLFileName

Specify the name of the file containing your Marpa::R2-style grammar.

See share/stringparser.bnf for a sample.

This option is mandatory.

Default: ''.

=back

=cut
