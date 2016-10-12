#!/usr/bin/env perl
#
# Google Drive direct download of big files
# ./gdown.pl 'gdrive file url' 'desired file name' [wget_option]...
#  The 'desired file name' can be a path: relative or absolute.
#
# Distributed under GPL 3 (http://www.gnu.org/licenses/gpl-3.0.html)
# v1.0 by circulosmeos 04-2014.
# http://circulosmeos.wordpress.com/2014/04/12/google-drive-direct-download-of-big-files
#
# v2.0 by Noureddin 06-2016 <noureddin95@gmail.com>
# Change Log:
#   - support resuming downloading files (using .part-files for incomplete downloads)
#   - more portability; it can run on virtually any OS with Perl and Wget (no /tmp; Wget's path is easily changeable)
#   - improve output (to have the best experience, use Wget 1.16 or higher)
#   - support Wget options
#   - embedability (can be a part of another perl script)
# http://github.com/noureddin/gdrive-dl

use strict;
use warnings;
use File::Copy qw(move);

die "\n./gdown.pl 'gdrive file url' 'desired file name' [wget_option]...\n\n" if (@ARGV < 2);

my $wget = 'wget'; # change this to the Wget's path, if it is not in your $PATH or in the same directory as the script.
my $url;
my $filename;
my $downloadfile;
my $tempfile;
my $cookiefile;
my @wget_options;

confirm(shift, shift, @ARGV); # confirm($url, $filename, @wget_options);

sub confirm {
    ($url, $filename, @wget_options) = @_;
    $downloadfile = "$filename.part";
    
    $url = "https://drive.google.com/uc?id=$url&export=download" if ($url !~ /^http/); # if an ID not a url
    
    $tempfile = $filename.'.html';
    $cookiefile = $filename.'_cookie.txt';
    
    my $confirm;
    my $check;
    my $docs_flag;

    confirm_execute_command();

    while (-s $tempfile < 100000) { # only if the file isn't the download yet
        open fTEMPFILE, '<', $tempfile;
        $check=0;
        foreach (<fTEMPFILE>) {
            if (/href="(\/uc\?export=download[^"]+)/) {
                $url='https://docs.google.com'.$1;
                $url=~s/&amp;/&/g;
                $confirm='';
                $check=1;
                last;
            }
            if (/confirm=([^;&]+)/) {
                $confirm=$1;
                $check=1;
                last;
            }
            if (/"downloadUrl":"([^"]+)/) {
                $url=$1;
                $url=~s/\\u003d/=/g;
                $url=~s/\\u0026/&/g;
                $confirm='';
                $check=1;
                last;
            }
        }
        close fTEMPFILE;
        die "Couldn't confirm and download $filename :-(\n" if ($check==0);
        $url=~s/confirm=([^;&]+)/confirm=$confirm/ if $confirm ne '';
        
        # the first url redirects to docs.google.com/..., which in turn redirects to another docs.google.com/... which is the final url
        if ($url=~/docs\.google\.com/) {
            if (defined $docs_flag)
            { confirm_execute_command_final(); return 1; }
            else
            { $docs_flag = 1; confirm_execute_command(); }
        }
        else
        { confirm_execute_command(); }
    }
}

sub confirm_execute_command {
    system($wget, '-q', '--load-cookie', $cookiefile, '--save-cookie', $cookiefile, $url, '-O', $tempfile, @wget_options);
}

sub confirm_execute_command_final {
    my $wget_version = `$wget -V`; ($wget_version) = $wget_version=~/^GNU Wget ([0-9]+\.[0-9]+)[ .]/; # get Wget version
    if ( system($wget, '-c', '--load-cookie', $cookiefile, '--save-cookie', $cookiefile, $url, '-O', $downloadfile, @wget_options,
                  ($wget_version ge '1.16')? ('-q', '--show-progress') : () ) == 0 ) { # if downloading finished successfully
        unlink($tempfile, $cookiefile);
        move($downloadfile, $filename);
    }
}
