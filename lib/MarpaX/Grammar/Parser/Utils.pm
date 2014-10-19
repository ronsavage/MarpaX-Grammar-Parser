package MarpaX::Grammar::Parser::Utils;

use strict;
use utf8;
use warnings;
use warnings  qw(FATAL utf8);    # Fatalize encoding glitches.
use open      qw(:std :utf8);    # Undeclared streams in UTF-8.
use charnames qw(:full :short);  # Unneeded in v5.16.

use List::AllUtils qw/any max/;

use Moo;

use Path::Tiny;   # For path().

use Types::Standard qw/Any HashRef Str/;

has logger =>
(
	default  => sub{return undef},
	is       => 'rw',
	isa      => Any,
	required => 0,
);

has maxlevel =>
(
	default  => sub{return 'notice'},
	is       => 'rw',
	isa      => Str,
	required => 0,
);

has minlevel =>
(
	default  => sub{return 'error'},
	is       => 'rw',
	isa      => Str,
	required => 0,
);

has raw_tree =>
(
	default  => sub{return ''},
	is       => 'rw',
	isa      => Any,
	required => 1,
);

has statements =>
(
	default  => sub{return {} },
	is       => 'rw',
	isa      => HashRef,
	required => 0,
);

our $VERSION = '1.04';

# ------------------------------------------------

sub BUILD
{
	my($self)  = @_;

	die "No raw_tree provided\n" if (! $self -> raw_tree);

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

# ------------------------------------------------

sub formatter
{
	my($self, $depth, $hashref) = @_;
	my(@keys)           = keys %$hashref;
	my($max_key_length) = max map{length} @keys;

	# If any key points to a hashref, do not try to line up the '=>' vertically,
	# because the dump of the hashref will make the padding useless.

	my($ref_present) = any {ref $$hashref{$_} } @keys; # $#refs >= 0 ? 1 : 0;

	my($indent);
	my($key_pad);
	my($pretty_key);
	my($line);

	for my $key (sort keys %$hashref)
	{
		$indent     = '    ' x $depth;
		$pretty_key = ($key =~ /^\w+$/) || ($key =~ /^\'/) ? $key : "'$key'";
		$key_pad    = ' ' x ($max_key_length - length($key) + 1);
		$key_pad    = ' ' if ($ref_present);
		$line       = "$indent$pretty_key$key_pad=>";

		if (ref $$hashref{$key})
		{
			$self -> log(info => $line);
			$self -> log(info => "$indent\{");

			$self -> formatter($depth + 1, $$hashref{$key});

			$self -> log(info => "$indent},");
		}
		else
		{
			$self -> log(info => "$line $$hashref{$key},");
		}
	}

} # End of formatter.

# --------------------------------------------------

sub log
{
	my($self, $level, $s) = @_;

	$self -> logger -> log($level => $s) if ($self -> logger);

} # End of log.

# ------------------------------------------------

sub report
{
	my($self) = @_;

	$self -> formatter(0, $self -> statements);

} # End of report.

# ------------------------------------------------

sub run
{
	my($self) = @_;

	my($name, @name);
	my(@stack);

	$self -> raw_tree -> walk_down
	({
		callback => sub
		{
			my($node, $option) = @_;
			@name = ();
			$name = $node -> name;

			return 1 if ( (length($name) == 0) || ($name =~ /^\d+$/) );

			while ($node -> is_root == 0)
			{
				push @name, $name;

				$node = $node -> mother;
				$name = $node -> name;
			}

			push @stack, join('|', reverse @name) if ($#name >= 0);

			return 1; # Keep walking.
		},
		_depth => 0,
	});

	@stack     = sort @stack;
	my($count) = 0;

	my($ref);
	my(%statements);

	for my $i (0 .. $#stack)
	{
		@name = split(/\|/, $stack[$i]);

		# Skip all but 1 elements in stack which just say 'statement'.

		if ($#name == 0)
		{
			next if (++$count > 1);
		}

		$ref            = \%statements;
		$$ref{$name[0]} = {} if (! $$ref{$name[0]});

		for my $j (1 .. $#name)
		{
			if ($j < $#name)
			{
				$ref             = $$ref{$name[$j - 1]};
				$$ref{$name[$j]} = {} if (! $$ref{$name[$j]});
			}
			else
			{
				$$ref{$name[$j - 1]}            = {} if (! ref $$ref{$name[$j - 1]});
				$$ref{$name[$j - 1]}{$name[$j]} = 1;
			}
		}
	}

	$self -> statements($statements{statement});
	$self -> report; # This prints nothing by default.

	# Return 0 for success and 1 for failure.

	return 0;

} # End of run.

# -----------------------------------------------

1;

=pod

=head1 NAME

C<MarpaX::Grammar::Parser::Utils> - Print, as a hash, the raw tree built by calling MarpaX::Grammar::Parser's run() method

=head1 Synopsis

	scripts/tree.dump.pl -marpa share/metag.bnf -r share/stringparser.raw.tree -u share/stringparser.bnf

Nothing is printed by default. See C<maxlevel> to 'info' to get the hashref printed on STDOUT.

For more help, run:

	scripts/tree.dump.pl -h

=head1 Description

This module prints its own interpretation of the raw tree.

The raw tree, as output by L<Marpa::R2> and stored in a L<Tree::DAG_Node> object, can also be
written to a file with the -raw_tree_file option.

This output is used to help me ensure all the cases output by Marpa are accounted for in
L<MarpaX::Grammar::Parser>.

=head1 Constructor and Initialization

Call L</new()>: C<< my($util) = MarpaX::Grammar::Parser::Utils -> new(k1 => v1, ...) >>.

It returns a new object of type C<MarpaX::Grammar::Parser::Utils>.

Key-value pairs accepted in the parameter list (see also the corresponding methods
[e.g. L</maxlevel(['info'])>]):

=over 4

=item o logger => a-Log::Handler-Object

By default, an object of type L<Log::Handler> is created which prints to STDOUT.

See C<maxlevel> and C<minlevel> below.

Set C<logger> to '' (the empty string) to stop a logger being created.

Default: undef.

=item o maxlevel => $level

This option is only used if this module creates an object of type L<Log::Handler>.

See L<Log::Handler::Levels>.

Nothing is printed by default. Set C<maxlevel> to 'info' to get the hashref printed on STDOUT.

Default: 'notice'.

=item o minlevel => $level

This option affects L<Log::Handler> object.

See L<Log::Handler::Levels>.

Default: 'error'.

No lower levels are used.

=item o raw_tree => $tree

This option is mandatory. The value supplied for $tree must be an object of type L<Tree::DAG_Node>,
as created by L<MarpaX::Grammar::Parser>.

See scripts/tree.dump.pl.

=back

=head1 Methods

=head2 formatter($depth, $hashref)

Formats the given hashref, with $depth (starting from 0) used to indent the output.

Outputs using calls to L</log($level, $s)>.

When you call L</report()>, it calls to C<< $self -> formatter(0, $self -> statements) >>.

End users would normally never call this method, and not override it. Just call L</report()>.

=head2 log($level, $s)

Calls $self -> logger -> log($level => $s) if ($self -> logger).

=head2 logger([$logger_object])

Here, the [] indicate an optional parameter.

Get or set the logger object.

To disable logging, just set logger to the empty string.

Note: C<logger> is a parameter to new().

=head2 maxlevel([$level])

Here, the [] indicate an optional parameter.

Get or set the value used by the logger object.

This option is only used if an object of type L<Log::Handler> is created.

See L<Log::Handler::Levels>.

Note: C<maxlevel> is a parameter to new().

=head2 minlevel([$level])

Here, the [] indicate an optional parameter.

Get or set the value used by the logger object.

This option is only used if an object of type L<Log::Handler> is created.

See L<Log::Handler::Levels>.

Note: C<minlevel> is a parameter to new().

=head2 new()

The constructor. See L</Constructor and Initialization>.

=head2 report()

Just calls C<< $self -> formatter(0, $self -> statements) >>, which in turn uses the logger
provided in the call to L</new()>.

=head2 raw_tree()

Returns the object of type L<Tree::DAG_Node> provided during the call to L</new()>.

=head2 run()

Constructs a hashref version of the L<Tree::DAG_Node> object created by getting Marpa to parse
a grammar.

This tree is output after calling L<MarpaX::Grammar::Parser>'s C<run()> method.

See L</statements()>.

=head2 statements()

Returns a hashref describing the grammar provided in the raw_tree parameter to L</new()>.

Only meaningful after L</run()> has been called.

The keys in the hashref are the types of statements found in the grammar, and the values for those
keys are either '1' to indicate the key exists, or a hashref.

The latter hashref's keys are all the sub-types of statements found in the grammar, for the given
statement.

The pattern of keys pointing to either '1' or a hashref, is repeated to whatever depth is required
to represent the tree.

=head1 FAQ

See also L<MarpaX::Grammar::Parser/FAQ>.

=head2 Why did you write your own dumping code?

I tried these fine modules: L<Data::Dumper>, L<Data::Dumper::Concise> (which is what I normally
use), and L<Data::Dump::Streamer>. Between them they have every option you'd want, but not the
ones I<I> wanted.

=head1 Version Numbers

Version numbers < 1.00 represent development versions. From 1.00 up, they are production versions.

=head1 Machine-Readable Change Log

The file Changes was converted into Changelog.ini by L<Module::Metadata::Changes>.

=head1 Support

Email the author, or log a bug on RT:

L<https://rt.cpan.org/Public/Dist/Display.html?Name=MarpaX::Grammar::Parser>.

=head1 Author

L<MarpaX::Grammar::Parser> was written by Ron Savage I<E<lt>ron@savage.net.auE<gt>> in 2013.

Marpa's homepage: L<http://savage.net.au/Marpa.html>.

Homepage: L<http://savage.net.au/index.html>.

=head1 Copyright

Australian copyright (c) 2013, Ron Savage.

	All Programs of mine are 'OSI Certified Open Source Software';
	you can redistribute them and/or modify them under the terms of
	The Artistic License, a copy of which is available at:
	http://www.opensource.org/licenses/index.html

=cut
