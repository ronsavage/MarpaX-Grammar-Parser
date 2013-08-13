package Data::TreeDumper::Renderer::Marpa;

use 5.006;
use strict;
use warnings;

use Tree::DAG_Node;

my($previous_level) = - 1;
my($previous_type)  = '';

my($attributes);
my($current_node);
my(%node_per_level);
my(%sister_count);

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

	my($new_node);
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

	$sister_count{$level} = 0 if (! defined $sister_count{$level});

#	print "Sisters: $sister_count. Level: $previous_level => $level. Value: $element_value. Element: $token. \n";

	if ($level == 0)
	{
		$sister_count{$level}++;

		if ($sister_count{$level} == 1)
		{
			$attributes = {start => $token};
		}
		elsif ($sister_count{$level} = 2)
		{
			$$attributes{end} = $token;
		}
		else
		{
			$$attributes{level} = $level;
			$$attributes{type}  = $type;
			$new_node           = Tree::DAG_Node -> new
			({
				attributes => {%$attributes},
				name       => $token,
			});

			$current_node = $$setup{RENDERER}{root};

			$current_node -> add_daughter($new_node);

			$node_per_level{$level} = $new_node;

#			print "1 Level $level. Set '$token' => '$type' @ $current_node => $new_node. \n";
		}

	}
	elsif ($level > $previous_level)
	{
		$sister_count{$level} = 1;
	}
	elsif ($level == $previous_level)
	{
		$sister_count{$level}++;

		$current_node -> add_daughter($new_node);

		$node_per_level{$level} = $new_node;

#		print "3 Level $level. Set '$token' => '$type' @ $current_node => $new_node. \n";
	}
	else # $level < $previous_level.
	{
		$sister_count{$level} = 1;
		$current_node = $node_per_level{$level - 1};

		$current_node -> add_daughter($new_node);

		$node_per_level{$level} = $new_node;

#		print "4 Level $level. Set '$token' => '$type' @ $current_node => $new_node. \n";
	}

	$previous_level = $level;
	$previous_type  = $type;

#	print map{"$_\n"} @{$$setup{RENDERER}{root} -> tree2string({no_attributes => 0})};
#	print "\n";

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

=cut

