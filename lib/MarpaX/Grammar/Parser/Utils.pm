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
		$indent = '    ' x $depth;

		# Quote non-words.

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

L<MarpaX::Grammar::Parser::Utils> - Helps analyze the output of parsing metag.bnf

=head1 Synopsis

This module is only for use by the author of C<MarpaX::Grammar::Parser>.

See scripts/tree.dump.pl.

=head1 Description

Help analyze the output of parsing metag.bnf.

It is not expected that end-users would ever need to use this module.

=head1 Constructor and Initialization

=head2 Calling new()

C<new()> is called as C<< my($obj) = MarpaX::Grammar::Parser::Utils -> new() >>.

It returns a new object of type C<MarpaX::Grammar::Parser::Utils>.

=head1 Methods

=head2 print_tree()

Prints bits and pieces of a L<Tree::DAG_Node> tree.

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
