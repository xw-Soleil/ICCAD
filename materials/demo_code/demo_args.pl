#!/usr/bin/perl -w

use strict;

print "The input arguments are:\n";

foreach $a (@ARGV)
{
	print "$a \n";
} 

my $n = @ARGV;
print "There are totally $n of them.\n\n";

print "In this program, I can also see environment variables' values\n";
$n = $ENV{"PATH"};
print "For example - the \$PATH is $n \n";
$n = $ENV{"HOME"};
print "For example - the \$HOME is $n \n";

