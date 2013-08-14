package MarpaX::Grammar::Parser;

use strict;
use utf8;
use warnings;
use warnings  qw(FATAL utf8);    # Fatalize encoding glitches.
use open      qw(:std :utf8);    # Undeclared streams in UTF-8.
use charnames qw(:full :short);  # Unneeded in v5.16.

use Data::TreeDumper ();               # For DumpTree().
use Data::TreeDumper::Renderer::Marpa; # Used by DumpTree().

use English '-no_match_vars';

use Log::Handler;

use MarpaX::Grammar::Parser::Dummy;
use Marpa::R2;

use Moo;

use Perl6::Slurp; # For slurp().

use Tree::DAG_Node;

has logger =>
(
	default  => sub{return undef},
	is       => 'rw',
#	isa      => 'Str',
	required => 0,
);

has marpa_bnf_file =>
(
	default  => sub{return ''},
	is       => 'rw',
	#isa     => 'Str',
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

has raw_tree =>
(
	default  => sub{return ''},
	is       => 'rw',
	#isa     => 'Tree::DAG_Node',
	required => 0,
);

has raw_tree_file =>
(
	default  => sub{return ''},
	is       => 'rw',
	#isa     => 'Str',
	required => 0,
);

has user_bnf_file =>
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

	$self -> raw_tree
	(
		Tree::DAG_Node -> new
		({
			attributes => {},
			name       => 'statements',
		})
	);

} # End of BUILD.

# --------------------------------------------------

sub log
{
	my($self, $level, $s) = @_;

	$self -> logger -> log($level => $s) if ($self -> logger);

} # End of log.

# ------------------------------------------------

sub run
{
	my($self)          = @_;
	my($package)       = 'MarpaX::Grammar::Parser::Dummy';
	my $marpa_bnf      = slurp $self -> marpa_bnf_file, {utf8 => 1};
	my($marpa_grammar) = Marpa::R2::Scanless::G -> new({bless_package => $package, source => \$marpa_bnf});
	my $user_bnf       = slurp $self -> user_bnf_file, {utf8 => 1};
	my($recce)         = Marpa::R2::Scanless::R -> new({grammar => $marpa_grammar});

	$recce -> read(\$user_bnf);

	Data::TreeDumper::DumpTree
	(
		${$recce -> value},
		'', # No title since Data::TreeDumper::Renderer::Marpa prints nothing.
		DISPLAY_ROOT_ADDRESS => 1,
		NO_WRAP              => 1,
		RENDERER             =>
		{
			NAME    => 'Marpa',  # I.e.: Data::TreeDumper::Renderer::Marpa.
			package => $package, # I.e.: MarpaX::Grammar::Parser::Dummy.
			root    => $self -> raw_tree,
		}
	);

	my($raw_tree_file) = $self -> raw_tree_file;

	if ($raw_tree_file)
	{
		open(OUT, '>', $raw_tree_file) || die "Can't open(> $raw_tree_file): $!\n";
		print OUT map{"$_\n"} @{$self -> raw_tree -> tree2string({no_attributes => $self -> no_attributes})};
		close OUT;
	}

	# Return 0 for success and 1 for failure.

	return 0;

} # End of run.

# ------------------------------------------------

1;

=pod

=head1 NAME

C<MarpaX::Grammar::Parser> - Converts a Marpa grammar into a tree using Tree::DAG_Node

=head1 Synopsis

	use MarpaX::Grammar::Parser;

	my(%option) =
	(
		marpa_bnf_file => 'metag.bnf',
		raw_tree_file  => 'my.raw.tree',
		user_bnf_file  => 'my.bnf,
	);

	MarpaX::Grammar::Parser -> new(%option) -> run;

=head1 Description

=head1 Installation

Install C<MarpaX::Grammar::Parser> as you would for any C<Perl> module:

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

=head1 Constructor and Initialization

C<new()> is called as C<< my($parser) = MarpaX::Grammar::Parser -> new(k1 => v1, k2 => v2, ...) >>.

It returns a new object of type C<MarpaX::Grammar::Parser>.

Key-value pairs accepted in the parameter list (see corresponding methods for details
[e.g. marpa_bnf_file([$string])]):

=over 4

=item o -logger aLog::HandlerObject

By default, an object of type L<Log::Handler> is created which prints to STDOUT, but nothing is actually printed.

See C<maxlevel> and C<minlevel> below.

Set C<logger> to '' to stop logging.

Default: undef.

=item o -marpa_bnf_file aMarpaBNFFileName

Specify the name of Marpa's own BNF file. This file ships with L<Marpa::R2>, in the meta/ directory.
It's name is metag.bnf.

A copy, as of Marpa::R2 V 2.066000, ships with C<MarpaX::Grammar::Parser>. See data/metag.bnf.

This option is mandatory.

Default: ''.

=item o -maxlevel logOption1

This option affects L<Log::Handler> objects.

See the L<Log::Handler::Levels> docs.

Default: 'info'.

=item o -minlevel logOption2

This option affects L<Log::Handler> object.

See the L<Log::Handler::Levels> docs.

Default: 'error'.

No lower levels are used.

=item o -no_attributes Boolean

Include (0) or exclude (1) attributes in the raw_tree_file output.

Default: 0.

=item o -raw_tree_file aTextFileName

The name of the text file to write containing the grammar as a tree.

If '', the file is not written.

Default: ''.

=item o -user_bnf_file aUserGrammarFileName

Specify the name of the file containing your Marpa::R2-style grammar.

See data/stringparser.bnf for a sample.

This option is mandatory.

Default: ''.

=back

=head1 Installing the module

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
	make (or dmake)
	make test
	make install

=head1 Methods

=head2 log($level, $s)

Calls $self -> logger -> log($level => $s) if ($self -> logger).

=head2 logger([$logger_object])

Here, the [] indicate an optional parameter.

Get or set the logger object.

To disable logging, just set logger to the empty string.

Note: C<logger> is a parameter to new().

=head2 marpa_bnf_file([$bnf_file_name])

Here, the [] indicate an optional parameter.

Get or set the name of the file to read Marpa's grammar's BNF from. The whole file is slurped in as a single string.

The parameter is mandatory.

This file ships with L<Marpa::R2>, in the meta/ directory. It's name is metag.bnf.

A copy, as of Marpa::R2 V 2.066000, ships with L<MarpaX::Grammar::Parser>.

See data/metag.bnf for a sample.

Note: C<marpa_bnf_file> is a parameter to new().

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

=head2 no_attributes([$Boolean])

Here, the [] indicate an optional parameter.

Get or set the option which includes (0) or excludes (1) node attributes from being included in the output
C<raw_tree_file>.

Note: C<no_attributes> is a parameter to new().

=head2 raw_tree()

Returns the root node, of type L<Tree::DAG_Node>, of the raw tree of items in the user's BNF.

By raw tree, I mean as derived directly from Marpa. Later, a cooked_tree() method will be provided,
for a compressed version of the tree.

The raw tree is optionally written to the file name given by L</raw_tree_file([$output_file_name])>.

=head2 raw_tree_file([$output_file_name])

Here, the [] indicate an optional parameter.

Get or set the name of the file to which the tree form of the user's grammar will be written.

If no output file is supplied, nothing is written.

See data/stringparser.tree for the output of parsing data/stringparser.bnf.

This latter file is the grammar used in L<Marpa::Demo::StringParser>.

Note: C<raw_tree_file> is a parameter to new().

=head2 user_bnf_file([$bnf_file_name])

Here, the [] indicate an optional parameter.

Get or set the name of the file to read the user's grammar's BNF from. The whole file is slurped in as a single string.

The parameter is mandatory.

See data/stringparser.bnf for a sample. It is the grammar used in L<MarpaX::Demo::StringParser>.

Note: C<user_bnf_file> is a parameter to new().

=head1 Files Shipped with this Module

=over 4

=item o data/c.ast.bnf

This is part of L<MarpaX::Languages::C::AST>, by Peter Stuifzand. It's 1,565 lines long.

The output is data/c.ast.tree.

=item o data/c.ast.tree

This is the output from parsing data/c.ast.bnf. It's 56,723 lines long, which indicates the complexity of
Peter's grammar for C.

=item o data/json.1.bnf

It is part of L<MarpaX::Demo::JSON_1>, written as a gist by Peter Stuifzand.

See L<https://gist.github.com/pstuifzand/4447349>.

The output is data/json.1.tree.

=item o data/json.1.tree

This is the output from parsing data/json.1.bnf.

=item o data/json.2.bnf

It is part of L<MarpaX::Demo::JSON_2>, written by Jeffrey Kegler as a reply to the gist above from Peter.

The output is data/json.2.tree.

=item o data/json.2.tree

This is the output from parsing data/json.2.bnf.

=item o data/metag.bnf.

This is a copy of L<Marpa::R2>'s BNF.

See L</marpa_bnf_file([$bnf_file_name])> below.

=item o data/stringparser.bnf.

This is a copy of L<MarpaX::Demo::StringParser>'s BNF.

The output is data/stringparser.tree.

See L</user_bnf_file([$bnf_file_name])> below.

=item o data/stringparser.tree

This is the output from parsing data/stringparser.bnf.

See also the next item.

=item o data/stringparser.treedumper

This is the I<default> output from parsing data/stringparser.bnf, as generated by L<Data::TreeDumper>.

In other words, if you run:

	perl -Ilib scripts/g2p.pl -marpa_bnf data/metag.bnf -n 1 \
		-tree data/stringparser.tree -user_bnf data/stringparser.bnf

The output is data/stringparser.tree.

But if you patch sub run() as below, and run:

	perl -Ilib scripts/g2p.pl -marpa_bnf data/metag.bnf -n 1 \
		-user_bnf data/stringparser.bnf > data/stringparser.treedumper

The output is data/stringparser.treedumper.

Then you can compare the latter (the default) output of L<Data::TreeDumper> with the output from this module.

Patch run() from this (which returns the tree but prints nothing):

	Data::TreeDumper::DumpTree
	(
		${$recce -> value},
		'', # No title since Data::TreeDumper::Renderer::Marpa prints nothing.
		DISPLAY_ROOT_ADDRESS => 1,
		NO_WRAP              => 1,
		RENDERER             =>
		{
			NAME    => 'Marpa',  # I.e.: Data::TreeDumper::Renderer::Marpa.
			package => $package, # I.e.: MarpaX::Grammar::Parser::Dummy.
			root    => $self -> raw__tree,
		}
	);

To this (which just prints the default output):

	print Data::TreeDumper::DumpTree
	(
		${$recce -> value},
		'', # No title since Data::TreeDumper::Renderer::Marpa prints nothing.
		DISPLAY_ROOT_ADDRESS => 1,
		NO_WRAP              => 1,
	#	RENDERER             =>
	#	{
	#		NAME    => 'Marpa',  # I.e.: Data::TreeDumper::Renderer::Marpa.
	#		package => $package, # I.e.: MarpaX::Grammar::Parser::Dummy.
	#		root    => $self -> raw_tree,
	#	}
	);

=back

=head1 FAQ

=head2 Where did the basic code come from?

Jeffrey Kegler wrote it, and posted it on the Google Group dedicated to Marpa, on 2013-07-22,
in the thread 'Low-hanging fruit'. I modified it slightly for a module context.

=head2 Why did you use Data::TreeDump?

It offered the output which was most easily parsed of the modules I tested.
The others were L<Data::Dumper>, L<Data::TreeDraw>, L<Data::TreeDumper> and L<Data::Printer>.

=head2 Where is Marpa's Home Page?

L<http://jeffreykegler.github.io/Ocean-of-Awareness-blog/metapages/annotated.html>.

=head2 Are there any articles discussing Marpa?

Yes, many by the author, and several others.

See Marpa's home page, mentioned just above.

See L<The Marpa Guide|http://marpa-guide.github.io/>.

See L<Parsing a here doc|http://peterstuifzand.nl/2013/04/19/parse-a-heredoc-with-marpa.html> by Peter Stuifzand.

See L<Conditional preservation of whitespace|http://savage.net.au/Ron/html/Conditional.preservation.of.whitespace.html> by Ron Savage.

=head1 Machine-Readable Change Log

The file Changes was converted into Changelog.ini by L<Module::Metadata::Changes>.

=head1 Version Numbers

Version numbers < 1.00 represent development versions. From 1.00 up, they are production versions.

=head1 Support

Email the author, or log a bug on RT:

L<https://rt.cpan.org/Public/Dist/Display.html?Name=MarpaX::Grammar::Parser>.

=head1 See Also

L<Marpa::Demo::JSON_1>.

L<Marpa::Demo::JSON_2>.

L<Marpa::Demo::StringParser>.

L<MarpaX::Languages::C::AST>.

L<Data::TreeDumper>.

L<Log::Handler>.

=head1 Author

L<MarpaX::Grammar::Parser> was written by Ron Savage I<E<lt>ron@savage.net.auE<gt>> in 2013.

Home page: L<http://savage.net.au/>.

=head1 Copyright

Australian copyright (c) 2013, Ron Savage.

	All Programs of mine are 'OSI Certified Open Source Software';
	you can redistribute them and/or modify them under the terms of
	The Artistic License 2.0, a copy of which is available at:
	http://www.opensource.org/licenses/index.html

=cut
