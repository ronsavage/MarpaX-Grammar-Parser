package MarpaX::Grammar::Parser;

use strict;
use utf8;
use warnings;
use warnings  qw(FATAL utf8);    # Fatalize encoding glitches.
use open      qw(:std :utf8);    # Undeclared streams in UTF-8.
use charnames qw(:full :short);  # Unneeded in v5.16.

use Data::RenderAsTree;

use File::Slurp; # For read_file().

use List::AllUtils qw/any max/;

use Log::Handler;

use Marpa::R2;

use Moo;

use Set::Array;

use Tree::DAG_Node;

use Types::Standard qw/Any Bool HashRef Int Object Str/;

has bind_attributes =>
(
	default  => sub{return 0},
	is       => 'rw',
	isa      => Bool,
	required => 0,
);

has cooked_tree =>
(
	default  => sub{return Tree::DAG_Node -> new({name => 'Statements'})},
	is       => 'rw',
	isa      => Object,
	required => 0,
);

has cooked_tree_file =>
(
	default  => sub{return ''},
	is       => 'rw',
	isa      => Str,
	required => 0,
);

has first_rule =>
(
	default  => sub{return ''},
	is       => 'rw',
	isa      => Str,
	required => 0,
);

has logger =>
(
	default  => sub{return undef},
	is       => 'rw',
	isa      => Any,
	required => 0,
);

has marpa_bnf_file =>
(
	default  => sub{return ''},
	is       => 'rw',
	isa      => Str,
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

has node_stack =>
(
	default  => sub{return Set::Array -> new},
	is       => 'rw',
	isa      => Object,
	required => 0,
);

has raw_tree =>
(
	default  => sub{return ''},
	is       => 'rw',
	isa      => Any,
	required => 0,
);

has raw_tree_file =>
(
	default  => sub{return ''},
	is       => 'rw',
	isa      => Str,
	required => 0,
);

has statements =>
(
	default  => sub{return {} },
	is       => 'rw',
	isa      => HashRef,
	required => 0,
);

has uid =>
(
	default  => sub{return 0},
	is       => 'rw',
	isa      => Int,
	required => 0,
);

has user_bnf_file =>
(
	default  => sub{return ''},
	is       => 'rw',
	isa      => Str,
	required => 0,
);

our $VERSION = '2.00';

# ------------------------------------------------

sub BUILD
{
	my($self)  = @_;

	die "No Marpa BNF file found\n" if (! -e $self -> marpa_bnf_file);
	die "No user BNF file found\n"  if (! -e $self -> user_bnf_file);

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

	$self -> node_stack -> push($self -> cooked_tree);

} # End of BUILD.

# ------------------------------------------------

sub _add_daughter
{
	my($self, $name, $attributes) = @_;
	$attributes       ||= {};
	$$attributes{uid} = $self -> uid($self -> uid + 1);
	my($node)         =	Tree::DAG_Node -> new
						({
							attributes => $attributes,
							name       => $name,
						});
	my($tos) = $self -> node_stack -> last;

	#print '_add_daughter. stack size: ', $self -> node_stack -> length, "\n";

	$tos -> add_daughter($node);

	return $node;

} # End of _add_daughter.

# ------------------------------------------------

sub clean_name
{
	my($self, $name) = @_;
	my($attributes)  = {bracketed_name => 0, quantifier => '', real_name => $name};

	# Expected cases:
	# o {bare_name => $name}.
	# o {bracketed_name => $name}.
	# o $name.

	if (ref $name eq 'HASH')
	{
		if (defined $$name{bare_name})
		{
			$$attributes{real_name} = $name = $$name{bare_name};
		}
		else
		{
			$$attributes{real_name}      = $name = $$name{bracketed_name};
			$$attributes{bracketed_name} = 1;
			$name                        =~ s/^<//;
			$name                        =~ s/>$//;
		}
	}

	return ($name, $attributes);

} # End of clean_name.

# ------------------------------------------------

sub compress_tree
{
	my($self) = @_;

	my($alternative_count);
	my($daughter, @daughters);
	my($name, @name);
	my($statement);

	$self -> node_stack -> push(Tree::DAG_Node -> new({name => 'Dummy'}) );

	$self -> raw_tree -> walk_down
	({
		callback => sub
		{
			my($node, $option) = @_;
			$name      = $node -> name;
			$statement = ($name =~ /Class = .+::(.+?)\s/) ? $1 : '';

			if ($statement)
			{
				if ($statement eq 'action_name')
				{
					$self -> _add_daughter('action');
					$self -> _add_daughter('=>');
				}
				elsif ($statement eq 'alternatives')
				{
					$alternative_count = 0;
				}
				elsif ($statement eq 'alternative')
				{
					$alternative_count++;
				}
				elsif ($statement eq 'blessing')
				{
					$self -> _add_daughter('bless');
					$self -> _add_daughter('=>');
				}
				elsif ($statement eq 'discard_rule')
				{
					$self -> _add_daughter(':discard');
					$self -> _add_daughter('~');
				}
				elsif ($statement eq 'event_specification')
				{
					$self -> _add_daughter('event');
					$self -> _add_daughter('=>');
				}
				elsif ($statement eq 'latm_specification')
				{
					$self -> _add_daughter('latm');
					$self -> _add_daughter('=>');
				}
				elsif ($statement eq 'lexeme_default_statement')
				{
					$self -> _add_daughter('lexeme default');
					$self -> _add_daughter('=');
				}
				elsif ($statement eq 'lexeme_rule')
				{
					$self -> _add_daughter(':lexeme');
					$self -> _add_daughter('~');
				}
				elsif ($statement eq 'pause_specification')
				{
					$self -> _add_daughter('pause');
					$self -> _add_daughter('=>');
				}
				elsif ($statement eq 'priority_specification')
				{
					$self -> _add_daughter('priority');
					$self -> _add_daughter('=>');
				}
				elsif ($statement eq 'rhs')
				{
					$self -> _add_daughter('|') if ($alternative_count > 1);
				}
				elsif ($statement eq 'separator_specification')
				{
					$self -> _add_daughter('separator');
					$self -> _add_daughter('=>');
				}
				elsif ($statement eq 'start_rule')
				{
					$self -> _add_daughter(':start');
					$self -> _add_daughter('::=');
				}
				elsif ($statement eq 'statement')
				{
					# Discard previous statement (or Dummy) from top of stack.

					$node = $self -> node_stack -> pop;
					$self -> node_stack -> push($self -> _add_daughter($statement) );

					if ($node -> name ne 'Dummy')
					{
						@daughters = $node -> daughters;
						$name      = join(' ', map{$_ -> name} @daughters);

						$node -> add_daughters_left(Tree::DAG_Node -> new({name => $name}) );
					}
				}
			}
			elsif ($node -> my_daughter_index == 2)
			{
				# Split things like:
				# o '2 = graph_definition [SCALAR 186]'.
				# o '2 = ::= [SCALAR 195]'.
				# o '2 = <string lexeme> [SCALAR 2047]'.

				@name = split(/\s+/, $name);

				# Discard the '[$x' and '$n]'.

				pop @name for 1 .. 2;

				if ($name[2] ne 'undef')
				{
					$self -> _add_daughter(join(' ', @name[2 .. $#name]) );
				}
			}

			return 1; # Keep walking.
		},
		_depth => 0,
	});

	my($node) = $self -> node_stack -> pop;

	if ($node -> name ne 'Dummy')
	{
		@daughters = $node -> daughters;
		$name      = join(' ', map{$_ -> name} @daughters);

		$node -> add_daughters_left(Tree::DAG_Node -> new({name => $name}) );
	}

} # End of compress_tree.

# ------------------------------------------------

sub _fabricate_start_rule
{
	my($self)       = @_;
	my($first_rule) = '';

	my(@daughters);
	my($name);

	$self -> cooked_tree -> walk_down
	({
		callback => sub
		{
			my($node, $option) = @_;
			@daughters = $node -> daughters;

			return if ($#daughters < 0);

			$name = $daughters[0] -> name;

			if (! $first_rule && (substr($name, 0, 1) ne ':') && ($name =~ /::=/) )
			{
				$first_rule = $node;

				return 0; # Stop walking.
			}

			return 1; # Keep walking.
		},
		_depth => 0,
	});

	die "Unable to determine which rule is the first\n" if (! $first_rule);

	@daughters = $first_rule -> daughters;
	$name      = $daughters[1] -> name;
	my($node)  = Tree::DAG_Node -> new({name => 'statement'});

	$self -> cooked_tree -> add_daughter_left($node);

	for my $new_name (":start ::= $name", ':start', '::=', $name)
	{
		$node -> add_daughter(Tree::DAG_Node -> new({name => $new_name}) );
	}

} # End of _fabricate_start_rule.

# ------------------------------------------------

sub _find_start_rule
{
	my($self)  = @_;
	my($found) = 'No';

	my($name);

	$self -> cooked_tree -> walk_down
	({
		callback => sub
		{
			my($node, $option) = @_;
			$name = $node -> name;

			if ($name eq ':start')
			{
				$found = 'Yes';

				return 0; # Stop walking.
			}

			return 1; # Keep walking.
		},
		_depth => 0,
	});

	return $found;

} # End of _find_start_rule.

# ------------------------------------------------

sub log
{
	my($self, $level, $s) = @_;

	$self -> logger -> log($level => $s) if ($self -> logger);

} # End of log.

# ------------------------------------------------

sub run
{
	my($self)          = @_;
	my $marpa_bnf      = read_file($self -> marpa_bnf_file, binmode => ':utf8');
	my($marpa_grammar) = Marpa::R2::Scanless::G -> new({bless_package => 'MarpaX::Grammar::Parser', source => \$marpa_bnf});
	my $user_bnf       = read_file($self -> user_bnf_file, binmode =>':utf8');
	my($recce)         = Marpa::R2::Scanless::R -> new({grammar => $marpa_grammar});

	$recce -> read(\$user_bnf);

	my($value) = $recce -> value;

	die "Parse failed\n" if (! defined $value);

	$value = $$value;

	die "Parse failed\n" if (! defined $value);

	my($renderer) = Data::RenderAsTree -> new
		(
			attributes       => 0,
			max_key_length   => 100,
			max_value_length => 100,
			title            => 'Marpa value()',
			verbose          => 0,
		);
	my($output) = $renderer -> render($value);

	$self -> raw_tree($renderer -> root);

	my($raw_tree_file) = $self -> raw_tree_file;

	if ($raw_tree_file)
	{
		open(my $fh, '>', $raw_tree_file) || die "Can't open(> $raw_tree_file): $!\n";
		print $fh map{"$_\n"} @{$self -> raw_tree -> tree2string({no_attributes => 1 - $self -> bind_attributes})};
		close $fh;
	}

	$self -> compress_tree;

	if ($self -> _find_start_rule eq 'No')
	{
		$self -> _fabricate_start_rule;
	}

	my($cooked_tree_file) = $self -> cooked_tree_file;

	if ($cooked_tree_file)
	{
		open(my $fh, '>', $cooked_tree_file) || die "Can't open(> $cooked_tree_file): $!\n";
		print $fh map{"$_\n"} @{$self -> cooked_tree -> tree2string({no_attributes => 1 - $self -> bind_attributes})};
		close $fh;
	}

	# Return 0 for success and 1 for failure.

	return 0;

} # End of run.

#-------------------------------------------------

1;

=pod

=head1 NAME

C<MarpaX::Grammar::Parser> - Converts a Marpa grammar into a tree using Tree::DAG_Node

=head1 Synopsis

	use MarpaX::Grammar::Parser;

	my(%option) =
	(		# Inputs:
		marpa_bnf_file   => 'share/metag.bnf',
		user_bnf_file    => 'share/stringparser.bnf',
			# Outputs:
		cooked_tree_file => 'share/stringparser.cooked.tree',
		raw_tree_file    => 'share/stringparser.raw.tree',
	);

	MarpaX::Grammar::Parser -> new(%option) -> run;

For more help, run:

	 scripts/bnf2tree.pl -h

See share/*.bnf for input files and share/*.tree for output files.

Installation includes copying all files from the share/ directory, into a dir chosen by
L<File::ShareDir>. Run scripts/find.grammars.pl to display the name of that dir.

The cooked tree can be graphed with L<MarpaX::Grammar::GraphViz2>. That module has its own
L<demo page|http://savage.net.au/Perl-modules/html/marpax.grammar.graphviz2/index.html>.

=head1 Description

C<MarpaX::Grammar::Parser> uses L<Marpa::R2> to convert a user's BNF into a tree of
Marpa-style attributes, (see L</raw_tree()>), and then post-processes that (see L</compress_tree()>)
to create another tree, this time containing just the original grammar (see L</cooked_tree()>).

The nature of these trees is discussed in the L</FAQ>. The trees are managed by L<Tree::DAG_Node>.

Lastly, the major purpose of the cooked tree is to serve as input to L<MarpaX::Grammar::GraphViz2>.

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

Key-value pairs accepted in the parameter list (see also the corresponding methods
[e.g. L</marpa_bnf_file([$bnf_file_name])>]):

=over 4

=item o bind_attributes => Boolean

Include (1) or exclude (0) attributes in the tree file(s) output.

Default: 0.

=item o cooked_tree_file => aTextFileName

The name of the text file to write containing the grammar as a cooked tree.

If '', the file is not written.

Default: ''.

Note: The bind_attributes option/method affects the output.

=item o logger => aLog::HandlerObject

By default, an object of type L<Log::Handler> is created which prints to STDOUT.

See C<maxlevel> and C<minlevel> below.

Set C<logger> to '' (the empty string) to stop a logger being created.

Default: undef.

=item o marpa_bnf_file => aMarpaBNFFileName

Specify the name of Marpa's own BNF file. This distro ships it as share/metag.bnf.

This option is mandatory.

Default: ''.

=item o maxlevel => $level

This option is only used if this module creates an object of type L<Log::Handler>.

See L<Log::Handler::Levels>.

Nothing is printed by default.

Default: 'notice'.

=item o minlevel => $level

This option affects L<Log::Handler> objects.

See the L<Log::Handler::Levels> docs.

Default: 'error'.

No lower levels are used.

=item o raw_tree_file => aTextFileName

The name of the text file to write containing the grammar as a raw tree.

If '', the file is not written.

Default: ''.

Note: The bind_attributes option/method affects the output.

=item o user_bnf_file => aUserBNFFileName

Specify the name of the file containing your Marpa::R2-style grammar.

See share/stringparser.bnf for a sample.

This option is mandatory.

Default: ''.

=back

=head1 Methods

=head2 bind_attributes([$Boolean])

Here, the [] indicate an optional parameter.

Get or set the option which includes (1) or excludes (0) node attributes from the output
C<cooked_tree_file> and C<raw_tree_file>.

Note: C<bind_attributes> is a parameter to new().

=head2 clean_name($name)

Returns a list of 2 elements: ($name, $attributes).

$name is just the name of the token.

$attributes is a hashref with these keys:

=over 4

=item o bracketed_name => $Boolean

Indicates the token's name is (1) or is not (0) of the form '<...>'.

=item o quantifier => $char

Indicates the token is quantified. $char is one of '', '*' or '+'.

If $char is '' (the empty string), the token is not quantified.

=item o real_name => $string

The user-specified version of the name of the token, including leading '<' and trailing '>' if any.

=back

=head2 compress_tree()

Called automatically by L</run()>.

Converts the raw tree into the cooked tree.

Output is the tree returned by L</cooked_tree()>.

=head2 cooked_tree()

Returns the root node, of type L<Tree::DAG_Node>, of the cooked tree of items in the user's grammar.

By cooked tree, I mean as post-processed from the raw tree so as to include just the original user's
BNF tokens.

The cooked tree is optionally written to the file name given by
L</cooked_tree_file([$output_file_name])>.

The nature of this tree is discussed in the L</FAQ>.

See also L</raw_tree()>.

=head2 cooked_tree_file([$output_file_name])

Here, the [] indicate an optional parameter.

Get or set the name of the file to which the cooked tree form of the user's grammar will be written.

If no output file is supplied, nothing is written.

See share/stringparser.cooked.tree for the output of post-processing Marpa's analysis of
share/stringparser.bnf.

This latter file is the grammar used in L<MarpaX::Demo::StringParser>.

Note: C<cooked_tree_file> is a parameter to new().

Note: The bind_attributes option/method affects the output.

=head2 first_rule()

Returns the first G1-level rule in the user's gramamr. This is used to fabricate a start rule if
'start_rule' is not found in the cooked tree. This new node is not in the raw tree, but only in
the cooked tree, and hence in the hashref version of the cooked tree.

The presence of a start rule helps L<MarpaX::Grammar::GraphViz2> generate the grammar's image.

=head2 log($level, $s)

Calls $self -> logger -> log($level => $s) if ($self -> logger).

=head2 logger([$logger_object])

Here, the [] indicate an optional parameter.

Get or set the logger object.

To disable logging, just set logger to the empty string.

Note: C<logger> is a parameter to new().

=head2 marpa_bnf_file([$bnf_file_name])

Here, the [] indicate an optional parameter.

Get or set the name of the file to read Marpa's grammar from.

Note: C<marpa_bnf_file> is a parameter to new().

=head2 maxlevel([$$level])

Here, the [] indicate an optional parameter.

Get or set the value used by the logger object.

This option is only used if an object of type L<Log::Handler> is created.
See L<Log::Handler::Levels>.

Note: C<maxlevel> is a parameter to new().

=head2 minlevel([$$level])

Here, the [] indicate an optional parameter.

Get or set the value used by the logger object.

This option is only used if an object of type L<Log::Handler> is created.
See L<Log::Handler::Levels>.

Note: C<minlevel> is a parameter to new().

=head2 new()

The constructor. See L</Constructor and Initialization>.

=head2 raw_tree()

Returns the root node, of type L<Tree::DAG_Node>, of the raw tree of items in the user's grammar.

By raw tree, I mean as derived directly from Marpa.

The raw tree is optionally written to the file name given by L</raw_tree_file([$output_file_name])>.

The nature of this tree is discussed in the L</FAQ>.

See also L</cooked_tree()>.

=head2 raw_tree_file([$output_file_name])

Here, the [] indicate an optional parameter.

Get or set the name of the file to which the raw tree form of the user's grammar will be written.

If no output file is supplied, nothing is written.

See share/stringparser.raw.tree for the output of Marpa's analysis of share/stringparser.bnf.

This latter file is the grammar used in L<MarpaX::Demo::StringParser>.

Note: C<raw_tree_file> is a parameter to new().

Note: The bind_attributes option/method affects the output.

=head2 run()

The method which does all the work.

See L</Synopsis> and scripts/bnf2tree.pl for sample code.

run() returns 0 for success and 1 for failure.

=head2 statements()

Returns a hashref describing the grammar provided in the user_bnf_file parameter to L</new()>.

The L</FAQ> discusses the format of this hashref.

=head2 user_bnf_file([$bnf_file_name])

Here, the [] indicate an optional parameter.

Get or set the name of the file to read the user's grammar's BNF from. The whole file is
slurped in as a single string.

See share/stringparser.bnf for a sample. It is the grammar used in L<MarpaX::Demo::StringParser>.

Note: C<user_bnf_file> is a parameter to new().

=head1 Files Shipped with this Module

=head2 Data Files

=over 4

=item o share/c.ast.bnf

This is part of L<MarpaX::Languages::C::AST>, by Jean-Damien Durand. It's 1,565 lines long.

The outputs are share/c.ast.cooked.tree and share/c.ast.raw.tree.

=item o share/c.ast.cooked.tree

This is the output from post-processing Marpa's analysis of share/c.ast.bnf.

The command to generate this file is:

	scripts/bnf2tree.sh c.ast

=item o share/c.ast.raw.tree

This is the output from processing Marpa's analysis of share/c.ast.bnf. It's 56,723 lines long,
which indicates the complexity of Jean-Damien's grammar for C.

The command to generate this file is:

	scripts/bnf2tree.sh c.ast

=item o share/json.1.bnf

It is part of L<MarpaX::Demo::JSONParser>, written as a gist by Peter Stuifzand.

See L<https://gist.github.com/pstuifzand/4447349>.

The command to process this file is:

	scripts/bnf2tree.sh json.1

The outputs are share/json.1.cooked.tree and share/json.1.raw.tree.

=item o share/json.2.bnf

It also is part of L<MarpaX::Demo::JSONParser>, written by Jeffrey Kegler as a reply to the gist
above from Peter.

The command to process this file is:

	scripts/bnf2tree.sh json.2

The outputs are share/json.2.cooked.tree and share/json.2.raw.tree.

=item o share/json.3.bnf

The is yet another JSON grammar written by Jeffrey Kegler.

The command to process this file is:

	scripts/bnf2tree.sh json.3

The outputs are share/json.3.cooked.tree and share/json.3.raw.tree.

=item o share/metag.bnf.

This is a copy of L<Marpa::R2>'s BNF. That is, it's the file which Marpa uses to validate both
its own metag.bnf (self-reflexively), and any user's BNF file.

See L</marpa_bnf_file([$bnf_file_name])> above.

The command to process this file is:

	scripts/bnf2tree.sh metag

The outputs are share/metag.cooked.tree and share/metag.raw.tree.

=item o share/metag.hashref

Created by:

	scripts/bnf2tree.pl -mar share/metag.bnf -u share/metag.bnf -r share/metag.raw.tree \
		-max info > share/metag.hashref

=item o share/stringparser.bnf.

This is a copy of L<MarpaX::Demo::StringParser>'s BNF.

See L</user_bnf_file([$bnf_file_name])> above.

The command to process this file is:

	scripts/bnf2tree.sh stringparser

The outputs are share/stringparser.cooked.tree and share/stringparser.raw.tree.

=item o share/stringparser.hashref

Created by:

	scripts/bnf2tree.pl -mar share/stringparser.bnf -u share/stringparser.bnf \
		-r share/stringparser.raw.tree -max info > share/stringparser.hashref

=item o share/stringparser.treedumper

This is the output of running:

	scripts/metag.pl share/metag.bnf share/stringparser.bnf > \
		share/stringparser.treedumper

That script, metag.pl, is discussed just below, and in the L</FAQ>.

=item o share/termcap.info.bnf

It is part of L<MarpaX::Database::Terminfo>, written by Jean-Damien Durand.

The command to process this file is:

	scripts/bnf2tree.sh termcap.info

The outputs are share/termcap.info.cooked.tree and share/termcap.info.raw.tree.

=back

=head2 Scripts

These scripts are all in the scripts/ directory.

=over 4

=item o bnf2tree.pl

This is a neat way of using this module. For help, run:

	scripts/bnf2tree.pl -h

Of course you are also encouraged to include the module directly in your own code.

=item o bnf2tree.sh

This is a quick way for me to run bnf2tree.pl.

=item o find.grammars.pl

This prints the path to a grammar file. After installation of the module, run it with any of these
	parameters:

	scripts/find.grammars.pl (Defaults to json.1.bnf)
	scripts/find.grammars.pl c.ast.bnf
	scripts/find.grammars.pl json.1.bnf
	scripts/find.grammars.pl json.2.bnf
	scripts/find.grammars.pl json.3.bnf
	scripts/find.grammars.pl stringparser.bnf
	scripts/find.grammars.pl termcap.inf.bnf

It will print the name of the path to given grammar file.

=item o metag.pl

This is Jeffrey Kegler's code. See the L</FAQ> for more.

=item o pod2html.sh

This lets me quickly proof-read edits to the docs.

=back

=head1 FAQ

=head2 What is this BNF (SLIF-DSL) thingy?

Marpa's grammars are written in what we call a SLIF-DSL. Here, SLIF stands for Marpa's Scanless
Interface, and DSL is
L<Domain-specific Language|https://en.wikipedia.org/wiki/Domain-specific_language>.

Many programmers will have heard of L<BNF|https://en.wikipedia.org/wiki/Backus%E2%80%93Naur_Form>.
Well, Marpa's SLIF-DSL is an extended BNF. That is, it includes special tokens which only make sense
within the context of a Marpa grammar. Hence the 'Domain Specific' part of the name.

In practice, this means you express your grammar in a string, and Marpa treats that as a set of
rules as to how you want Marpa to process your input stream.

Marpa's docs for its SLIF-DSL L<are here|https://metacpan.org/module/Marpa::R2::Scanless::DSL>.

=head2 What is the difference between the cooked tree and the raw tree?

The raw tree is generated by processing the output of Marpa's parse of the user's grammar file.
It contains Marpa's view of that grammar.

The cooked tree is generated by post-processing the raw tree, to extract just the user's grammar's
tokens. It contains the user's view of their grammar.

The cooked tree can be graphed with L<MarpaX::Grammar::GraphViz2>. That module has its own
L<demo page|http://savage.net.au/Perl-modules/html/marpax.grammar.graphviz2/index.html>.

The following items explain this in more detail.

=head2 What are the details of the nodes in the cooked tree?

Under the root, there are a set of nodes:

=over 4

=item o N nodes, 1 per statement in the grammar

The node's names are the left-hand side of each statement in the grammar.

Each node is the root of a subtree describing the statement.

Under those nodes are a set of nodes:

=over 4

=item o 1 node for the separator between the left and right sides of the statement

So, the node's name is one of: '=' '::=' or '~'.

=item o 1 node per token from the right-hand side of each statement

The node's name is the token itself.

=back

=back

The attributes of each node are a hashref, with these keys:

=over 4

=item o bracketed_name => $Boolean

Indicates the token's name is or is not of the form '<...>'.

=item o quantifier => $char

Indicates the token is quantified. $char is one of '', '*' or '+'.

If $char is '' (the empty string), the token is not quantified.

=item o real_name => $string

The user-specified version of the name of the token, including leading '<' and trailing '>' if any.

=back

See share/stringparser.cooked.tree.

=head2 What are the details of the nodes in the raw tree?

Under the root, there are a set of nodes:

=over 4

=item o One node for the offset of the start of each grammar statement within the input stream.

The node's name is the integer start offset.

=item o One node for the offset of the end of each grammar statement within the input stream.

The node's name is the integer end offset.

=item o N nodes, 1 per statement in the grammar

The node's names are either an item from the user's grammar (when the attribute 'type' is 'Grammar')
or a Marpa-assigned token (when the attribute 'type' is 'Marpa').

Each node is the root of a subtree describing the statement.

See share/stringparser.raw.attributes.tree. The tree has attributes displayed using
(bind_attributes => 1), and share/stringparser.raw.tree for the same tree without attributes
(bind_attributes => 0).

=back

The attributes of each node are a hashref, with these keys:

=over 4

=item o type

This indicates what type of node it is.  Values:

=over 4

=item o 'Grammar' => The node's name is an item from the user-specified grammar.

=item o 'Marpa' => Marpa has assigned a class to the node (or to one of its parents)

The class name is for the form: $class_name::$node_name.

C<$class_name> is a constant provided by this module, and is 'MarpaX::Grammar::Parser::Dummy'.

The technique used to generate this file is discussed above, under L</Data Files>.

Note: The file share/stringparser.treedumper shows some class names, but they are currently I<not>
stored in the tree returned by the method L</raw_tree()>.

=back

=back

See share/stringparser.raw.tree.

=head2 Why are attributes used to identify bracketed names?

Because L<dot|http://graphviz.org> assigns a special meaning to labels which begin with '<' and
'<<'.

=head2 What is the format of the hashref of the cooked tree?

The keys in the hashref are the types of statements found in the grammar, and the values for those
keys are either '1' to indicate the key exists, or a hashref.

The latter hashref's keys are all the sub-types of statements found in the grammar, for the given
statement.

The pattern of keys pointing to either '1' or a hashref, is repeated to whatever depth is required
to represent the tree.

See share/*.hashref for sample output. Instructions for producing this output are detailed under
L</Data Files>.

=head2 Why did you write your own formatter for the output hashref?

I tried some fine modules (L<Data::Dumper>, L<Data::Dumper::Concise> and L<Data::Dump::Streamer>),
but even though they may have every option you want, they don't have the options I<I> want.

=head2 How do I sort the daughters of a node?

Here's one way, using the node names as sort keys.

As an example, choose $root as either $self -> cooked_tree or $self -> raw_tree, and then:

	@daughters = sort{$a -> name cmp $b -> name} $root -> daughters;

	$root -> set_daughters(@daughters);

Note: Since the original order of the daughters, in both the cooked and raw trees, is significant,
sorting is contra-indicated.

=head2 Where did the basic code come from?

Jeffrey Kegler wrote it, and posted it on the Google Group dedicated to Marpa, on 2013-07-22,
in the thread 'Low-hanging fruit'. I modified it slightly for a module context.

The original code is shipped as scripts/metag.pl.

=head2 Why did you use Data::TreeDump?

It offered the output which was most easily parsed of the modules I tested.
The others were L<Data::Dumper>, L<Data::TreeDraw>, L<Data::TreeDumper> and L<Data::Printer>.

=head2 Where is Marpa's Homepage?

L<http://jeffreykegler.github.io/Ocean-of-Awareness-blog/>.

=head2 Are there any articles discussing Marpa?

Yes, many by its author, and several others. See Marpa's homepage, just above, and:

L<The Marpa Guide|http://marpa-guide.github.io/>, (in progress, by Peter Stuifzand and Ron Savage).

L<Parsing a here doc|http://peterstuifzand.nl/2013/04/19/parse-a-heredoc-with-marpa.html>, by Peter
Stuifzand.

L<An update of parsing here docs|http://peterstuifzand.nl/2013/04/22/changes-to-the-heredoc-parser-example.html>,
by Peter Stuifzand.

L<Conditional preservation of whitespace|http://savage.net.au/Ron/html/Conditional.preservation.of.whitespace.html>,
by Ron Savage.

=head1 See Also

L<MarpaX::Demo::JSONParser>.

L<MarpaX::Demo::StringParser>.

L<MarpaX::Grammar::GraphViz2>.

L<MarpaX::Languages::C::AST>.

L<Data::TreeDumper>.

L<Log::Handler>.

=head1 Machine-Readable Change Log

The file Changes was converted into Changelog.ini by L<Module::Metadata::Changes>.

=head1 Version Numbers

Version numbers < 1.00 represent development versions. From 1.00 up, they are production versions.

=head1 Repository

L<https://github.com/ronsavage/MarpaX-Grammar-Parser>

=head1 Support

Email the author, or log a bug on RT:

L<https://rt.cpan.org/Public/Dist/Display.html?Name=MarpaX::Grammar::Parser>.

=head1 Author

L<MarpaX::Grammar::Parser> was written by Ron Savage I<E<lt>ron@savage.net.auE<gt>> in 2013.

Marpa's homepage: L<http://savage.net.au/Marpa.html>.

Homepage: L<http://savage.net.au/>.

=head1 Copyright

Australian copyright (c) 2013, Ron Savage.

	All Programs of mine are 'OSI Certified Open Source Software';
	you can redistribute them and/or modify them under the terms of
	The Artistic License 2.0, a copy of which is available at:
	http://www.opensource.org/licenses/index.html

=cut
