use strict;
use warnings;

use ExtUtils::MakeMaker;

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

my(%params) =
(
	AUTHOR   => 'Ron Savage (ron@savage.net.au)',
	ABSTRACT => 'Convert a Marpa grammar into a tree using Tree::DAG_Node',
	clean =>
	{
		FILES => 'blib/* Makefile MANIFEST MarpaX-Grammar-Parser-*'
	},
	dist =>
	{
		COMPRESS => 'gzip',
		SUFFIX   => 'gz'
	},
	DISTNAME  => 'MarpaX-Grammar-Parser',
	NAME      => 'MarpaX::Grammar::Parser',
	PL_FILES  => {},
	PREREQ_PM =>
	{
		'charnames'      => 0,
		'File::Spec'     => 3.33,
		'List::AllUtils' => 0.03,
		'Log::Handler'   => 0.78,
		'Moo'            => 1.002000,
		'open'           => 0,
		'perl'           => '5.8.1', # For the utf8 stuff.
		'Perl6::Slurp'   => 0.03,
		'Pod::Usage'     => 1.36,
		'Tree::DAG_Node' => 1.12,
		'strict'         => 0,
		'Test::More'     => 0.94,
#		'Test::Pod'      => 1.45, # Make it optional. See xt/author/pod.t
		'Text::Xslate'   => 1.4001,
		'utf8'           => 0,
		'warnings'       => 0,
	},
	VERSION_FROM => 'lib/MarpaX/Grammar/Parser.pm',
);

if ( ($ExtUtils::MakeMaker::VERSION =~ /^\d\.\d\d$/) && ($ExtUtils::MakeMaker::VERSION > 6.30) )
{
	$params{LICENSE} = 'artistic_2';
}

if ($ExtUtils::MakeMaker::VERSION ge '6.46')
{
	$params{META_MERGE} =
	{
		resources =>
		{
			bugtracker => 'https://rt.cpan.org/Public/Dist/Display.html?Name=MarpaX-Grammar-Parser',
			license    => 'http://www.perlfoundation.org/artistic_license_2_0',
		},
	};
}

WriteMakefile(%params);
