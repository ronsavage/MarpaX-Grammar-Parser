use strict;
use warnings;

use Algorithm::Diff;

use File::Temp;

use MarpaX::Grammar::Parser;

use Path::Tiny;   # For path().
use Perl6::Slurp; # For slurp().

use Test::More;

# -------------

BEGIN {use_ok('MarpaX::Grammar::Parser'); }

# The EXLOCK option is for BSD-based systems.

my($temp_dir)       = File::Temp -> newdir('temp.XXXX', CLEANUP => 1, EXLOCK => 0, TMPDIR => 1);
my($temp_dir_name)  = $temp_dir -> dirname;
my($tree_file_name) = path($temp_dir_name, 'stringparser.tree');
my($in_file_name)   = path('data', 'stringparser.bnf');
my($orig_file_name) = path('data', 'stringparser.tree');

my($parser) = MarpaX::Grammar::Parser -> new
(
	input_file => "$in_file_name",
	logger     => '',
	tree_file  => "$tree_file_name",
);

isa_ok($parser, 'MarpaX::Grammar::Parser', 'new() returned correct object type');
is($parser -> input_file, $in_file_name, 'input_file() returns correct string');
is($parser -> logger, '', 'logger() returns correct string');
is($parser -> tree_file, $tree_file_name, 'tree_file() returns correct string');

$parser -> run;

is(slurp("$orig_file_name", {utf8 => 1}), slurp("$tree_file_name", {utf8 => 1}), 'Output tree matches shipped tree');

done_testing;
