package MarpaX::Grammar::Parser;

use strict;
use utf8;
use warnings;
use warnings  qw(FATAL utf8);    # Fatalize encoding glitches.
use open      qw(:std :utf8);    # Undeclared streams in UTF-8.
use charnames qw(:full :short);  # Unneeded in v5.16.

use Data::TreeDumper ();               # For DumpTree().
use Data::TreeDumper::Renderer::Marpa; # Used by DumpTree().

use Log::Handler;

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

our $VERSION = '1.01';

# ------------------------------------------------

sub BUILD
{
	my($self)  = @_;

	die "No Marpa BNF file provided\n" if (! $self -> marpa_bnf_file);
	die "No user BNF file provided\n"  if (! $self -> user_bnf_file);

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
			attributes => {level => 0, type => 'class'},
			name       => 'statements',
		})
	);

} # End of BUILD.

# --------------------------------------------------

sub compress_branch
{
	my($self, $index, $a_node) = @_;

	my($name);

	$a_node -> walk_down
	({
		callback => sub
		{
			my($node, $option) = @_;
			$name = $node -> name;

			if ($name eq 'default_rule')
			{
				$self -> process_default_rule($index, $node);
			}
			elsif ($name eq 'discard_rule')
			{
				$self -> process_discard_rule($index, $node);
			}
			elsif ($name =~ /(.+)_event_declaration$/)
			{
				$self -> process_event_declaration($index, $node, $1);
			}
			elsif ($name eq 'lexeme_default_statement')
			{
				$self -> process_lexeme_default($index, $node);
			}
			elsif ($name eq 'lexeme_rule')
			{
				$self -> process_lexeme_rule($index, $node);
			}
			elsif ($name eq 'priority_rule')
			{
				$self -> process_priority_rule($index, $node);
			}
			elsif ($name eq 'quantified_rule')
			{
				$self -> process_quantified_rule($index, $node);
			}
			elsif ($name eq 'start_rule')
			{
				$self -> process_start_rule($index, $node);
			}

			return 1; # Keep walking.
		},
		_depth => 0,
	});

} # End of compress_branch.

# --------------------------------------------------

sub compress_tree
{
	my($self) = @_;

	# Phase 1: Process the children of the root:
	# o First daughter is offset of start within input stream.
	# o Second daughter is offset of end within input stream.
	# o Remainder are statements.

	my(@daughters) = $self -> raw_tree -> daughters;
	my($start)    = (shift @daughters) -> name;
	my($end)      = (shift @daughters) -> name;

	# Phase 2: Process each statement.

	for my $index (0 .. $#daughters)
	{
		$self -> compress_branch($index + 1, $daughters[$index]);
	}

} # End of compress_tree.

# --------------------------------------------------

sub log
{
	my($self, $level, $s) = @_;

	$self -> logger -> log($level => $s) if ($self -> logger);

} # End of log.

# --------------------------------------------------

sub process_default_rule
{
	my($self, $index, $a_node) = @_;
	my(%map) =
	(
		action   => 'action',
		blessing => 'bless',
	);

	my($name);
	my(@token);

	$a_node -> walk_down
	({
		callback => sub
		{
			my($node, $option) = @_;
			$name = $node -> name;

			return 1 if ($name =~ /^\d+$/);

			if ($node -> mother -> name =~ /op_declare_+/)
			{
				push @token, ':default', $name;
			}
			elsif ($node -> mother -> mother -> name =~ /(action|blessing)_name/)
			{
				push @token, $map{$1}, '=>', $name;
			}

			return 1; # Keep walking.
		},
		_depth => 0,
	});

	$self -> log(info => join(' ', @token) );

} # End of process_default_rule.

# --------------------------------------------------

sub process_discard_rule
{
	my($self, $index, $a_node) = @_;

	my($name);
	my(@token);

	$a_node -> walk_down
	({
		callback => sub
		{
			my($node, $option) = @_;
			$name = $node -> name;

			return 1 if ($name =~ /^\d+$/);

			if ($node -> mother -> mother -> name eq 'symbol_name')
			{
				push @token, ':discard', '=>', $name;
			}

			return 1; # Keep walking.
		},
		_depth => 0,
	});

	$self -> log(info => join(' ', @token) );

} # End of process_discard_rule.

# --------------------------------------------------

sub process_event_declaration
{
	my($self, $index, $a_node, $type) = @_;
	my(%type) =
	(
		completion => 'completed',
		nulled     => 'nulled',
		prediction => 'prediction',
	);

	my($name);
	my(@token);

	$a_node -> walk_down
	({
		callback => sub
		{
			my($node, $option) = @_;
			$name = $node -> name;

			return 1 if ($name =~ /^\d+$/);

			if ($node -> mother -> mother -> name eq 'event_name')
			{
				push @token, 'event', $name, '=', $type{$type};
			}
			elsif ($node -> mother -> mother -> name eq 'symbol_name')
			{
				push @token, $name;
			}

			return 1; # Keep walking.
		},
		_depth => 0,
	});

	$self -> log(info => join(' ', @token) );

} # End of process_event_declaration.

# --------------------------------------------------

sub process_lexeme_default
{
	my($self, $index, $a_node) = @_;
	my(%map) =
	(
		action   => 'action',
		blessing => 'bless',
	);
	my(@token) = ('lexeme default', '=');

	my($name);

	$a_node -> walk_down
	({
		callback => sub
		{
			my($node, $option) = @_;
			$name = $node -> name;

			return 1 if ($name =~ /^\d+$/);

			if ($node -> mother -> mother -> name =~ /(action|blessing)_name/)
			{
				push @token, $map{$1}, '=>', $name;
			}

			return 1; # Keep walking.
		},
		_depth => 0,
	});

	$self -> log(info => join(' ', @token) );

} # End of process_lexeme_default.

# --------------------------------------------------

sub process_lexeme_rule
{
	my($self, $index, $a_node) = @_;
	my(@token) = (':lexeme', '~');

	my($name);

	$a_node -> walk_down
	({
		callback => sub
		{
			my($node, $option) = @_;
			$name = $node -> name;

			return 1 if ($name =~ /^\d+$/);

			if ($node -> mother -> mother -> name eq 'event_name')
			{
				push @token, 'event', '=>', $name;
			}
			elsif ($node -> mother -> mother -> name eq 'pause_specification')
			{
				push @token, 'pause', '=>', $name;
			}
			elsif ($node -> mother -> mother -> name eq 'symbol_name')
			{
				push @token, $name;
			}

			return 1; # Keep walking.
		},
		_depth => 0,
	});

	$self -> log(info => join(' ', @token) );

} # End of process_lexeme_rule.

# --------------------------------------------------

sub process_parenthesized_list
{
	my($self, $index, $a_node, $depth_under) = @_;

	my($name);
	my(@rhs);

	$a_node -> walk_down
	({
		callback => sub
		{
			my($node, $option) = @_;
			$name = $node -> name;

			return 1 if ($name =~ /^\d+$/);

			if ($$option{_depth} == $depth_under)
			{
				push @rhs, $name;
			}

			return 1; # Keep walking.
		},
		_depth => 0,
	});

	$rhs[0]     = "($rhs[0]";
	$rhs[$#rhs] = "$rhs[$#rhs])";

	return [@rhs];

} # End of process_parenthesized_list.

# --------------------------------------------------

sub process_priority_rule
{
	my($self, $index, $a_node) = @_;

	my($alternative_count) = 0;

	my($continue);
	my($depth_under);
	my($name);
	my(@token);

	$a_node -> walk_down
	({
		callback => sub
		{
			my($node, $option) = @_;
			$name     = $node -> name;
			$continue = 1;

			return $continue if ($name =~ /^\d+$/);

			if ($node -> mother -> mother -> name eq 'action_name')
			{
				push @token, 'action', '=>', $name;
			}
			elsif ($name eq 'alternative')
			{
				$alternative_count++;

				push @token, '|' if ($alternative_count > 1);
			}
			elsif ($node -> mother -> mother -> name eq 'blessing_name')
			{
				push @token, 'bless', '=>', $name;
			}
			elsif ($node -> mother -> name eq 'character_class')
			{
				push @token, $name;
			}
			elsif ($node -> mother -> name =~ /op_declare_+/)
			{
				push @token, $name;
			}
			elsif ($name eq 'parenthesized_rhs_primary_list')
			{
				$continue    = 0;
				$depth_under = $node -> depth_under;

				push @token, @{$self -> process_parenthesized_list($index, $node, $depth_under)};
			}
			elsif ($node -> mother -> name eq 'single_quoted_string')
			{
				push @token, $name;
			}
			elsif ($node -> mother -> mother -> name eq 'symbol_name')
			{
				push @token, $name;
			}

			return $continue;
		},
		_depth => 0,
	});

	$self -> log(info => join(' ', @token) );

} # End of process_priority_rule.

# --------------------------------------------------

sub process_quantified_rule
{
	my($self, $index, $a_node) = @_;

	my($name);
	my(@token);

	$a_node -> walk_down
	({
		callback => sub
		{
			my($node, $option) = @_;
			$name = $node -> name;

			return 1 if ($name =~ /^\d+$/);

			if ($node -> mother -> mother -> name eq 'action_name')
			{
				push @token, 'action', '=>', $name;
			}
			elsif ($node -> mother -> name eq 'character_class')
			{
				push @token, $name;
			}
			elsif ($node -> mother -> name =~ /op_declare_+/)
			{
				push @token, $name;
			}
			elsif ($node -> mother -> name eq 'quantifier')
			{
				$token[$#token] .= $name;
			}
			elsif ($node -> mother -> mother -> name eq 'separator_specification')
			{
				push @token, 'separator', '=>';
			}
			elsif ($node -> mother -> mother -> name eq 'symbol_name')
			{
				push @token, $name;
			}

			return 1; # Keep walking.
		},
		_depth => 0,
	});

	$self -> log(info => join(' ', @token) );

} # End of process_quantified_rule.

# --------------------------------------------------

sub process_start_rule
{
	my($self, $index, $a_node) = @_;

	my($name);
	my(@token);

	$a_node -> walk_down
	({
		callback => sub
		{
			my($node, $option) = @_;
			$name = $node -> name;

			return 1 if ($name =~ /^\d+$/);

			if ($node -> mother -> mother -> name eq 'symbol_name')
			{
				push @token, ':start', '::=', $name;
			}

			return 1; # Keep walking.
		},
		_depth => 0,
	});

	$self -> log(info => join(' ', @token) );

} # End of process_start_rule.

# ------------------------------------------------

sub run
{
	my($self)          = @_;
	my($package)       = 'MarpaX::Grammar::Parser::Dummy'; # This is actually included below.
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

package MarpaX::Grammar::Parser::Dummy;

our $VERSION = '1.00';

sub new{return {};}

#-------------------------------------------------

1;

=pod

=head1 NAME

C<MarpaX::Grammar::Parser> - Converts a Marpa grammar into a tree using Tree::DAG_Node

=head1 Synopsis

	use MarpaX::Grammar::Parser;

	my(%option) =
	(
		marpa_bnf_file => 'data/metag.bnf',   # Input.
		raw_tree_file  => 'data/my.raw.tree', # Output.
		user_bnf_file  => 'data/my.bnf',      # Input.
	);

	my($parser) = MarpaX::Grammar::Parser -> new(%option);

	$parser -> run;

	print map{"$_\n"} @{$parser -> raw_tree -> tree2string({no_attributes => 1})};

See data/metag.bnf for the BNF file which ships with L<Marpa::R2> V 2.066000.

See data/*.bnf for input files and data/*.tree for output files.

For help, run

	shell> perl -Ilib scripts/g2p.pl -h

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

=item o logger aLog::HandlerObject

By default, an object of type L<Log::Handler> is created which prints to STDOUT, but in this version nothing
is actually printed.

See C<maxlevel> and C<minlevel> below.

Set C<logger> to '' (the empty string) to stop a logger being created.

Default: undef.

=item o marpa_bnf_file aMarpaBNFFileName

Specify the name of Marpa's own BNF file. This file ships with L<Marpa::R2>, in the meta/ directory.
It's name is metag.bnf.

A copy, as of Marpa::R2 V 2.066000, ships with C<MarpaX::Grammar::Parser>. See data/metag.bnf.

This option is mandatory.

Default: ''.

=item o maxlevel logOption1

This option affects L<Log::Handler> objects.

See the L<Log::Handler::Levels> docs.

Default: 'info'.

=item o minlevel logOption2

This option affects L<Log::Handler> object.

See the L<Log::Handler::Levels> docs.

Default: 'error'.

No lower levels are used.

=item o no_attributes Boolean

Include (0) or exclude (1) attributes in the raw_tree_file output.

Default: 0.

=item o raw_tree_file aTextFileName

The name of the text file to write containing the grammar as a raw tree.

If '', the file is not written.

Default: ''.

=item o user_bnf_file aUserGrammarFileName

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

Get or set the name of the file to which the raw tree form of the user's grammar will be written.

If no output file is supplied, nothing is written.

See data/stringparser.tree for the output of processing Marpa's analysis of data/stringparser.bnf.

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

This is the output from processing Marpa's analysis of data/c.ast.bnf. It's 56,723 lines long, which indicates
the complexity of Peter's grammar for C.

The command to generate this file is:

	shell> scripts/g2p.sh c.ast

=item o data/json.1.bnf

It is part of L<MarpaX::Demo::JSONParser>, written as a gist by Peter Stuifzand.

See L<https://gist.github.com/pstuifzand/4447349>.

The output is data/json.1.tree.

=item o data/json.1.tree

This is the output from processing Marpa's analysis of data/json.1.bnf.

The command to generate this file is:

	shell> scripts/g2p.sh json.1

=item o data/json.2.bnf

It also is part of L<MarpaX::Demo::JSONParser>, written by Jeffrey Kegler as a reply to the gist above from Peter.

The output is data/json.2.tree.

=item o data/json.2.tree

This is the output from processing Marpa's analysis of data/json.2.bnf.

The command to generate this file is:

	shell> scripts/g2p.sh json.2

=item o data/metag.bnf.

This is a copy of L<Marpa::R2>'s BNF.

See L</marpa_bnf_file([$bnf_file_name])> above.

=item o data/stringparser.bnf.

This is a copy of L<MarpaX::Demo::StringParser>'s BNF.

The output is data/stringparser.tree.

See L</user_bnf_file([$bnf_file_name])> above.

=item o data/stringparser.tree

This is the output from processing Marpa's analysis of data/stringparser.bnf.

The command to generate this file is:

	shell> scripts/g2p.sh stringparser

See also the next item.

=item o data/stringparser.treedumper

This is the output of running:

	shell> perl scripts/metag.pl data/metag.bnf data/stringparser.bnf > data/stringparser.treedumper

That script, metag.pl, is discussed just below, and in the L</FAQ>.

=item o scripts/g2p.pl

This is a neat way of using the module. For help, run:

	shell> perl -Ilib scripts/g2p.pl -h

Of course you are also encouraged to include this module directly in your own code.

=item o scripts/g2p.sh

This is a quick way for me to run g2p.pl.

=item o scripts/metag.pl

This is Jeffrey Kegler's code. See the first FAQ question.

=item o scripts/pod2html.sh

This lets me quickly proof-read edits to the docs.

=back

=head1 FAQ

=head2 What are the attributes and name of each node in tree?

=over 4

=item o Attributes

=over 4

=item o level

This is the level in the tree of the 'current' node.

The root of the tree is level 0. All other nodes have the value of $level + 1, where $level (starting from 0) is
determined by L<Data::TreeDumper>.

=item o type

This indicates what type of node it is.  Values:

=over 4

=item o Grammar

'Grammar' means the node's name is an item from the user-specified grammar.

=item o Marpa

'Marpa' means that Marpa has assigned a class to the node, of the form:

	$class_name::$node_name

See data/stringparser.treedumper, which will make this much clearer.

C<$class_name> is a constant provided by this module, and is 'MarpaX::Grammar::Parser::Dummy'.

=back

=back

=item o Name

This is either an item from the user-specified grammar (when the attribute C<type> is 'Grammar') or
a Marpa-internal token (when the attribute C<type> is 'Marpa').

=back

=head2 Where did the basic code come from?

Jeffrey Kegler wrote it, and posted it on the Google Group dedicated to Marpa, on 2013-07-22,
in the thread 'Low-hanging fruit'. I modified it slightly for a module context.

The original code is shipped as scripts/metag.pl.

As you can see he uses a different way of reading the files, one which avoids loading a separate module.
I've standardized on L<Perl6::Slurp>, especially when I want utf8, and L<File::Slurp> when I want to read a
directory. Of course I try not to use both in the same module.

=head2 Why did you use Data::TreeDump?

It offered the output which was most easily parsed of the modules I tested.
The others were L<Data::Dumper>, L<Data::TreeDraw>, L<Data::TreeDumper> and L<Data::Printer>.

=head2 Why are some options/methods called raw_*?

See L</ToDo> below for details.

=head2 Where is Marpa's Homepage?

L<http://jeffreykegler.github.io/Ocean-of-Awareness-blog/>.

=head2 Are there any articles discussing Marpa?

Yes, many by its author, and several others. See Marpa's homepage, just above, and:

L<The Marpa Guide|http://marpa-guide.github.io/>, (in progress, by Peter Stuifzand and Ron Savage).

L<Parsing a here doc|http://peterstuifzand.nl/2013/04/19/parse-a-heredoc-with-marpa.html>, by Peter Stuifzand.

L<An update of parsing here docs|http://peterstuifzand.nl/2013/04/22/changes-to-the-heredoc-parser-example.html>, by Peter Stuifzand.

L<Conditional preservation of whitespace|http://savage.net.au/Ron/html/Conditional.preservation.of.whitespace.html>, by Ron Savage.

=head1 See Also

L<Marpa::Demo::JSONParser>.

L<Marpa::Demo::StringParser>.

L<MarpaX::Languages::C::AST>.

L<Data::TreeDumper>.

L<Log::Handler>.

=head1 ToDo

=over 4

=item o Compress the tree

=over 4

=item o Horizontal compression

At the moment, the first 2 children of each 'class' type node are the offset and length within the input stream
where the parser found each token. I want to move those into the attributes of the 3rd node, and hence remove
those 2 nodes at each level of the tree.

See data/stringparser.tree.

=item o Vertical compression

The tree contains many nodes which are artifacts of Marpa's processing method. I want to remove any nodes which
do not refer directly to items in the user's grammar.

=back

Together this will mean the remaining nodes can be used without further modification as input to my other module
L<Marpa::Grammar::GraphViz2>. The latter is on hold until I can effect these compressions, so don't be surprized
if that link fails.

When this work is done, there will be 2 new attributes in this module, cooked_tree() to return the root of the
compressed tree, and cooked_tree_file(), which will name the file to use to save the new tree to disk.

=back

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
	The Artistic License 2.0, a copy of which is available at:
	http://www.opensource.org/licenses/index.html

=cut
