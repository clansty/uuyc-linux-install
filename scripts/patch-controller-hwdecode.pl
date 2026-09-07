#!/usr/bin/env perl
use strict;
use warnings;
use Cwd qw(abs_path);
use Digest::SHA qw(sha256_hex);
use File::Basename qw(dirname basename);
use File::Spec;
use JSON::PP;

sub usage {
    return "Usage: perl $0 MANIFEST INPUT_DIR NEW_OUTPUT_DIR\n"
        . "Experimental: emits patched copies only; GPU decoding is not yet verified.\n";
}

if (@ARGV == 1 && $ARGV[0] eq '--help') {
    print usage();
    exit 0;
}
die usage() unless @ARGV == 3;
my ($manifest_path, $input_arg, $output_arg) = @ARGV;
my $input = abs_path($input_arg);
die "Input directory does not exist\n" unless defined $input && -d $input;
die "Output already exists (must be a new directory)\n" if -e $output_arg || -l $output_arg;
my $parent = abs_path(dirname($output_arg));
die "Output parent directory does not exist\n" unless defined $parent && -d $parent;
my $output = File::Spec->catdir($parent, basename($output_arg));
die "Output must be outside the input directory\n"
    if $output eq $input || index($output, "$input/") == 0;

sub read_bytes {
    my ($path) = @_;
    open my $fh, '<:raw', $path or die "Cannot read $path: $!\n";
    local $/;
    my $data = <$fh>;
    close $fh or die "Cannot close $path: $!\n";
    return defined $data ? $data : '';
}

sub hex_bytes {
    my ($value, $label) = @_;
    die "Invalid $label hex bytes\n"
        unless defined $value && !ref($value) && $value =~ /\A(?:[0-9a-fA-F]{2})+\z/;
    return pack 'H*', $value;
}

my $manifest = decode_json(read_bytes($manifest_path));
die "Unsupported experimental controller manifest\n"
    unless ref($manifest) eq 'HASH'
    && ($manifest->{schema_version} // '') eq '1'
    && ($manifest->{kind} // '') eq 'uu-controller-hwdecode'
    && JSON::PP::is_bool($manifest->{experimental}) && $manifest->{experimental}
    && JSON::PP::is_bool($manifest->{gpu_decode_verified}) && !$manifest->{gpu_decode_verified};
die "Manifest files must be a nonempty array\n"
    unless ref($manifest->{files}) eq 'ARRAY' && @{$manifest->{files}};

my (@verified, %names);
for my $file (@{$manifest->{files}}) {
    die "Invalid file entry\n" unless ref($file) eq 'HASH';
    my $name = $file->{name};
    die "Invalid or duplicate filename\n"
        unless defined $name && !ref($name) && $name =~ /\A[A-Za-z0-9_-][A-Za-z0-9_.-]*\z/
        && !$names{$name}++;
    my $digest = $file->{sha256};
    die "Invalid SHA256 for $name\n"
        unless defined $digest && !ref($digest) && $digest =~ /\A[0-9a-f]{64}\z/;
    my $path = File::Spec->catfile($input, $name);
    die "Missing regular input file: $name\n" unless -f $path && !-l $path;
    my $data = read_bytes($path);
    die "SHA256 mismatch: $name\n" unless sha256_hex($data) eq $digest;
    die "Missing patches: $name\n"
        unless ref($file->{patches}) eq 'ARRAY' && @{$file->{patches}};
    my @patches;
    for my $patch (@{$file->{patches}}) {
        die "Invalid patch: $name\n" unless ref($patch) eq 'HASH';
        my $offset_hex = $patch->{file_offset};
        die "Invalid offset: $name\n"
            unless defined $offset_hex && !ref($offset_hex)
            && $offset_hex =~ /\A0x[0-9a-fA-F]{1,8}\z/;
        my $offset = hex $offset_hex;
        my $original = hex_bytes($patch->{original}, 'original');
        my $replacement = hex_bytes($patch->{replacement}, 'replacement');
        die "Patch length mismatch: $name\n" unless length($original) == length($replacement);
        die "Patch outside file: $name\n" if $offset + length($original) > length($data);
        die "Original bytes mismatch: $name at $offset_hex\n"
            unless substr($data, $offset, length($original)) eq $original;
        push @patches, [$offset, $original, $replacement];
    }
    my $end = 0;
    for my $patch (sort { $a->[0] <=> $b->[0] } @patches) {
        my ($offset, $original, $replacement) = @$patch;
        die "Overlapping patches: $name\n" if $offset < $end;
        $end = $offset + length($original);
        substr($data, $offset, length($original), $replacement);
    }
    push @verified, [$name, $data];
}

# 全部输入验证通过后才创建输出，避免错误版本留下可误用的半套补丁。
mkdir $output or die "Cannot create output directory $output: $!\n";
for my $file (@verified) {
    my ($name, $data) = @$file;
    my $path = File::Spec->catfile($output, $name);
    open my $fh, '>:raw', $path or die "Cannot create $path: $!\n";
    print {$fh} $data or die "Cannot write $path: $!\n";
    close $fh or die "Cannot close $path: $!\n";
    print sha256_hex($data), "  $path\n";
}
print "Experimental copies created; actual GPU decoding remains unverified.\n";
