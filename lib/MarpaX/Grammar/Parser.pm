package MarpaX::Grammar::Parser;

use strict;
use utf8;
use warnings;
use warnings  qw(FATAL utf8);    # Fatalize encoding glitches.
use open      qw(:std :utf8);    # Undeclared streams in UTF-8.
use charnames qw(:full :short);  # Unneeded in v5.16.

use Data::Dumper::Concise; # For Dumper().

use List::AllUtils qw/first_index indexes/;

use Log::Handler;

use Moo;

use Perl6::Slurp; # For slurp().

use Tree::DAG_Node;

has input_file =>
(
	default  => sub{return 'grammar.bnf'},
	is       => 'rw',
	#isa     => 'Str',
	required => 0,
);

has logger =>
(
	default  => sub{return undef},
	is       => 'rw',
#	isa      => 'Str',
	required => 0,
);

has maxlevel =>
(
	default  => sub{return 'info'},
	is       => 'rw',
#	isa      => 'Str',
	required => 0,
);

has minlevel =>
(
	default  => sub{return 'error'},
	is       => 'rw',
#	isa      => 'Str',
	required => 0,
);

has no_attributes =>
(
	default  => sub{return 0},
	is       => 'rw',
	#isa     => 'Bool',
	required => 0,
);

has root =>
(
	default  => sub{return ''},
	is       => 'rw',
	#isa     => 'Tree::DAG_Node',
	required => 0,
);

has tree_file =>
(
	default  => sub{return ''},
	is       => 'rw',
	#isa     => 'Str',
	required => 0,
);

our $VERSION = '1.00';

# ------------------------------------------------

sub BUILD
{
	my($self)  = @_;

	if (! defined $self -> logger)
	{
		$self -> logger(Log::Handler -> new);
		$self -> logger -> add
		(
			screen =>
			{
				maxlevel       => $self -> maxlevel,
				message_layout => '%m',
				minlevel       => $self -> minlevel,
			}
		);
	}

} # End of BUILD.

# --------------------------------------------------

sub check_angle_brackets
{
	my($self, $field, $names) = @_;
	my($index) = first_index{$_ =~ /^</} @$field;

	my($name);
	my($quantifier);

	while ($index >= 0)
	{
		for (my $i = $index; $i <= $#$field; $i++)
		{
			if ($$field[$i] =~ />([*+])?$/)
			{
				$quantifier                = $1 || '';
				substr($$field[$i], -1, 1) = '' if ($quantifier);

				splice(@$field, $index, ($i - $index + 1), join(' ', @$field[$index .. $i]) );

				$name          = $$field[$index];
				$$names{$name} =
				{
					angled     => 1,
					quantifier => $quantifier,
				};

				# Keep searching.

				$index = first_index{$_ =~ /^</ && $_ !~ />[*+]?$/} @$field;

				last;
			}
		}
	}

	for (my $i = $index; $i <= $#$field; $i++)
	{
		if ( (! $$names{$$field[$i]}) && ($$field[$i] =~ /^\w/) && ($$field[$i] !~ /^\d/) )
		{
			if ($$field[$i] =~ /([*+])?$/)
			{
				$quantifier = $1 || '';

				if ($quantifier)
				{
					delete $$names{$$field[$i]};

					substr($$field[$i], -1, 1) = '';
				}
			}
			else
			{
				$quantifier = '';
			}

			$$names{$$field[$i]} =
			{
				angled     => 0,
				quantifier => $quantifier,
			};
		}
	}

} # End of check_angle_brackets.

# --------------------------------------------------

sub log
{
	my($self, $level, $s) = @_;

	$self -> logger -> log($level => $s) if ($self -> logger);

} # End of log.

# ------------------------------------------------

sub run
{
	my($self)  = @_;
	my($names) = $self -> process;

	my($name);

	$self -> root -> walk_down
	({
		callback => sub
		{
			my($n, $options) = @_;
			$name = $n -> name;

			if (defined $$names{$name})
			{
				$n -> attributes
				(
					{%{$n -> attributes}, %{$$names{$name} } }
				);
			}

			return 1;
		},
		_depth => 0,
	});

	my($tree_file) = $self -> tree_file;

	if ($tree_file)
	{
		open(OUT, '>', $tree_file) || die "Can't open(> $tree_file): $!\n";
		print OUT map{"$_\n"} @{$self -> root -> tree2string({no_attributes => $self -> no_attributes})};
		close OUT;
	}

} # End of run.

# ------------------------------------------------

1;

=pod

=head1 NAME

L<MarpaX::Grammar::Parser> - Convert a Marpa grammar into a tree using Tree::DAG_Node

=head1 Synopsis

=head1 Description

=head1 Installation

Install L<MarpaX::Grammar::Parser> as you would for any C<Perl> module:

Run:

	cpanm MarpaX::Grammar::Parser

or run:

	sudo cpan MarpaX::Grammar::Parser

or unpack the distro, and then either:

	perl Build.PL
	./Build
	./Build test
	sudo ./Build install

or:

	perl Makefile.PL
	make (or dmake or nmake)
	make test
	make install

=head1 Scripts Shipped with this Module

=head1 Constructor and Initialization

C<new()> is called as C<< my($parser) = MarpaX::Grammar::Parser -> new(k1 => v1, k2 => v2, ...) >>.

It returns a new object of type C<MarpaX::Grammar::Parser>.

Key-value pairs accepted in the parameter list (see corresponding methods for details
[e.g. logger([$string])]):

=over 4

=item o input_file => $grammar_file_name

Read the grammar definition from this file.

The whole file is slurped in as a single string.

The parameter is mandatory.

See data/stringparser.grammar.bnf for a sample.

Default: ''.

=item o logger => $logger_object

Specify a logger object.

The default value triggers creation of an object of type L<Log::Handler> which outputs to the screen.

To disable logging, just set I<logger> to the empty string.

The value for I<logger> is passed to L<Graph::Easy::Marpa::Parser> and to L<Graph::Easy::Marpa::Renderer::Parser>.

Default: undef.

=item o maxlevel => $level

This option is only used if an object of type L<Log::Handler> is created. See I<logger> above.

See also L<Log::Handler::Levels>.

The value for I<maxlevel> is passed to L<Graph::Easy::Marpa::Parser> and to L<Graph::Easy::Marpa::Renderer::Parser>.

Default: 'info'. A typical value is 'debug'.

=item o minlevel => $level

This option is only used if an object of type L<Log::Handler> is created. See I<logger> above.

See also L<Log::Handler::Levels>.

The value for I<minlevel> is passed to L<Graph::Easy::Marpa::Parser> and to L<Graph::Easy::Marpa::Renderer::Parser>.

Default: 'error'.

No lower levels are used.

=item o tree_file => $file_name

The name of the text file to write containing the grammar as a tree.

The output is generated by L<Tree::DAG_Node>'s C<tree2string()> method.

If '', the file is not written.

Default: ''.

=back

=head1 Methods

=head2 input_file([$graph_file_name])

Here, the [] indicate an optional parameter.

Get or set the name of the file to read the grammar definition from.

The whole file is slurped in as a single string.

The parameter is mandatory.

See data/stringparser.grammar.bnf for a sample.

Note: C<input_file> is a parameter to new().

=head2 log($level, $s)

Calls $self -> logger -> log($level => $s) if ($self -> logger).

=head2 logger([$logger_object])

Here, the [] indicate an optional parameter.

Get or set the logger object.

To disable logging, just set logger to the empty string.

This logger is passed to L<Graph::Easy::Marpa::Parser> and L<Graph::Easy::Marpa::Renderer::Parser>.

Note: C<logger> is a parameter to new().

=head2 maxlevel([$string])

Here, the [] indicate an optional parameter.

Get or set the value used by the logger object.

This option is only used if an object of type L<Log::Handler> is created. See L<Log::Handler::Levels>.

Note: C<maxlevel> is a parameter to new().

=head2 minlevel([$string])

Here, the [] indicate an optional parameter.

Get or set the value used by the logger object.

This option is only used if an object of type L<Log::Handler> is created. See L<Log::Handler::Levels>.

Note: C<minlevel> is a parameter to new().

=head2 root()

Returns the root node, of type L<Tree::DAG_Node>, of the tree of items in the input stream's BNF.

=head2 tree_file([$output_file_name])

Here, the [] indicate an optional parameter.

Get or set the name of the file to which the tree form of the graph will be written.

If no output file is supplied, nothing is written.

Note: C<tree_file> is a parameter to new().

=head1 FAQ

=head1 Machine-Readable Change Log

The file Changes was converted into Changelog.ini by L<Module::Metadata::Changes>.

=head1 Version Numbers

Version numbers < 1.00 represent development versions. From 1.00 up, they are production versions.

=head1 Support

Email the author, or log a bug on RT:

L<https://rt.cpan.org/Public/Dist/Display.html?Name=MarpaX::Grammar::Parser>.

=head1 Author

L<MarpaX::Grammar::Parser> was written by Ron Savage I<E<lt>ron@savage.net.auE<gt>> in 2013.

Home page: L<http://savage.net.au/>.

=head1 Copyright

Australian copyright (c) 2013, Ron Savage.

	All Programs of mine are 'OSI Certified Open Source Software';
	you can redistribute them and/or modify them under the terms of
	The Artistic License, a copy of which is available at:
	http://www.opensource.org/licenses/index.html

=cut
