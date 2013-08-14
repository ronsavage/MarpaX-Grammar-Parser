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

has marpas_bnf_file =>
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

has users_bnf_file =>
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

	$self -> root
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
	my($self)           = @_;
	my($package)        = 'MarpaX::Grammar::Parser::Dummy';
	my $marpas_bnf      = slurp $self -> marpas_bnf_file, {utf8 => 1};
	my($marpas_grammar) = Marpa::R2::Scanless::G -> new({bless_package => $package, source => \$marpas_bnf});
	my $users_bnf       = slurp $self -> users_bnf_file, {utf8 => 1};
	my($recce)          = Marpa::R2::Scanless::R -> new({grammar => $marpas_grammar});

	$recce -> read(\$users_bnf);

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
			root    => $self -> root,
		}
	);

	my($tree_file) = $self -> tree_file;

	if ($tree_file)
	{
		open(OUT, '>', $tree_file) || die "Can't open(> $tree_file): $!\n";
		print OUT map{"$_\n"} @{$self -> root -> tree2string({no_attributes => $self -> no_attributes})};
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
		marpas_bnf_file => 'metag.bnf',
		tree_file       => 'my.tree',
		users_bnf_file  => 'my.bnf,
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

=head1 Files Shipped with this Module

=over 4

=item o data/json.1.bnf

It is part of the unreleased module MarpaX::Demo::JSON_1, written as a gist by Peter Stuifzand.

See L<https://gist.github.com/pstuifzand/4447349>.

=item o data/json.2.bnf

It is part of the unreleased module MarpaX::Demo::JSON_2, written by Jeffrey Kegler as a reply to gist from Peter.

=item o data/metag.bnf.

This is a copy of L<Marpa::R2>'s BNF.

See L</marpas_bnf_file([$bnf_file_name])> below.

=item o data/stringparser.bnf.

This is a copy of L<MarpaX::Demo::StringParser>'s BNF.

See L</users_bnf_file([$bnf_file_name])> below.

=item o data/stringparser.log

This is the output from parsing data/stringparser.bnf.

=back

=head1 Constructor and Initialization

C<new()> is called as C<< my($parser) = MarpaX::Grammar::Parser -> new(k1 => v1, k2 => v2, ...) >>.

It returns a new object of type C<MarpaX::Grammar::Parser>.

Key-value pairs accepted in the parameter list (see corresponding methods for details
[e.g. marpas_bnf_file([$string])]):

=over 4

=item o -logger aLog::HandlerObject

By default, an object is created which prints to STDOUT.

Set this to '' to stop logging.

Default: undef.

=item o -marpas_bnf_file aMarpaBNFFileName

Specify the name of Marpa's own BNF file.

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

=item o -tree_file aTextFileName

The name of the text file to write containing the grammar as a tree.

If '', the file is not written.

Default: ''.

=item o -users_bnf_file aUsersGrammarFileName

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

This logger is passed to L<Graph::Easy::Marpa::Parser> and L<Graph::Easy::Marpa::Renderer::Parser>.

Note: C<logger> is a parameter to new().

=head2 marpas_bnf_file([$bnf_file_name])

Here, the [] indicate an optional parameter.

Get or set the name of the file to read Marpa's grammar's BNF from.

The whole file is slurped in as a single string.

The parameter is mandatory.

This file ships with L<Marpa::R2>, in the meta/ directory. It's name is metag.bnf.

A copy, as of Marpa::R2 V 2.066000, ships with L<MarpaX::Grammar::Parser>.

See data/metag.bnf for a sample.

Note: C<marpas_bnf_file> is a parameter to new().

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

Get or set the option which includes (0) or excludes (1) from node attributes being included in the output
C<tree_file>.

Note: C<no_attributes> is a parameter to new().

=head2 root()

Returns the root node, of type L<Tree::DAG_Node>, of the tree of items in the user's BNF.

It is this tree which is optionally written to the file name given by L</tree_file([$output_file_name])>.

=head2 tree_file([$output_file_name])

Here, the [] indicate an optional parameter.

Get or set the name of the file to which the tree form of the user's grammar will be written.

If no output file is supplied, nothing is written.

See data/stringparser.log for the output of parsing data/stringparser.bnf.

This latter file is the grammar used in L<Marpa::Demo::StringParser>.

Note: C<tree_file> is a parameter to new().

=head2 users_bnf_file([$bnf_file_name])

Here, the [] indicate an optional parameter.

Get or set the name of the file to read the user's grammar's BNF from.

The whole file is slurped in as a single string.

The parameter is mandatory.

See data/stringparser.bnf for a sample. It is the grammar used in L<MarpaX::Demo::StringParser>.

Note: C<users_bnf_file> is a parameter to new().

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

Yes.

See Marpa's home page, mentioned just above.

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

L<Data::TreeDumper>.

L<MarpaX::Grammar::Parser>.

L<Marpa::Demo::StringParser>.

L<MarpaX::Languages::C::AST>.

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
