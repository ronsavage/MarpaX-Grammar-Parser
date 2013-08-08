use strict;
use warnings;

use Module::Build;

my $class = Module::Build->subclass(code => <<'EOF');

sub ACTION_authortest
{
	my($self) = @_;

	$self->depends_on('build');
	$self->depends_on('manifest');
	$self->depends_on('distmeta');

	$self->test_files( qw< t xt/author > );
	$self->recursive_test_files(1);

	$self->depends_on('test');

	return;
}
EOF

$class -> new
(
	module_name    => 'MarpaX::Grammar::Parser',
	license        => 'artistic_2',
	dist_abstract  => 'Convert a Marpa grammar into a tree using Tree::DAG_Node',
	dist_author    => 'Ron Savage <ron@savage.net.au>',
	build_requires =>
	{
		'Test::More' => 0.94,
#		'Test::Pod'  => 1.45, # Make it optional. See t/pod.t
	},
	configure_requires =>
	{
		'Module::Build' => 0.3800,
	},
	requires =>
	{
		'Algorithm::Diff'       => 1.1902,
		'autodie'               => 2.16,
		'charnames'             => 0,
		'English'               => 1.04,
		'Data::Dumper::Concise' => 2.020,
		'Getopt::Long'          => 2.41,
		'File::Basename'        => 2.82,
		'File::Spec'            => 3.40,
		'File::Temp'            => 0.2301,
		'List::AllUtils'        => 0.03,
		'Log::Handler'          => 0.78,
		'Marpa::R2'             => 2.066000,
		'Moo'                   => 1.002000,
		'open'                  => 0,
		'Path::Tiny'            => 0.025,
		'perl'                  => '5.14.2', # For the utf8 stuff.
		'Perl6::Slurp'          => 0.03,
		'Pod::Usage'            => 1.36,
		'Tree::DAG_Node'        => 1.12,
		'strict'                => 0,
		'utf8'                  => 0,
		'warnings'              => 0,
	},
	resources =>
	{
		bugtracker => 'https://rt.cpan.org/Public/Dist/Display.html?Name=MarpaX-Grammar-Parser',
		license    => 'http://www.perlfoundation.org/artistic_license_2_0',
	},
) -> create_build_script();
