#!/usr/bin/env perl
use strict;
use warnings;
use Cwd qw(abs_path);
use File::Basename qw(dirname);
use File::Temp qw(tempdir);
use File::Path qw(make_path);
use Test::More;

my $repo = dirname(dirname(abs_path($0)));
my $temp = tempdir(CLEANUP => 1);
my $prefix = "$temp/prefix space % dollar\$ quote\" slash\\ tick`";
my $bin = "$temp/bin space %";
my $apps = "$temp/applications";
make_path($prefix);
open my $reg, '>', "$prefix/system.reg" or die $!;
close $reg;
my @install = ($^X, "$repo/scripts/install-launcher.pl", $prefix, $bin, $apps);
is(system(@install), 0, 'install into isolated directories');
ok(-x "$bin/uu-controller", 'launcher is executable');
is(system('desktop-file-validate', "$apps/uu-controller.desktop"), 0, 'desktop entry validates');
ok(system(@install) != 0, 'existing files rejected');
is(system('bash', "$bin/uu-controller", '--help'), 0, 'launcher help');
ok(system('bash', "$bin/uu-controller", 'invalid') != 0, 'launcher bad input rejected');
open my $stub, '>', "$bin/uu-controller" or die $!;
print {$stub} <<'STUB';
#!/usr/bin/env perl
use strict;
use warnings;
open my $out, '>', $ENV{UU_TEST_OUTPUT} or die $!;
print {$out} "$ENV{WINEPREFIX}\n@ARGV\n";
close $out;
STUB
close $stub;
local $ENV{UU_TEST_OUTPUT} = "$temp/result";
is(system('gio', 'launch', "$apps/uu-controller.desktop"), 0, 'launch through desktop interface');
for (1..100) {
    last if -s "$temp/result";
    select undef, undef, undef, 0.02;
}
open my $result, '<', "$temp/result" or die "Desktop did not launch: $!";
my $actual = do { local $/; <$result> };
is($actual, "$prefix\nstart\n", 'desktop preserves special path characters and start argument');
done_testing();
