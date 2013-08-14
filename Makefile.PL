use strict;
use warnings;

use ExtUtils::MakeMaker;

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

my(%params) =
(
	AUTHOR   => 'Ron Savage (ron@savage.net.au)',
	ABSTRACT => 'Converts a Marpa grammar into a tree using Tree::DAG_Node',
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
		'Algorithm::Diff'  => 1.1902,
		'charnames'        => 0,
		'Data::TreeDumper' => 0.40,
		'English'          => 1.04,
		'Getopt::Long'     => 2.41,
		'File::Temp'       => 0.2301,
		'Log::Handler'     => 0.78,
		'Marpa::R2'        => 2.066000,
		'Moo'              => 1.002000,
		'open'             => 0,
		'Path::Tiny'       => 0.025,
		'perl'             => '5.14.2', # For the utf8 stuff.
		'Perl6::Slurp'     => 0.03,
		'Pod::Usage'       => 1.36,
		'Tree::DAG_Node'   => 1.12,
		'strict'           => 0,
		'Test::More'       => 0.94,
#		'Test::Pod'        => 1.45, # Make it optional. See xt/author/pod.t
		'utf8'             => 0,
		'warnings'         => 0,
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
