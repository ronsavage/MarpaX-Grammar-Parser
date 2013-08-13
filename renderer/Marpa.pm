package Data::TreeDumper::Renderer::Marpa;

use 5.006;
use strict;
use warnings;

use Tree::DAG_Node;

my($current_node)   = '';
my($previous_level) = 1;
my($previous_node)  = '';

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
	my(
	$element,
	$level,
	$is_terminal,
	$previous_level_separator,
	$separator,
	$element_name,
	$element_value,
	$td_address,
	$address_link,
	$perl_size,
	$perl_address,
	$setup,
	) = @_ ;

	return '' if ($element =~ /^\d+$/);

	my($package)  = $$setup{RENDERER}{package};
	$current_node = $$setup{RENDERER}{root} if ($level < $previous_level);
	my($new_node) = Tree::DAG_Node -> new
	({
		attributes => {},
		name       => $1,
	});

	if ($element =~ /$package\:\:(.+)=/)
	{
		if ($level > $previous_level)
		{
#			$current_node -> add_daughter($new_node);
		}
		else
		{
#			$current_node -> add_right_sister($new_node);
		}
	}

	$previous_level = $level;

	my($result);

	$result = "Element: $element. Level: $previous_level => $level. Name: $element_name. Value: $element_value. \n";

	return $result;

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

=cut

