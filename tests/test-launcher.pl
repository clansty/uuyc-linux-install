#!/usr/bin/env perl
use strict;
use warnings;
use Cwd qw(abs_path);
use File::Basename qw(dirname);
use File::Temp qw(tempdir);
use File::Path qw(make_path);
use File::Copy qw(copy);
use Test::More;

my $repo = dirname(dirname(abs_path($0)));
my $temp = tempdir(CLEANUP => 1);
my $prefix = "$temp/prefix space % dollar\$ quote\" slash\\ tick`";
my $bin = "$temp/bin space %";
my $apps = "$temp/applications";
make_path($prefix);
open my $reg, '>', "$prefix/system.reg" or die $!;
close $reg;
my $icon = '024B_GameViewer.0';
my @install = ($^X, "$repo/scripts/install-launcher.pl", $prefix, $bin, $apps, $icon);
is(system(@install), 0, 'install into isolated directories');
open my $entry, '<', "$apps/uu-controller.desktop" or die $!;
my $entry_text = do { local $/; <$entry> };
like($entry_text, qr/^Icon=\Q$icon\E$/m, 'uses the supplied UU icon');
ok(system($^X, "$repo/scripts/install-launcher.pl", $prefix, "$temp/no-icon-bin", "$temp/no-icon-apps") != 0,
    'missing icon rejected');
ok(!-e "$temp/no-icon-bin", 'missing icon creates no output');
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
my $wine_entry = "$temp/wine-original.desktop";
copy("$apps/uu-controller.desktop", $wine_entry) or die $!;
is(system('desktop-file-edit', '--set-key=NoDisplay', '--set-value=true', $wine_entry), 0,
    'hide original entry with the documented command');
is(system('desktop-file-validate', $wine_entry), 0, 'hidden entry validates');
open my $hidden, '<', $wine_entry or die $!;
my $hidden_text = do { local $/; <$hidden> };
like($hidden_text, qr/^NoDisplay=true$/m, 'original entry is hidden');
like($hidden_text, qr/^Icon=\Q$icon\E$/m, 'hiding original preserves its icon');
open my $visible, '<', "$apps/uu-controller.desktop" or die $!;
my $visible_text = do { local $/; <$visible> };
unlike($visible_text, qr/^NoDisplay=true$/m, 'custom entry remains visible');
done_testing();
