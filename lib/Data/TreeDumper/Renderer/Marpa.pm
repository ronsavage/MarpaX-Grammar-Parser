package Data::TreeDumper::Renderer::Marpa;

use 5.006;
use strict;
use warnings;

use Tree::DAG_Node;

my($previous_level) = - 1;
my($previous_type)  = '';

my($current_node);
my(%node_per_level);

our $VERSION = '1.00';

#-------------------------------------------------

sub GetRenderer
{
	return
	({
		BEGIN => \&begin,
		NODE  => \&node,
		END   => \&end,
	});

} # End of Getrenderer.

#-------------------------------------------------

sub begin
{
	my($title, $td_address, $element, $perl_size, $perl_address, $setup) = @_ ;

	return '';

} # End of begin.

#-------------------------------------------------

sub node
{
	my($element, $level, $is_terminal, $previous_level_separator, $separator, $element_name,
		$element_value, $td_address, $address_link, $perl_size, $perl_address, $setup) = @_ ;

	my($token);
	my($type);

	if ($element =~ /$$setup{RENDERER}{package}\:\:(.+)=/)
	{
		$token = $1;
		$type  = 'class';
	}
	else
	{
		$token = $element;
		$type  = 'token';
	}

	my($new_node) = Tree::DAG_Node -> new
	({
		attributes => {level => $level, type => $type},
		name       => $token,
	});

	# This test works for the very first call because the initial value of $previous_level is < 0.
	# Also, $current_node is unchanged by this if when $level == $previous_level.

	if ($level > $previous_level)
	{
		$current_node = $level == 0 ? $$setup{RENDERER}{root} : $node_per_level{$previous_level};
	}
	elsif ($level < $previous_level)
	{
		$current_node = $level == 0 ? $$setup{RENDERER}{root} : $node_per_level{$level - 1};
	}

	$current_node -> add_daughter($new_node);

	$node_per_level{$level} = $new_node;
	$previous_level         = $level;
	$previous_type          = $type;

	return '';

} # End of node.

#-------------------------------------------------

sub end
{
	my($setup) = @_;

	return '';

} # End of end.

#-------------------------------------------------

1;

=pod

=head1 NAME

C<Data::TreeDumper::Renderer::Marpa> - A Marpa::R2 plugin for Data::TreeDumper

=head1 Synopsis

No synopsis needed since this module is used automatically by L<MarpaX::Grammar::Parser>.

=head1 Description

This module is a dummy plugin for L<Data::TreeDumper>. It is used by L<MarpaX::Grammar::Parser>
as a namespace during the parsing of a L<Marpa::R2>-style BNF.

=head1 Installation

This module is installed automatically when you install L<MarpaX::Grammar::Parser>.

=head1 Machine-Readable Change Log

The file Changes was converted into Changelog.ini by L<Module::Metadata::Changes>.

=head1 Version Numbers

Version numbers < 1.00 represent development versions. From 1.00 up, they are production versions.

=head1 Support

Email the author, or log a bug on RT:

L<https://rt.cpan.org/Public/Dist/Display.html?Name=MarpaX::Grammar::Parser>.

=head1 See Also

L<Marpa::Demo::JSONParser>.

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
