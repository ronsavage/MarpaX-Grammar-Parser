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

our $VERSION = '1.04';

# ------------------------------------------------

sub report
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

	for my $key (sort keys %$hashref)
	{
		$indent     = '    ' x $depth;
		$pretty_key = ($key =~ /^\w+$/) || ($key =~ /^\'/) ? $key : "'$key'";
		$key_pad    = ' ' x ($max_key_length - length($key) + 1);
		$key_pad    = ' ' if ($ref_present);

		print "$indent$pretty_key$key_pad=> ";

		if (ref $$hashref{$key})
		{
			print "\n$indent\{\n";

			$self -> report($depth + 1, $$hashref{$key});

			print "$indent},\n";
		}
		else
		{
			print "$$hashref{$key},\n";
		}
	}

} # End of report.

# ------------------------------------------------

sub run
{
	my($self, %params) = @_;

	my($name, @name);
	my(@stack);

	$params{raw_tree} -> walk_down
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

	$self -> report(0, \%statements);

	return 0;

} # End of run.

# -----------------------------------------------

1;

=pod

=head1 NAME

C<MarpaX::Grammar::Parser::Utils> - Print, as a hash, the raw tree built by calling L<MarpaX::Grammar::Parser>'s C<run()> method

=head1 Synopsis

	scripts/tree.dump.pl -m share/metag.bnf -r share/stringparser.raw.tree -u share/stringparser.bnf > stringparser.log

See scripts/tree.dump.pl.

=head1 Description

This module prints its own interpretation of the raw tree.

The raw tree, as output by Marpa, can also be written to a file with the -raw_tree_file option.

This output is used to help me ensure all the cases output by L<Marpa::R2> are accounted for in
C<MarpaX::Grammar::Parser>.

=head1 Constructor and Initialization

=head2 Calling new()

C<new()> is called as C<< my($obj) = MarpaX::Grammar::Parser::Utils -> new() >>.

It returns a new object of type C<MarpaX::Grammar::Parser::Utils>.

=head1 Methods

=head2 run(%params)

Prints a hashref version of the L<Tree::DAG_Node> object created by getting Marpa to parse a grammar.

This tree is output from L<MarpaX::Grammar::Parser>'s C<run()> method.

Keys in %params:

=over 4

=item o raw_tree

The value for this key is the raw tree built when L<MarpaX::Grammar::Parser>'s C<run()> method is called.

See scripts/tree.dump.pl.

=back

=head1 FAQ

See also L<MarpaX::Grammar::Parser/FAQ>.

=head2 Why did you write your own dumping code?

I tried these fine modules: L<Data::Dumper>, L<Data::Dumper::Concise> (which is what I normally use), and
L<Data::Dump::Streamer>. Between them they have every option you'd want, but not the ones I<I> wanted.

=head1 Version Numbers

Version numbers < 1.00 represent development versions. From 1.00 up, they are production versions.

=head1 Machine-Readable Change Log

The file Changes was converted into Changelog.ini by L<Module::Metadata::Changes>.

=head1 Support

Email the author, or log a bug on RT:

L<https://rt.cpan.org/Public/Dist/Display.html?Name=MarpaX::Grammar::Parser>.

=head1 Author

L<MarpaX::Grammar::Parser> was written by Ron Savage I<E<lt>ron@savage.net.auE<gt>> in 2013.

Home page: L<http://savage.net.au/index.html>.

=head1 Copyright

Australian copyright (c) 2013, Ron Savage.

	All Programs of mine are 'OSI Certified Open Source Software';
	you can redistribute them and/or modify them under the terms of
	The Artistic License, a copy of which is available at:
	http://www.opensource.org/licenses/index.html

=cut
