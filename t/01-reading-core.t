use strict;
use warnings;
use Test::More;
use FindBin;
use File::Spec::Functions;
use File::Basename qw(dirname);

our $module = 'Text::FromAny';
do(pathToContent('content/reading'));

sub pathToContent
{
	my $file = shift;
    my $sub = shift;
    $sub //= 'data';
	my @paths = (dirname(__FILE__), $FindBin::RealBin);
	my @subPaths = (curdir(), $sub, catfile('t/'.$sub));
	foreach my $p (@paths)
	{
		foreach my $e (@subPaths)
		{
			my $try = catfile($p,$e,$file);
			if (-e $try)
			{
				return $try;
			}
		}
	}
	return undef;
}
