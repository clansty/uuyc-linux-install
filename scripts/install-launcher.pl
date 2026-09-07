#!/usr/bin/env perl
use strict;
use warnings;
use Cwd qw(abs_path);
use File::Basename qw(dirname);
use File::Path qw(make_path);
use Fcntl qw(O_WRONLY O_CREAT O_EXCL);

if (@ARGV == 1 && $ARGV[0] eq '--help') {
    print "usage: perl scripts/install-launcher.pl PREFIX BIN_DIRECTORY APPLICATIONS_DIRECTORY\n";
    exit 0;
}
@ARGV == 3 or die "usage: perl scripts/install-launcher.pl PREFIX BIN_DIRECTORY APPLICATIONS_DIRECTORY\n";
my ($prefix, $bin, $applications) = @ARGV;
for ($prefix, $bin, $applications) {
    m{^/} && !/[\r\n\0]/ or die "Use absolute paths without line breaks\n";
}
$prefix = abs_path($prefix) // die "Prefix does not exist\n";
-f "$prefix/system.reg" or die "Not an initialized Wine prefix\n";
my $repo = dirname(dirname(abs_path($0)));
my $launcher = "$bin/uu-controller";
my $desktop = "$applications/uu-controller.desktop";
for ($launcher, $desktop) {
    !-e $_ && !-l $_ or die "Refusing to overwrite $_\n";
}
sub read_file {
    my ($path) = @_;
    open my $handle, '<', $path or die "$path: $!\n";
    local $/;
    return <$handle>;
}
sub exec_quote {
    my ($value) = @_;
    $value =~ s/([\\"`\$])/\\$1/g;
    $value =~ s/%/%%/g;
    $value = '"' . $value . '"';
    $value =~ s/\\/\\\\/g;
    return $value;
}
my $script = read_file("$repo/scripts/uu-controller");
my $entry = read_file("$repo/templates/uu-controller.desktop.in");
my $exec = '/usr/bin/env ' . exec_quote("WINEPREFIX=$prefix") . ' ' . exec_quote($launcher) . ' start';
$entry =~ s/\@EXEC\@/$exec/;
make_path($bin, $applications);
for my $item ([$launcher, $script, 0755], [$desktop, $entry, 0644]) {
    my ($path, $content, $mode) = @$item;
    sysopen my $handle, $path, O_WRONLY | O_CREAT | O_EXCL, $mode or die "$path: $!\n";
    print {$handle} $content or die "$path: $!\n";
    close $handle or die "$path: $!\n";
}
print "Launcher: $launcher\nDesktop: $desktop\n";
