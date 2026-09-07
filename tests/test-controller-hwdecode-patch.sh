#!/usr/bin/env bash
set -euo pipefail
repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
perl - "$repo_dir/scripts/patch-controller-hwdecode.pl" <<'PERL'
use strict;
use warnings;
use Digest::SHA qw(sha256_hex);
use File::Temp qw(tempdir);
use JSON::PP;
use Test::More;

my $tool = shift @ARGV;
my $tmp = tempdir(CLEANUP => 1);
mkdir "$tmp/input" or die $!;
sub write_file {
    my ($path, $data) = @_;
    open my $fh, '>:raw', $path or die $!;
    print {$fh} $data or die $!;
    close $fh or die $!;
}
sub read_file {
    open my $fh, '<:raw', shift or die $!;
    local $/;
    return <$fh>;
}
write_file("$tmp/input/test.dll", 'abcdefgh');
my $manifest = {
    schema_version => 1, kind => 'uu-controller-hwdecode',
    experimental => JSON::PP::true, gpu_decode_verified => JSON::PP::false,
    files => [{name => 'test.dll', sha256 => sha256_hex('abcdefgh'),
        patches => [{file_offset => '0x2', original => '6364', replacement => '7879'}]}]
};
sub run_tool {
    my ($output) = @_;
    write_file("$tmp/manifest.json", encode_json($manifest));
    return system($^X, $tool, "$tmp/manifest.json", "$tmp/input", $output) >> 8;
}
is(run_tool("$tmp/patched"), 0, 'valid input succeeds');
is(read_file("$tmp/patched/test.dll"), 'abxyefgh', 'exact patched bytes');
is(read_file("$tmp/input/test.dll"), 'abcdefgh', 'input unchanged');
isnt(run_tool("$tmp/patched"), 0, 'existing output rejected');
isnt(run_tool("$tmp/input"), 0, 'input as output rejected');
isnt(run_tool("$tmp/input/subdir"), 0, 'output inside input rejected');
$manifest->{files}[0]{sha256} = '0' x 64;
isnt(run_tool("$tmp/wrong-hash"), 0, 'wrong hash rejected');
ok(!-e "$tmp/wrong-hash", 'wrong hash creates no output');
$manifest->{files}[0]{sha256} = sha256_hex('abcdefgh');
my $patch = $manifest->{files}[0]{patches}[0];
$patch->{original} = '0000';
isnt(run_tool("$tmp/wrong-bytes"), 0, 'wrong signature rejected');
$patch->{original} = '6364';
$patch->{replacement} = '78';
isnt(run_tool("$tmp/wrong-length"), 0, 'unequal lengths rejected');
$patch->{replacement} = '7879';
$patch->{file_offset} = '0x8';
isnt(run_tool("$tmp/outside"), 0, 'out-of-bounds patch rejected');
$patch->{file_offset} = '0x2';
push @{$manifest->{files}[0]{patches}}, {%$patch};
isnt(run_tool("$tmp/overlap"), 0, 'overlapping patches rejected');
pop @{$manifest->{files}[0]{patches}};
push @{$manifest->{files}}, {name => 'missing.dll', sha256 => '0' x 64, patches => [%$patch]};
isnt(run_tool("$tmp/missing"), 0, 'missing second file rejected');
ok(!-e "$tmp/missing", 'all files validated before output');
is(read_file("$tmp/input/test.dll"), 'abcdefgh', 'input unchanged after all failures');
done_testing();
PERL
