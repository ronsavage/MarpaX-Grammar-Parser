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

has cooked_tree =>
(
	default  => sub{return ''},
	is       => 'rw',
	#isa     => 'Tree::DAG_Node',
	required => 0,
);

has cooked_tree_file =>
(
	default  => sub{return ''},
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

	die "No Marpa SLIF-DSL file provided\n" if (! $self -> marpa_bnf_file);
	die "No user SLIF-DSL file provided\n"  if (! $self -> user_bnf_file);

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

	$self -> cooked_tree
	(
		Tree::DAG_Node -> new
		({
			name => 'statements',
		})
	);

	$self -> raw_tree
	(
		Tree::DAG_Node -> new
		({
			attributes => {type => 'Marpa'},
			name       => 'statements',
		})
	);

} # End of BUILD.

# --------------------------------------------------

sub clean_name
{
	my($self, $name) = @_;
	my($attributes)  = {bracketed_name => 0, quantifier => ''};

	# Expected cases:
	# o {bare_name => $name}.
	# o {bracketed_name => $name}.
	# o $name.
	#
	# Quantified names are handled in sub compress_branch.

	if (ref $name eq 'HASH')
	{
		if (defined $$name{bare_name})
		{
			$name = $$name{bare_name};
		}
		else
		{
			$name       = $$name{bracketed_name};
			$name       =~ s/^<//;
			$name       =~ s/>$//;
			$attributes = {bracketed_name => 1};
		}
	}

	return ($name, $attributes);

} # End of clean_name.

# --------------------------------------------------

sub compress_branch
{
	my($self, $index, $a_node) = @_;

	my($name);
	my($token);

	$a_node -> walk_down
	({
		callback => sub
		{
			my($node, $option) = @_;
			$name = $node -> name;

			if ($name eq 'default_rule')
			{
				$token = $self -> process_default_rule($index, $node);
			}
			elsif ($name eq 'discard_rule')
			{
				$token = $self -> process_discard_rule($index, $node);
			}
			elsif ($name eq 'empty_rule')
			{
				$token = $self -> process_empty_rule($index, $node);
			}
			elsif ($name =~ /(.+)_event_declaration$/)
			{
				$token = $self -> process_event_declaration($index, $node, $1);
			}
			elsif ($name eq 'lexeme_default_statement')
			{
				$token = $self -> process_lexeme_default($index, $node);
			}
			elsif ($name eq 'lexeme_rule')
			{
				$token = $self -> process_lexeme_rule($index, $node);
			}
			elsif ($name eq 'priority_rule')
			{
				$token = $self -> process_priority_rule($index, $node);
			}
			elsif ($name eq 'quantified_rule')
			{
				$token = $self -> process_quantified_rule($index, $node);
			}
			elsif ($name eq 'start_rule')
			{
				$token = $self -> process_start_rule($index, $node);
			}

			return 1; # Keep walking.
		},
		_depth => 0,
	});

	my($attributes);

	($name, $attributes) = $self -> clean_name(shift @$token);
	my($node)            = Tree::DAG_Node -> new
	({
		attributes => $attributes,
		name       => $name,
	});

	$self -> cooked_tree -> add_daughter($node);

	for (my $i = 0; $i <= $#$token; $i++)
	{
		$name                = $$token[$i];
		($name, $attributes) = $self -> clean_name($name);

		# Special case handling: Quantitied rules.

		if ( ($i < $#$token) && (ref $$token[$i + 1] eq 'HASH') && ($$token[$i + 1]{quantifier}) )
		{
			$i++;

			$$attributes{quantifier} = $$token[$i]{quantifier};
		}

		$node -> add_daughter
		(
			Tree::DAG_Node -> new
			({
				attributes => $attributes,
				name       => $name,
			})
		);
	}

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

			# Skip the first 2 daughters, which hold offsets for the
			# start and end of the token within the input stream.

			return 1 if ($node -> my_daughter_index < 2);

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

	return [@token];

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

			# Skip the first 2 daughters, which hold offsets for the
			# start and end of the token within the input stream.

			return 1 if ($node -> my_daughter_index < 2);

			if ($node -> mother -> mother -> name eq 'symbol_name')
			{
				push @token, ':discard', '=>', {$node -> mother -> name => $name};
			}

			return 1; # Keep walking.
		},
		_depth => 0,
	});

	return [@token];

} # End of process_discard_rule.

# --------------------------------------------------

sub process_empty_rule
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

			# Skip the first 2 daughters, which hold offsets for the
			# start and end of the token within the input stream.

			return 1 if ($node -> my_daughter_index < 2);

			if ($node -> mother -> name =~ /op_declare_+/)
			{
				push @token, $name;
			}
			elsif ($node -> mother -> mother -> name eq 'symbol_name')
			{
				push @token, {$node -> mother -> name => $name};
			}

			return 1; # Keep walking.
		},
		_depth => 0,
	});

	return [@token];

} # End of process_empty_rule.

# --------------------------------------------------

sub process_event_declaration
{
	my($self, $index, $a_node, $type) = @_;
	my(%type) =
	(
		completion => 'completed',
		nulled     => 'nulled',
		prediction => 'predicted',
	);

	my($name);
	my(@token);

	$a_node -> walk_down
	({
		callback => sub
		{
			my($node, $option) = @_;
			$name = $node -> name;

			# Skip the first 2 daughters, which hold offsets for the
			# start and end of the token within the input stream.

			return 1 if ($node -> my_daughter_index < 2);

			if ($node -> mother -> mother -> name eq 'event_name')
			{
				push @token, 'event', $name, '=', $type{$type};
			}
			elsif ($node -> mother -> mother -> name eq 'symbol_name')
			{
				push @token, {$node -> mother -> name => $name};
			}

			return 1; # Keep walking.
		},
		_depth => 0,
	});

	return [@token];

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

			# Skip the first 2 daughters, which hold offsets for the
			# start and end of the token within the input stream.

			return 1 if ($node -> my_daughter_index < 2);

			if ($node -> mother -> mother -> name =~ /(action|blessing)_name/)
			{
				push @token, $map{$1}, '=>', $name;
			}

			return 1; # Keep walking.
		},
		_depth => 0,
	});

	return [@token];

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

			# Skip the first 2 daughters, which hold offsets for the
			# start and end of the token within the input stream.

			return 1 if ($node -> my_daughter_index < 2);

			if ($node -> mother -> mother -> name eq 'event_name')
			{
				push @token, 'event', '=>', $name;
			}
			elsif ($node -> mother -> mother -> name eq 'pause_specification')
			{
				push @token, 'pause', '=>', $name;
			}
			elsif ($node -> mother -> mother -> name eq 'priority_specification')
			{
				push @token, 'priority', '=>', $name;
			}
			elsif ($node -> mother -> mother -> name eq 'symbol_name')
			{
				push @token, {$node -> mother -> name => $name};
			}

			return 1; # Keep walking.
		},
		_depth => 0,
	});

	return [@token];

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

			# Skip the first 2 daughters, which hold offsets for the
			# start and end of the token within the input stream.

			return 1 if ($node -> my_daughter_index < 2);

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

			# Skip the first 2 daughters, which hold offsets for the
			# start and end of the token within the input stream.

			return 1 if ($node -> my_daughter_index < 2);

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
			elsif ($node -> mother -> mother -> name eq 'rank_specification')
			{
				push @token, 'rank', '=>', $name;
			}
			elsif ($node -> mother -> name eq 'single_quoted_string')
			{
				push @token, $name;
			}
			elsif ($node -> mother -> mother -> name eq 'symbol_name')
			{
				push @token, {$node -> mother -> name => $name};
			}

			return $continue;
		},
		_depth => 0,
	});

	return [@token];

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

			# Skip the first 2 daughters, which hold offsets for the
			# start and end of the token within the input stream.

			return 1 if ($node -> my_daughter_index < 2);

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
				push @token, {quantifier => $name};
			}
			elsif ($node -> mother -> mother -> name eq 'separator_specification')
			{
				push @token, 'separator', '=>';
			}
			elsif ($node -> mother -> mother -> name eq 'symbol_name')
			{
				push @token, {$node -> mother -> name => $name};
			}

			return 1; # Keep walking.
		},
		_depth => 0,
	});

	return [@token];

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

			# Skip the first 2 daughters, which hold offsets for the
			# start and end of the token within the input stream.

			return 1 if ($node -> my_daughter_index < 2);

			if ($node -> mother -> mother -> name eq 'symbol_name')
			{
				push @token, ':start', '::=', {$node -> mother -> name => $name};
			}

			return 1; # Keep walking.
		},
		_depth => 0,
	});

	return [@token];

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

	$self -> compress_tree;

	my($cooked_tree_file) = $self -> cooked_tree_file;

	if ($cooked_tree_file)
	{
		open(OUT, '>', $cooked_tree_file) || die "Can't open(> $cooked_tree_file): $!\n";
		print OUT map{"$_\n"} @{$self -> cooked_tree -> tree2string({no_attributes => $self -> no_attributes})};
		close OUT;
	}

	# Return 0 for success and 1 for failure.

	return 0;

} # End of run.

# ------------------------------------------------

package MarpaX::Grammar::Parser::Dummy;

our $VERSION = '1.01';

sub new{return {};}

#-------------------------------------------------

1;

=pod

=head1 NAME

C<MarpaX::Grammar::Parser> - Converts a Marpa grammar into a forest using Tree::DAG_Node

=head1 Synopsis

	use MarpaX::Grammar::Parser;

	my(%option) =
	(
		cooked_tree_file => 'share/stringparser.cooked.tree', # Output.
		marpa_bnf_file   => 'share/metag.bnf',                # Input.
		raw_tree_file    => 'share/stringparser.raw.tree',    # Output.
		user_bnf_file    => 'share/stringparser.bnf',         # Input.
	);

	my($parser) = MarpaX::Grammar::Parser -> new(%option);

	$parser -> run;

	# Output is in share/stringparser.cooked.tree and share/stringparser.raw.tree.

See share/metag.bnf for the SLIF-DSL file which ships with L<Marpa::R2> V 2.066000.

See share/*.bnf for input files and share/*.tree for output files.

For help, run

	shell> perl -Ilib scripts/bnf2tree.pl -h

=head1 Description

C<MarpaX::Grammar::Parser> uses L<Marpa::R2> to convert a user's SLIF-DSL into a tree of Marpa-style attributes,
(see L</raw_tree()>), and then post-processes that (see L</compress_tree()>) to create another tree, this time
containing just the original grammar (see L</cooked_tree()>).

So, currently, the forest contains 2 trees.

The nature of these trees is discussed in the L</FAQ>.

Lastly, one purpose of the cooked tree is to serve as input to L<MarpaX::Grammar::GraphViz2>.

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

=item o cooked_tree_file aTextFileName

The name of the text file to write containing the grammar as a cooked tree.

If '', the file is not written.

Default: ''.

=item o logger aLog::HandlerObject

By default, an object of type L<Log::Handler> is created which prints to STDOUT, but in this version nothing
is actually printed.

See C<maxlevel> and C<minlevel> below.

Set C<logger> to '' (the empty string) to stop a logger being created.

Default: undef.

=item o marpa_bnf_file aMarpaSLIF-DSLFileName

Specify the name of Marpa's own SLIF-DSL file. This file ships with L<Marpa::R2>, in the meta/ directory.
It's name is metag.bnf.

A copy, as of Marpa::R2 V 2.066000, ships with C<MarpaX::Grammar::Parser>. See share/metag.bnf.

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

Include (0) or exclude (1) attributes in the cooked_tree_file and the raw_tree_file.

Default: 0.

=item o raw_tree_file aTextFileName

The name of the text file to write containing the grammar as a raw tree.

If '', the file is not written.

Default: ''.

=item o user_bnf_file aUserSLIF-DSLFileName

Specify the name of the file containing your Marpa::R2-style grammar.

See share/stringparser.bnf for a sample.

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

=head2 clean_name($name)

Returns a list of 2 elements: ($name, $attributes).

$name is just the name of the token.

$attributes is a hashref with these keys:

=over 4

=item o bracketed_name => $Boolean

Indicates the token's name is or is not of the form '<...>'.

=item o quantifier => $char

Indicates the token is quantified. $char is one of '', '*' or '+'.

If $char is '' (the empty string), the token is not quantified.

=back

=head2 compress_branch($index, $node)

Called by L</compress_tree()>.

Converts 1 sub-tree of the raw tree into one sub-tree of the cooked tree.

=head2 compress_tree()

Called automatically by L</new()>.

Converts the raw tree into the cooked tree, calling L</compress_branch($index, $node)> once for each
daughter of the raw tree.

Output is the tree returned by L</cooked_tree()>.

=head2 cooked_tree()

Returns the root node, of type L<Tree::DAG_Node>, of the cooked tree of items in the user's grammar.

By cooked tree, I mean as post-processed from the raw tree so as to include just the original user's SLIF-DSL tokens.

The cooked tree is optionally written to the file name given by L</cooked_tree_file([$output_file_name])>.

The nature of this tree is discussed in the L</FAQ>.

See also L</raw_tree()>.

=head2 cooked_tree_file([$output_file_name])

Here, the [] indicate an optional parameter.

Get or set the name of the file to which the cooked tree form of the user's grammar will be written.

If no output file is supplied, nothing is written.

See share/stringparser.cooked.tree for the output of post-processing Marpa's analysis of share/stringparser.bnf.

This latter file is the grammar used in L<MarpaX::Demo::StringParser>.

Note: C<cooked_tree_file> is a parameter to new().

=head2 log($level, $s)

Calls $self -> logger -> log($level => $s) if ($self -> logger).

=head2 logger([$logger_object])

Here, the [] indicate an optional parameter.

Get or set the logger object.

To disable logging, just set logger to the empty string.

Note: C<logger> is a parameter to new().

=head2 marpa_bnf_file([$bnf_file_name])

Here, the [] indicate an optional parameter.

Get or set the name of the file to read Marpa's grammar from. The whole file is slurped in as a single string.

This file ships with L<Marpa::R2>, in the meta/ directory. It's name is metag.bnf.

A copy, as of Marpa::R2 V 2.066000, ships with L<MarpaX::Grammar::Parser>.

See share/metag.bnf for a sample.

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

=head2 new()

The constructor. See L</Constructor and Initialization>.

=head2 no_attributes([$Boolean])

Here, the [] indicate an optional parameter.

Get or set the option which includes (0) or excludes (1) node attributes from being included in the output
C<cooked_tree_file> and C<raw_tree_file>.

Note: C<no_attributes> is a parameter to new().

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

=head2 user_bnf_file([$bnf_file_name])

Here, the [] indicate an optional parameter.

Get or set the name of the file to read the user's grammar's SLIF-DSL from. The whole file is slurped in as
a single string.

See share/stringparser.bnf for a sample. It is the grammar used in L<MarpaX::Demo::StringParser>.

Note: C<user_bnf_file> is a parameter to new().

=head1 Files Shipped with this Module

=head2 Data Files

=over 4

=item o share/c.ast.bnf

This is part of L<MarpaX::Languages::C::AST>, by Jean-Damien Durand. It's 1,565 lines long.

The output is share/c.ast.raw.tree.

=item o share/c.ast.raw.tree

This is the output from processing Marpa's analysis of share/c.ast.bnf. It's 56,723 lines long, which indicates
the complexity of Jean-Damien's grammar for C.

The command to generate this file is:

	shell> scripts/bnf2tree.sh c.ast

=item o share/json.1.bnf

It is part of L<MarpaX::Demo::JSONParser>, written as a gist by Peter Stuifzand.

See L<https://gist.github.com/pstuifzand/4447349>.

The output is share/json.1.raw.tree.

=item o share/json.1.raw.tree

This is the output from processing Marpa's analysis of share/json.1.bnf.

The command to generate this file is:

	shell> scripts/bnf2tree.sh json.1

=item o share/json.2.bnf

It also is part of L<MarpaX::Demo::JSONParser>, written by Jeffrey Kegler as a reply to the gist above from Peter.

The output is share/json.2.raw.tree.

=item o share/json.2.raw.tree

This is the output from processing Marpa's analysis of share/json.2.bnf.

The command to generate this file is:

	shell> scripts/bnf2tree.sh json.2

=item o share/metag.bnf.

This is a copy of L<Marpa::R2>'s SLIF-DSL.

See L</marpa_bnf_file([$bnf_file_name])> above.

=item o share/stringparser.bnf.

This is a copy of L<MarpaX::Demo::StringParser>'s SLIF-DSL.

The output is share/stringparser.cooked.tree and share/stringparser.raw.tree.

See L</user_bnf_file([$bnf_file_name])> above.

=item o share/stringparser.cooked.tree

This is the output from post-processing Marpa's analysis of share/stringparser.bnf.

The command to generate this file is:

	shell> scripts/bnf2tree.sh stringparser

=item o share/stringparser.raw.tree

This is the output from processing Marpa's analysis of share/stringparser.bnf.

The command to generate this file is:

	shell> scripts/bnf2tree.sh stringparser

See also the next item.

=item o share/stringparser.treedumper

This is the output of running:

	shell> perl scripts/metag.pl share/metag.bnf share/stringparser.bnf > share/stringparser.treedumper

That script, metag.pl, is discussed just below, and in the L</FAQ>.

=item o share/termcap.info.bnf

It also is part of L<MarpaX::Database::Terminfo>, written by Jean-Damien Durand.

The output is share/termcap.info.raw.tree.

=item o share/termcap.info.raw.tree

This is the output from processing Marpa's analysis of share/termcap.info.bnf.

The command to generate this file is:

	shell> scripts/bnf2tree.sh termcap.info

=back

=head2 Scripts

=over 4

=item o scripts/find.grammars.pl

After installation of the module, run it with:

	shell> perl scripts/find.grammars.pl (Defaults to stringparser.bnf)
	shell> perl scripts/find.grammars.pl c.ast.bnf
	shell> perl scripts/find.grammars.pl json.1.bnf
	shell> perl scripts/find.grammars.pl json.2.bnf
	shell> perl scripts/find.grammars.pl stringparser.bnf
	shell> perl scripts/find.grammars.pl termcap.info.bnf

It will print the name of the path to given grammar file.

=item o scripts/bnf2tree.pl

This is a neat way of using the module. For help, run:

	shell> perl -Ilib scripts/bnf2tree.pl -h

Of course you are also encouraged to include this module directly in your own code.

=item o scripts/bnf2tree.sh

This is a quick way for me to run bnf2tree.pl.

=item o scripts/find.grammars.pl

This prints the path to a grammar file. After installation of the module, run it with:

	shell> perl scripts/find.grammars.pl (Defaults to json.1.bnf)
	shell> perl scripts/find.grammars.pl c.ast.bnf
	shell> perl scripts/find.grammars.pl json.1.bnf
	shell> perl scripts/find.grammars.pl json.2.bnf
	shell> perl scripts/find.grammars.pl stringparser.bnf
	shell> perl scripts/find.grammars.pl termcap.inf.bnf

It will print the name of the path to given grammar file.

=item o scripts/metag.pl

This is Jeffrey Kegler's code. See the first FAQ question.

=item o scripts/pod2html.sh

This lets me quickly proof-read edits to the docs.

=back

=head1 FAQ

=head2 What is this SLIF-DSL thingy?

Marpa's grammars are written in what we call a SLIF-DSL. Here, SLIF stands for Scanless Interface, and DSL is
L<Domain-specific Language|https://en.wikipedia.org/wiki/Domain-specific_language>.

Many programmers will have heard of L<BNF|https://en.wikipedia.org/wiki/Backus%E2%80%93Naur_Form>. Well, Marpa's
SLIF-DSL is an extended BNF. That is, it includes special tokens which only make sense within the context of a Marpa
grammar. Hence the 'Domain Specific' part of the name.

In practice, this means you express your grammar in a string, and Marpa treats that as a set of rules as to how
you want Marpa to process your input stream.

Marpa's docs for its SLIF-DSL L<are here|https://metacpan.org/module/Marpa::R2::Scanless::DSL>.

=head2 What is the difference between the cooked tree and the raw tree?

The raw tree is generated by processing the output of Marpa's parse of the user's grammar file.
It contains Marpa's view of that grammar.

The cooked tree is generated by post-processing the raw tree, to extract just the user's grammar's tokens.
It contains the user's view of their grammar.

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

If $char is ' ' (the empty string), the token is not quantified.

=back

See share/stringparser.cooked.tree.

=head2 What are the details of the nodes in the raw tree?

Under the root, there are a set of nodes:

=over 4

=item o One node for the offset of the start of the grammar within the input stream.

The node's name is the integer start offset.

=item o One node for the offset of the end of the grammar within the input stream.

The node's name is the integer end offset.

=item o N nodes, 1 per statement in the grammar

The node's names are either an item from the user's grammar (when the attribute 'type' is 'Grammar')
or a Marpa-assigned token (when the attribute 'type' is 'Marpa').

Each node is the root of a subtree describing the statement.

See share/stringparser.raw.attributes.tree for a tree with attributes displayed, and
share/stringparser.raw.tree for the same tree without attributes.

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

See share/stringparser.treedumper, which will make this much clearer.

The technique used to generate this file is discussed above, under L</Data Files>.

Note: The file share/stringparser.treedumper shows some class names, but they are currently I<not> stored
in the tree returned by the method L</raw_tree()>.

=back

=back

See share/stringparser.raw.tree.

=head2 Why are attributes used to identify bracketed names?

Because L<Graphviz|http://graphviz.org> assigns a special meaning to labels which begin with '<' and '<<'.

=head2 How do I sort the daughters of the root?

Here's one way, using the node names as sort keys.

Choose $root as either $self -> cooked_tree or $self -> raw_tree, and then:

	@daughters = sort{$a -> name cmp $b -> name} $root -> daughters;

	$root -> set_daughters(@daughters);

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

=head2 Where is Marpa's Homepage?

L<http://jeffreykegler.github.io/Ocean-of-Awareness-blog/>.

=head2 Are there any articles discussing Marpa?

Yes, many by its author, and several others. See Marpa's homepage, just above, and:

L<The Marpa Guide|http://marpa-guide.github.io/>, (in progress, by Peter Stuifzand and Ron Savage).

L<Parsing a here doc|http://peterstuifzand.nl/2013/04/19/parse-a-heredoc-with-marpa.html>, by Peter Stuifzand.

L<An update of parsing here docs|http://peterstuifzand.nl/2013/04/22/changes-to-the-heredoc-parser-example.html>, by Peter Stuifzand.

L<Conditional preservation of whitespace|http://savage.net.au/Ron/html/Conditional.preservation.of.whitespace.html>, by Ron Savage.

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
