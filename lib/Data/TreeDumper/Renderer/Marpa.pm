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

#-------------------------------------------------------------------------------------------
1 ;

__END__

=head1 NAME

Data::TreeDumper::Renderer::Marpa - Marpa renderer for Data::TreeDumper

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 AUTHORS

=head1 SEE ALSO

L<Data::TreeDumper>.

L<MarpaX::Grammar::Parser>.

=cut

