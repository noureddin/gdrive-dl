#!/usr/bin/env perl
# Google Drive Public Folder Mass Downloader (gdrive-dl), in perl
# by NoUrEdDiN : noureddin@protonmail.com or noureddin95@gmail.com
# License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>.

# updated 19th, Mar, 2017; 2017.03.19

# TODO (in the next few releases, hopefully):
# - support updating gdrive-dl from itself (run `gdrive-dl update` to update the script itself).
# - support updating files on the local drive, if the online files have been modified. (it requires getting/decoding the dates from the Drive page.)
# - test gdrive-dl more.
# - improve documentations.

use constant IDFILENAME => 'IDs'; # http://alvinalexander.com/perl/perl-write-file-example-read-file-array

use strict; use warnings;

use File::Copy qw(move);
use File::Path qw(make_path remove_tree);
use List::MoreUtils qw(uniq);
my $chex;
if (grep /-ch|-ex/, @ARGV)
{
  eval "use Tie::RegexpHash"; # for chex; https://metacpan.org/pod/Tie::RegexpHash
  $chex = Tie::RegexpHash->new();
}

use IO::Handle; STDOUT->autoflush(1); # to print on the same line; http://www.perlmonks.org/?node_id=699555

my $wget = 'wget'; # change this to the Wget's path, if it is not in your $PATH.
my $wget_version_1_16; # a flag, because we use the options '-q' and '--show-progress' with Wget >= 1.16, to get compact but meaningful output.
my @givenids; # ids given as arguments
my @givenurls; # urls given as arguments
my @dlids; # ids of files to download
my @dltitles; # titles of files to download (in the same order as @dlids)
my @dldates; # dates of files to download (in the same order as @dlids)
my %olddates; # id-date pairs from the old IDs file
my $force = 1; # to allow updating files if modified
my $no_scan;
my $trash;
my %duplicates; # for title_duplicated()
my $choose; # 1 for choose, 0 for exclude, undef for none
my $chexwarnflag; # rised if both choose and exclude are used
my $mso; # if defined, download Google files as MSOffice not PDF
my $odf; # if defined, download Google files as OpenDocument not PDF
my $txt; # if defined, download Google files as Plain Text; this downloads spreadsheets as CSV unless $tsv is defined
my $tsv; # if defined AND $txt is defined, download Google spreadsheets as tab-separated values, not comma-separated values
# for Google drawings, PDF is the default format; $mso or $odf downloads them as PNG; and $txt downloads them as SVG
# the following flags, with the corresponding switches, fine-tune them away from other "office" formats
#my $png; my $svg; # to be implemented sometime soon
my $gfilewarnflag; # rised if both $mso and $odf are defined
my $autodetect_dirs;
my $confirm_all;
my $gdl_cookiefile = '/tmp/gdrive-dl-'.`date +%s`; $gdl_cookiefile=~s/\n//; # TODO: PURIFY; use only Perl functions
my @wget_options = ('--load-cookie', $gdl_cookiefile, '--save-cookie', $gdl_cookiefile);
my @confirm;
my $ID;

if (grep /-tor/, @ARGV)
{
  # a REALLY quick and dirty solution; FIXME
  # it prints the script, found here http://tor.stackexchange.com/a/12545/16708, to a /tmp file, and uses it as $wget
  my $path = '/tmp/gdrive-dl-wget-tor';
  `sh -c 'echo "#!/bin/sh" > $path; echo "unset http_proxy" >> $path; echo "unset HTTP_PROXY" >> $path; echo "unset https_proxy" >> $path; echo "unset HTTPS_PROXY" >> $path; echo "exec torsocks $wget --passive-ftp \\\"\\\$@\\\"" >> $path'`;
  chmod(0755, $path);
  $wget = $path;
}

# Reading Arguments
if (defined $ARGV[0]) # TODO: use Getopt::Long; ?
{
  if ($ARGV[0] =~ /^help|--help|-h|-\?$/)
  {
    print <<'HD';
  Gdrive-dl is a public Google Drive downloader without needing an account.
It downloads a public folder with all of its contents, and syncs your local
copy with the online one. It also supports many features related to downloading
from public Google Drive without an account.

Usage: gdrive-dl [ID]... [URL]... [OPTION]...    # the downloading/syncing form
       gdrive-dl COMMAND [ARGUMENT]...           # see the Commands section below

Note: Files bigger than 25 MB need a special treatment, because Google cannot scan
them for viruses, so they have different commands and options.
These files are called here "big files".

Commands:
  If you want to do something other than downloading, call gdrive-dl with one of
these commands as the first argument.
  help, --help, -h, -?        print this help and exit
  help-tor, --help-tor        print how to use gdrive-dl with tor, and exit
  confirm [FILES]             confirm and download either FILES if supplied, or all the big
                             files in the current folder recursively.
  confirm-check               print a list of the big files in the current folder recursively
                             that are not yet confirmed and downloaded
  confirm-ia                  interactive confirming; it prints all files that need confirm
                             in the current folder, recursively, with the total file size,
                             and you choose which files to confirm and download.
  list [ID]... [URL]...       print the contents of the folders given by theirs IDs or URLs
  list-nodups [ID]... [URL]...  like 'list' but without duplicate-checking

Options:
  -ch, --choose=NAME           specify a file or folder to download only it
  -ex, --exclude=NAME          specify a file or folder to skip downloading it
  -tor                         use gdrive-dl with tor, see help-tor above
  -ns, --no-scan               use the current IDs files and don't scan the online drive
                               use --no-scan with --force to complete downloading
  -c,  --confirm[=FILE]        like 'confirm' command, but after downloading the drive
  -cc, --confirm-check         like 'confirm-check' command, but after downloading the drive
  -ad, --autodetect-dirs       download into a folder named the same as the given drive
  -mso,--microsoft-office      download Google files as docx, pptx, xlsx, and png, not pdf
  -odf,--opendocument-format   download Google files as odt, odp, ods, and png, not pdf
  -txt                         download Google files as txt, txt, csv, and svg, not pdf
  -tsv                         with '-txt', download Google spreadsheets as tsv, not csv
  *                            anything else is passed to Wget as an option

Notes:
  - Short options cannot be bundled; using '-fc' instead of '-f -c' is NOT allowed.
  - Short options with a value also require an "="; use '-ch=big.pdf' NOT "-ch big.pdf".
  - The arguments order in the downloading/syncing form doesn't matter; all the options are
    parsed first, then all the IDs are downloaded, then all the URLs.
  - You can use many choose (or exclude) switches to choose (or exclude) many files/folders,
    but you cannot use both choose and exclude at the same time.

License GPLv3+: GNU GPL version 3 <http://gnu.org/licenses/gpl.html>.
To get updates or send feedback: https://github.com/noureddin/gdrive-dl
To contact the author: noureddin95@gmail.com
HD
    exit;
  }
  elsif ($ARGV[0] =~ /^help-tor|--help-tor$/)
  {
    print <<'HD';
:: Installing and Configuring:
------------------------------
  You can use gdrive-dl with tor, if you have
1. Tor Browser Bundle (downloadable from https://torproject.org/), and
2. `torsocks` (could be obtained from your distro's repos).
  To configure torsocks to work with you Tor Browser Bundle, run this
command in the terminal:
    sudo sed 's/^TorPort .*/TorPort 9150/' -i /etc/tor/torsocks.conf

:: Running:
-----------
1. run Tor Browser Bundle, and leave it running
2. run gdrive-dl with `-tor` switch
HD
    exit;
  }
  elsif ($ARGV[0] eq 'confirm')
  {
    @confirm = grep {not /^-/} @ARGV[1..@ARGV-1];
    push(@wget_options, grep {/^-/} @ARGV[1..@ARGV-1]);
    $confirm_all = 1 if (scalar @confirm == 0);
    my_confirm();
    exit;
  }
  elsif ($ARGV[0] eq 'confirm-check')
  {
    my @c = get_confirm_all(1);
    print "$_\n" for (@c);
    exit;
  }
  elsif ($ARGV[0] eq 'confirm-ia') # interactive
  {
    print "\e[1mInteractive Confirmation Mode\e[m (enter 'h' for help):\n";
    while (1)
    {
      my @c = get_confirm_all(1);
      if ($#c < 0) { print "No files need being confirmed.\n"; exit; }
      
      my @s = map { '('.get_size_confirm($_).')'} @c;
      my $max_size = 0; $max_size = map { length($_)>$max_size?length($_):$max_size } @s; $max_size+=2;
      
cials:for my $i (0..$#c) { printf "\e[1m[%0*d] %*s\e[m %s\n", length($#c), $i+1, $max_size, $s[$i], $c[$i]; }
      
ciain:print "Choose: ";
      my $in = <STDIN>; chomp $in;
      if ($in eq 'h')
      {
        print <<"HD";
  Interactive Confirmation Mode in gdrive-dl is used to interactively choose files to be confirmed
and downloaded. In it you can see every file that needs confirming, in the current folder
respectively, is listed and preceded by two bold numbers: its size (between parenthese '\e[1m()\e[m'),
and its number (between brackets '\e[1m[]\e[m').
To choose a file, enter its number followed by the '\e[1menter\e[m' key. You can enter several
numbers separated by a space to get their respective files in the order you entered them.
A small '\e[1mq\e[m' will quit the program. And a small '\e[1ml\e[m' will re-list the files again.
A small '\e[1mh\e[m' will show this help.
You can enter a '\e[1mq\e[m' with the numbers to quit after downloading the requested files.
Any other letter alone will cause rechecking and relisting the list of the files, which
happens anyway after confirming and downloading any file.

HD
        goto cials; # FIXME: goto?!
      }
      goto cials if ($in eq 'l');
      @confirm = ();
      while ($in=~/([0-9]+)/g)
      {
        if ($1-1 > $#s || $1 < 1) { print "$1: invalid choice!\n"; goto ciain; }
        push(@confirm, $c[$1-1]) 
      }
      my_confirm();
      exit if $in =~ 'q';
    }
    exit;
  }
  elsif (($ARGV[0] eq 'list') or ($ARGV[0] eq 'list-nodups')) # TODO: see if both of them are really needed, and not only one
  {
    check_internet_connection();
    my @ids = @ARGV[1..@ARGV-1];
    if (scalar @ids == 0) { @ids = get_ids_dir('.') or exit_with_error("You must provide a folder URL or ID to list its contents.\n"); }
    for (@ids)
    {
      my $url = (/^[0-9]/) ? "https://drive.google.com/drive/folders/$_" : $_;
      my $F=`$wget -q '$url' -O - @wget_options`;
      my $ftitle; html_title($F, $ftitle);
      print "The contents of \"$ftitle\"\n";
      my $gd = $F=~m|\[\\x22[^0]|; # set $gd to 1 if there are Google Files (whose IDs are longer than the folders and regular files); TODO: check this check!
      printf "%-*s\t%s\n", ($gd==1)?44:28, 'ID', 'NAME';
      #printf "%-*s\t%s\n", ($gd==1)?44:28, $1, ($ARGV[0] eq 'list-nodups')?title_escape_readonly($2):title_list($2, ($3 =~ /vnd\.google-apps\.(.)/)? "\U$1" : '')
      while ($F=~m#\[\\x22(?<id>[^\\]+)\\x22,\[\\x22[0-9a-zA-Z-_]+\\x22]\\n,\\x22(?<title>.*?)\\x22,\\x22[^\\]+\\/(?<type>[^\\]+)\\x#g)
      {
        my $id = $+{id}; my $title = $+{title}; my $type = $+{type};
        printf "%-*s\t%s\n", ($gd==1)?44:28, $id, title_list($title, ($type =~ /vnd\.google-apps\.(.)/)? "\U$1" : '')
      }
    }
    exit;
  }
  elsif ($ARGV[0] !~ /^[-0-9]|http/) # if not an option, an id, or a url
  { exit_with_error("$ARGV[0]: unknown command! see the help.\n"); }
}

check_internet_connection();
foreach (@ARGV)
{
  if (/^[0-9]/)
  {
    push(@givenids, $_);
  }
  elsif (/^http/)
  {
    push(@givenurls, $_);
  }
  elsif (/^--choose=|^-ch=/)
  {
    if (defined $choose and $choose == 0) { $chexwarnflag = 1; next; }
    my ($a) = $_=~/^.*?=(.*)$/;
    #$a=~s|^(.*?)/?$|^\Q$1\E(/.*)?\$|;
    $a=~s|^(.*?)/?$|\Q$1\E(/.*)?|; # change path/to/folder to '\Qpath/to/folder\E(/.*)?' to match the folder and any of its contents
    $chex->add($a, 'matches');
    $choose = 1;
  }
  elsif (/^--regex-choose=|^-rch=/) # (?)
  {
    if (defined $choose and $choose == 0) { $chexwarnflag = 1; next; }
    my ($a) = $_=~/^.*?=(.*)$/;
    $chex->add($a, 'matches');
    $choose = 1;
  }
  elsif (/^--exclude=|^-ex=/)
  {
    if (defined $choose and $choose == 1) { $chexwarnflag = 1; next; }
    my ($a) = $_=~/^.*?=(.*)$/;
    $a=~s|^(.*?)/?$|^\Q$1\E(/.*)?\$|; # change 'path/to/folder' to '\Qpath/to/folder\E(/.*)?' to match the folder and any of its contents
    $chex->add($a, 'matches');
    $choose = 0;
  }
  elsif (/^--force|-f$/)
  {
    $force = 1; # to force download all regardless of anything; usually used for testing, checking, or completing downloading
    # now it's on by default for updating files if modified
  }
  elsif (/^--no-force|-nf$/)
  {
    undef $force; # for fixing a bug; see the commit msg for 2017.03.19
  }
  elsif (/^--no-scan|-ns$/)
  {
    $no_scan = 1; # mostly for debugging, or completing downloading
  }
  elsif (/^--trash|-t$/)
  {
    $trash = 1;
  }
  elsif (/^--confirm|-c$/)
  {
    $confirm_all = 1;
  }
  elsif (/^--confirm=|-c=/)
  {
    $_=~/^.*?=(.*)$/;
    push(@confirm, $1);
  }
  elsif (/^--confirm-check|-cc$/)
  {
    my @c = get_confirm_all();
    print "Needs Confirmation: $_\n" for (@c);
  }
  elsif (/^--autodetect-dirs|-ad$/)
  {
    $autodetect_dirs = 1;
  }
  elsif (/^--microsoft-office|-mso$/)
  {
    if (defined $odf or defined $txt) { $gfilewarnflag = 1; next; }
    $mso = 1;
  }
  elsif (/^--opendocument-format|-odf$/)
  {
    if (defined $mso or defined $txt) { $gfilewarnflag = 1; next; }
    $odf = 1;
  }
  elsif (/^-txt$/)
  {
    if (defined $mso or defined $odf) { $gfilewarnflag = 1; next; }
    $txt = 1;
  }
  elsif (/^-tsv$/)
  {
    #if (not defined $txt) { $gfilewarnflag = 1; next; }
    $tsv = 1;
  }
  else # assume the rest are Wget options; TODO: check the options before passing!
  {
    push(@wget_options, $_);
  }
}

if (defined $chexwarnflag)
{ outwarn('WARNING:', 'Choose and Exclude are used at the same time. Using the first, '.(($choose==1)?'Choose.':'Exclude.')); }

if (defined $gfilewarnflag)
{
  my $use = (defined $mso)?'MSO.':(defined $odf)?'ODF.':'TXT.';
  outwarn('WARNING:', 'You have chosen two or more of MSO, ODF, and TXT; you can\'t. Using the first, '.$use);
}

if (defined $tsv and not defined $txt)
{ outwarn('WARNING:', "'-txt' is not used but '-tsv' is used. It's ignored."); }

# if no IDs are given, look for this folder ID
if (scalar @givenids == 0 and scalar @givenurls == 0) { @givenids = get_ids_dir('.') or exit_with_error("No IDs given or found!\n"); }
## Getting the IDs
getroot($_)  foreach (@givenids);
get_this($_) foreach (@givenurls);
clean_exit();

# Functions

sub getroot
{
  # make sure all root-dependent arrays or hashes are empty
  @dlids = ();
  @dltitles = ();
  %duplicates = ();
  %olddates = ();
  
  my $F; my $id = $_[0]; my $type = get_type($id);
  if ($type ne 'F') # if not a folder
  {
    # Get the file name (the title)
    my $url = ($type eq '')?  "https://drive.google.com/file/d/$id/view" :                 # Regular File ### TODO
              ($type eq 'D')? "https://docs.google.com/document/d/$id/preview?hl=en" :     # Google Document
              ($type eq 'P')? "https://docs.google.com/presentation/d/$id/preview?hl=en" : # Google Presentation
              ($type eq 'S')? "https://docs.google.com/spreadsheets/d/$id/preview?hl=en" : # Google Spreadsheets
              ($type eq 'G')? "https://docs.google.com/drawings/d/$id/preview?hl=en" :     # Google Drawings (Graphics)
                              next; # if undef, it is not a valid ID!
    $F = `$wget -q '$url' -O - @wget_options`;
    my $title; html_title($F, $title); 
    download($type.$id, $title);
    return;
  }
                              
  if (defined $autodetect_dirs)
  {
    $F = `$wget -q 'https://drive.google.com/drive/folders/$id' -O - @wget_options`;
    my $title; html_title($F, $title);
    make_path($title); chdir($title);
    outbold("Getting \"$title\"");
  }
  my $push = 1; # `push = 1` means `no ids file` means `push to arrays and download from them` NOT `compare the old file with the new`
  $ID = '.'.IDFILENAME.'_'.$id;
  if (not defined $no_scan)
  {
    if ( -e $ID )
    { 
      move($ID, "${ID}_old");
      %olddates = getiddate("${ID}_old");
      $push = 0; # if an old IDs file exists, we use it w/ the new file, not the arrays.
    }
    $push = 1 if (defined $force);
    unlink("${ID}_");
    open (IDFILE, ">> ${ID}_") or exit_with_error("Problem opening the IDs file.\n"); # using a temp file is to not corrupt the file if gdrive-dl is interrupted
    wgetfolder($id, 0, '', $push, $F); undef $F;
    print "\e[1K\r";
    close(IDFILE); move("${ID}_", $ID); # when getting all the IDs is done
  }
  else
  { $push = 0; }
  
  # compare with the old ID file, or download all of the IDs
  if ( ! $push ) # = if an old IDs file exists or no_scan is chosen
  {
    my $old = "${ID}_old";
    my $new = $ID;
    undef $ID;
    
    # Deleted files/folder
    # the first "o" in these hashes names stands for original (the original IDs file, because we'll modify it soon). We use the original files to get the names of the to-be-deleted or to-be-downloaded files.
    my %oold = getidtitle($old);
    my %onew = getidtitle($new);
    # https://stackoverflow.com/a/4891975
    # we need to know the deleted files in order to know the moved/renamed files
    my %delids = map { $_ => 1 } grep {not $onew{$_}} keys %oold; # ids uniq to IDs_old -- to delete
    my %getids = (defined $force) # with $no_scan
                 ? %onew
                 : map { $_ => 1 } grep {not $oold{$_}} keys %onew; # ids uniq to IDs (new) -- to get
    my @delids = getids_sort($old, \%delids);
    my @getids = getids_sort($new, \%getids); undef %getids;
    if (defined $trash) { foreach (@delids) { next unless (chex($oold{$_})); trash($oold{$_}); } }
    # we want to delete, move/rename, then download. in this particular order. but we need the to-be-downloaded files id list in the second step (moved files), so we need to compute it first. but we won't download anything until the end of this if-body.
    
    # Moved or Renamed files/folders
    my @r = grep {not $delids{$_}} keys %oold; # not (deleted or to-be-downloaded) -- the intersection between the old and new ids
    undef %delids;
    
    # the m stands for moved
    my %mold; my %mnew;
    for (@r)
    {
      next if ($oold{$_} eq $onew{$_});
      $mold{$_} = $oold{$_};
      $mnew{$_} = $onew{$_};
    }

    #  if we moved a folder, its contents would move with it on the disk, but stay on the to-be-moved files list.
    #   so, first, we'll change the path of every subfile and subfolder to the new path, in the old list,
    #   and, second, we'll remove all duplicates between the old and new ids.
    for my $fid (grep /^F/, sort {length($mold{$a}) <=> length($mold{$b})} keys(%mold))
    {
      next if not defined $mold{$fid}; # if already deleted
      my $pathnew = $mnew{$fid}; my $pathold = $mold{$fid};
      for my $id (grep { $mold{$_} =~ /^\Q$pathold\E./ } sort {length($mold{$a}) <=> length($mold{$b})} keys(%mold))
      # the dot in the regex is to insure that the path itself is not grepped
      {
        $mold{$id} =~ s|^\Q$pathold\E|$pathnew|;
        if ($mold{$id} eq $mnew{$id}) # checking for duplicates
        { delete $mold{$id}; delete $mnew{$id}; }
      }
    }
    my @ids = getids_sort($new, \%mold); # should be no difference between %mold and %mnew here
    #  assuming a simple case: no existing files would have the new name of a will-be-moved file, no moving errors, etc
    #my @ids = getids($new, \%mold);
    for my $id (@ids)
    {
      next if (-e $mnew{$id} and not -e $mold{$id}); # already moved--happens when using --no-scan
      outmove($mold{$id}, $mnew{$id});
      move($mold{$id}, $mnew{$id}) or exit_with_error("Moving \"$mold{$id}\" to \"$mnew{$id}\" failed: $!"); # TODO in (bold?) red; remove '$!'
    }
    #undef %mold, %mnew;
    
    # New files/folder
    #  see the Deleted files/folder code above.    
    foreach (@getids)
    {
      next unless (chex($oold{$_})); next if (/^F/); # we create a folder only if it has contents
      download($_, $dldates[$_], $onew{$_});
    }
  }
  else # means, if $push. it's the else of `if ! $push`
  {
    # download all of them!
    for (0 .. $#dlids)
    {
      next unless (chex($dltitles[$_]));
      download($dlids[$_], $dldates[$_], $dltitles[$_]);
    }
  }
  print("\e[1K\r");
  my_confirm() if (defined $confirm_all or @confirm != 0);
  chdir('..') if (defined $autodetect_dirs);
}

sub wgetfolder # $_[0] = the folder id, $_[1] = date, $_[2] = current path, $_[3] = push?, $_[4] = $F
{
  my ($fid, $date, $path, $push) = @_;
  #if (defined $force and defined $olddates{'F'.$fid} and $date == $olddates{'F'.$fid})
  #{
  #  # the folder is up-to-date, so we will not do anything.
  #  # but we need to copy the data of its contents from the old ids file.
  #  # this is a quick and dirty solution; PURIFY!
  #  `grep '\t$path' "${ID}_old" >> "${ID}_"`;
  #  return;
  #}
  # It seems that this doesn't work, and we need to check the contents
  print "\e[1K\rScanning $path";
  
  # First, getting IDs and Titles
  my $F = (defined $autodetect_dirs and $path eq '') ? $_[4] : `$wget -q "https://drive.google.com/drive/folders/$fid" -O - @wget_options`;
  while ($F=~m#\[\\x22([^\\]+)\\x22,\[\\x22$fid\\x22]\\n,\\x22(.*?)\\x22,\\x22[^\\]+\\/([^\\]+)\\x.*?,[0-9]{13,},([0-9]{13,}),#g)
  {
    my $id = $1; my $title = $2; title_escape($title); my $typemarker = $3; my $date = $4;
    if ($typemarker eq 'vnd.google-apps.folder')
    { $typemarker = 'F'; }
    elsif ($typemarker eq 'vnd.google-apps.document')
    { $typemarker = 'D'; }
    elsif ($typemarker eq 'vnd.google-apps.presentation')
    { $typemarker = 'P'; }
    elsif ($typemarker eq 'vnd.google-apps.spreadsheet')
    { $typemarker = 'S'; }
    elsif ($typemarker eq 'vnd.google-apps.drawing')
    { $typemarker = 'G'; }
    else
    { $typemarker = '';  }

    title_duplicated($path, $title, $typemarker);
    if ($push)
    {
        push(@dlids, $typemarker.$id);
        push(@dltitles, $path.$title);
        push(@dldates, $date);
    }
    printf IDFILE "%s\t%s\t%s", $typemarker.$id, $date, $path.$title;
    if ($typemarker eq 'F')
    {
      print IDFILE "/\n"; # add a trailing '/' only if a folder
      wgetfolder($id, $date, "$path$title/", $push);
    }
    else
    { print IDFILE "\n"; }
  }
}

sub download # $_[0] is $id prefixed with the typemarker, $_[2] is $date, $_[1] is $title
{
  # http://www.labnol.org/internet/direct-links-for-google-drive/28356/
  my ($id, $date, $title) = @_; my $url;
  
  my $update; # just a flag
  if (%olddates and defined $olddates{$id} and $date != 0)
  {
    if ($date == $olddates{$id})
    {
       return; # nothing to do
    } else {
      $update = 1;
    }
  }
  if ($id =~ m/^0.*/) # Regular File
  {
    $url = "https://docs.google.com/uc?id=$id&export=download";
  }
  else # Google file
  {
    my $format; my $type; $id = substr($id, 1);
    if    ($_[0] =~ m/^D.*/) # Google Document
    {
      $format = (defined $mso)? 'docx' : (defined $odf)? 'odt' : (defined $txt)? 'txt' : 'pdf';
      $url = "https://docs.google.com/document/export?format=$format&id=$id";
    }
    elsif ($_[0] =~ m/^S.*/) # Google Spreadsheets
    {
      $format = (defined $mso)? 'xlsx' : (defined $odf)? 'ods' : (defined $txt)? ((defined $tsv)? 'tsv':'csv') : 'pdf';
      $url = "https://docs.google.com/spreadsheets/export?format=$format&id=$id";
    }
    elsif ($_[0] =~ m/^P.*/) # Google Presentation
    {
      $format = (defined $mso)? 'pptx' : (defined $odf)? 'odp' : (defined $txt)? 'txt' : 'pdf';
      $url = "https://docs.google.com/presentation/d/$id/export/$format";
    }
    elsif ($_[0] =~ m/^G.*/) # Google Drawings (Graphics)
    {
      $format = (defined $mso)? 'png' : (defined $odf)? 'png' : (defined $txt)? 'svg' : 'pdf';
      $url = "https://docs.google.com/drawings/d/$id/export/$format";
    }
    else # Folder; should not happen anyway
    { return; }
    $title .= ".$format";
  }

  unlink($title) if (defined $update);
  if ( ! -e "$title" )
  {
    (defined $update)? outupdate("$title"): outget("$title");
    if ( $title =~ m#^(.*)/[^/]+$# ) { make_path($1); }
    
    if ( system($wget, '-q', '-c', $url, '-O', $title.'._part', @wget_options) == 0 )
    {
      move($title.'._part', "$title");
      if (((stat($title))[7] < 4000) and (system('grep', '-q', '/uc?export=download', $title) == 0)) # TODO: PURIFY
      { outconfirm(get_size_confirm($title)); }
      else
      { outdone(get_filesize_str($title)); }
    }
    else
    {
      outfailed();
      unlink($gdl_cookiefile);
      exit_with_error("Download failed or interrupted\n");
    }
  }
}

sub get_this # given url, downloads it
{
  my $url = $_[0];
  if ($url =~ m|/folder|) # Folder
  {
     $url =~ /(0B[^?&]+)/;
     getroot($1);
  }
  else
  {
    my ($id) = $url=~m|/([0-9][-_0-9a-zA-Z]+)/|;
    $id = ($url =~ m|/file/|)?             $id : # Regular File
          ($url =~ m|/document/|)?     'D'.$id : # Google Document
          ($url =~ m|/presentation/|)? 'P'.$id : # Google Presentation
          ($url =~ m|/spreadsheets/|)? 'S'.$id : # Google Spreadsheet
          ($url =~ m|/drawings/|)?     'G'.$id : # Google Drawings (Graphics)
          ($url=~m|id=([^&/?]+)|)[0]; # some urls like https://drive.google.com/open?id=0BXXX
    if ($id eq '') {return}           # seems to be not a valid url
    # the 'hl=en' is to ensure the title contains 'Google Docs' or similar in English so its easier to be removed
    $url .= ($url =~ m/\?/)? '&hl=en' : '?hl=en';
    my $F = `$wget -q '$url' -O - @wget_options`;
    my $title; html_title($F, $title);
    download($id, 0, $title);
  }
}

sub trash
{
  # check if exists first
  #print "\e[1K\r";
  return if (not -e $_[0]); # already trashed--happens when using --no-scan
  outecho("Trashing \"$_[0]\"") unless (defined $_[1]);
  my $trashdir='.TRASH';
  #my $trashfile=$_[0];
  if ($_[0] =~ m#^(.*)/[^/]+/?$#)
  {
    $trashdir=$1.'/.TRASH';
  }
  make_path($trashdir);
  move($_[0], $trashdir);
}

sub html_title
# get the title from the <title> tag, and remove the non-printable unicode chars Google adds.
# $_[0] is $F, the entire html source; $_[1] is $title, the variable the title will be put in.
{
  $_[0]=~m|<title>(.*?)( - Google[^<]*)?</title>|;
  $_[1] = $1; title_escape($_[1]);
  $_[1]=~s/^\x{e2}\x{80}\x{aa}//;$_[1]=~s/\x{e2}\x{80}\x{ac}\x{e2}\x{80}\x{8f}$//;
  $_[1]=~s/^\x{e2}\x{80}\x{ab}//;$_[1]=~s/\x{e2}\x{80}\x{ac}\x{e2}\x{80}\x{8e}$//;
  
}

sub title_escape # makes every suitable substitution
{
  $_[0]=~s|\\\\u0026|&|g;
  $_[0]=~s|\\\\u[0-9a-f]{4}|-|g; # mostly, it's just a special char like < or >
  $_[0]=~s|\\\\\\x22|"|g;
  $_[0]=~s|\\x27|'|g;
  $_[0]=~s|\\/|-|g; # /
  $_[0]=~s|\\\\\\\\|-|g; # \
  $_[0]=~s|:|-|g;  
  $_[0]=~s|[[:space:]]+| |g;
  $_[0]=~s|^ *||g;
  $_[0]=~s| *$||g;
}

sub title_escape_readonly # it's title_escape(), but returns the escaped title instead of modifying in place
{
  my $a = $_[0]; title_escape($a); return $a;
}

sub title_list # it's title_escape(), but returns the escaped title instead of modifying in place; plus, it performs title_duplicated()
{
  my ($title, $typemarker) = @_;
  title_escape($title);

  title_duplicated('', $title, $typemarker);
  
  return $title;
}

sub do_check_duplicates # used with folders and Google files only, not regular files
{ # $_[0]: the full path/title (searched for), $_[1]: the to-be-modified title
  if (defined $duplicates{$_[0]})
  {
    $_[1] .= " ($duplicates{$_[0]})";
    $duplicates{$_[0]}++; # the first number to be appended to a name is 1
  }
  else
  { $duplicates{$_[0]} = 1; }
}

sub title_duplicated # add a number to avoid having files/folders with the same name in the same folder
{ # $_[0]: the parent path, $_[1]: the title, $_[2]: the type marker: '' for regular files, 'F' for folders, 'D' for Google Documents, 'P' for Google Presentations, 'S' for Google Spreadsheets
  my ($parent, $title, $marker) = @_;
  if ($marker eq '') # regular file
  {
    if (defined $duplicates{$parent.$title})
    {
      if ($title=~/\./) # if contains a dot
      {
        $title=~/^(.*)\.([^.]+)$/;
        $title = "$1 ($duplicates{$parent.$title}).$2";
      }
      else
      { $title .=" ($duplicates{$parent.$title})"; }
      $duplicates{$parent.$title}++;
    }
    else
    { $duplicates{$parent.$title} = 1; }
  }
  else # if folder or Google file
  {
    my $ext = ($marker eq 'F')?    ''      :      # folder--no extension
                                                  # Google file
              (    not defined $mso
               and not defined $odf
               and not defined $txt)?             #  PDF
                                   '.pdf'  :
              (defined $mso)?(                    #  MSOffice
                ($marker eq 'D')?  '.docx' :      #   Google document
                ($marker eq 'P')?  '.pptx' :      #   Google presentation
                ($marker eq 'S')?  '.xlsx' :      #   Google spreadsheet
                ($marker eq 'G')?  '.png'  :      #   Google drawings (graphics)
                                   '')     :     
              (defined $odf)?(                    #  OpenDocument
                ($marker eq 'D')?  '.odt'  :      #   Google document
                ($marker eq 'P')?  '.odp'  :      #   Google presentation
                ($marker eq 'S')?  '.ods'  :      #   Google spreadsheet
                ($marker eq 'G')?  '.png'  :      #   Google drawings (graphics)
                                   '')     :
                                                  #  PlainText
              (   $marker eq 'D'                  #   Google document
               or $marker eq 'P')? '.txt'  :      #   Google presentation
              (   $marker eq 'G')? '.png'  :      #   Google drawings (graphics)
              (   $marker eq 'S')?                #   Google spreadsheet
                (defined $tsv)?    '.tsv'  :      #    Tab-separated values
                                   '.csv'  :      #    Comma-separated values
                                   ''      ;
    # DISCLAIMER: The block of code above is written by a graphic designer, not a programmer. :P
    do_check_duplicates($parent.$title.$ext, $title);
  }
  $_[1] = $title;
}

sub chex ### it should be used as: `next unless (chex($title));`
# Choose and Exclude
# takes the path of a file or folder relative to its root (the given url),
# and returns true (1) to get it, or false (0) to skip it
# You cannot use both choose and exclude at the same time (at least until now).
{
  if (not defined $choose) { return 1; } # no chex
  elsif ($choose == 1) # choose
  {
    if (defined $chex->match($_[0]))
    { return 1; } else { return 0; }
  }
  elsif ($choose == 0) # exclude
  {
    if (not defined $chex->match($_[0]))
    { return 1; } else { return 0; }
  }
}

sub get_confirm_all
{
  my @c = split("\n", `grep -Ilr '/uc?export=download'`); # FIXME; PURIFY
  push(@c, split("\n", `find . -name '*_URL' -printf "\%P\\n"`)); # FIXME; PURIFY
  
  for my $a (@c)
  {
    if ($a =~ m|/|)
    {
      if ($a =~ m|^(.*/)\.(.*?)\.html$|)
      { $a = $1.$2; }
      elsif ($a =~ m|^(.*/)\.(.*?)_URL$|)
      { $a = $1.$2; }
      else # if it's the first file; i.e., downloaded by gdrive-dl itself, not confirmed yet
      {
        next if (defined $_[0]); # if confirm-check only
        $a =~ m|^(.*/)(.*?)$|;
        move("$a", "$1.$2.html");
      }
    }
    else
    {
      if ($a =~ m|^\.(.*?)\.html$|)
      { $a = $1; }
      elsif ($a =~ m|^\.(.*?)_URL$|)
      { $a = $1; }
      else # if it's the first file; i.e., downloaded by gdrive-dl itself, not confirmed yet
      {
        next if (defined $_[0]); # if confirm-check only
        move("$a", ".$a.html");
      }
    }
  }
  my %c = map {$_ => 1} @c;
  return sort keys %c;
}

sub get_size_confirm
# given an comfirm-required HTML file path and gives the size of the to-be-downloaded file
{ # src: http://www.perlmonks.org/?node_id=597051
  open my $fh, "<", $_[0] or return '0';
  while (my $l = <$fh>)
  {
    if ($l=~/ \(([0-9A-Z.]+)\)<\/span>/)
    { close $fh; return $1; }
  }
}

sub my_confirm
{
  my $wget_version = `$wget -V`; ($wget_version) = $wget_version=~/^GNU Wget ([0-9]+\.[0-9]+)[ .]/;
  $wget_version_1_16 = 1 if ($wget_version ge "1.16");
  if (defined $confirm_all) { confirm_all($wget_version_1_16); }
  else { confirm_one($_, $wget_version_1_16) for (@confirm); }
}

sub confirm_all # if the 1st agrument is given (defined), it means don't print "Confirming ..." because Wget >= 1.16
{
  my @c = get_confirm_all();
  confirm_one($_, $_[0]) for (@c);
}

sub confirm_one # if the 2nd agrument is given (defined), it means don't print "Confirming ..." because Wget >= 1.16
{
  my $a = $_[0];
  
  my $url; my $URL; my $html;
  
  if ($a =~ m|^(.*)/([^/]+)$|) # if the file is under a folder
  {
    $URL = "$1/.$2_URL";
    $html = "$1/.$2.html";
    make_path($1);
  }
  else
  {
    $URL = ".${a}_URL";
    $html = ".${a}.html";
  }
  
  if (-e $URL)
  {
    open fURL, '<', $URL and $url = <fURL>;
    close fURL;
  }
  else
  {
    $url = `grep '/uc?export=download' \"$a\" \"$html\" 2>/dev/null`; # FIXME; PURIFY
    ($url) = $url=~/(uc\?export=download[^"]+)"/;
    print STDERR "Cannot confirming $a\n" if ($url eq ''); # should not happen
    $url=~s/&amp;/\&/g;
    open fURL, '>', $URL and print fURL $url;
    close fURL;
  }
  outbold("Confirming $a") if (not defined $_[1]);
  confirm("https://drive.google.com/$url", "$a");
}

{
  # Google Drive direct download of big files
  #
  # Distributed under GPL 3 (http://www.gnu.org/licenses/gpl-3.0.html)
  # v1.0 by circulosmeos 04-2014.
  # http://circulosmeos.wordpress.com/2014/04/12/google-drive-direct-download-of-big-files
  #
  # v2.0 by Noureddin 06-2016 <noureddin95@gmail.com>
  # Change Log:
  #   - support continuing downloading files
  #   - more portability; it can run on virtually any OS with Perl and Wget (no /tmp; Wget's path is easily changeable)
  #   - improve output (to have the best experience, use Wget 1.16 or higher)
  #   - embeddability (can be a part of any Perl script, specifically gdrive-dl)
  # http://github.com/noureddin/gdrive-dl
  # To get it: https://github.com/noureddin/gdrive-dl/blob/b04158a2d967ac5dfdca54b62ca78087d5c92114/gdown.pl
  # This gdrive-dl version of gdown v2.0 is adapted from the original v2.0 in the above link.

  my $url;
  my $filename;
  my $tempfile;
  my $downloadfile;
  #my $cookiefile;
  my $urlfile; # for gdrive-dl
  
  sub confirm
  {
    ($url, $filename) = @_;
    $downloadfile = "$filename.part";
    
    if ($filename=~m|^(.*)/([^/]+)$|) # if the file is under a folder
    {
      $tempfile = "$1/.$2.html";
      #$cookiefile = "$1/.$2_cookie.txt";
      $urlfile = "$1/.$2_URL";
    }
    else
    {
      $tempfile = ".${filename}.html";
      #$cookiefile = ".${filename}_cookie.txt";
      $urlfile = ".${filename}_URL";
    }

    my $confirm;
    my $check;
    my $docs_flag;
    
    if (size_int(get_size_confirm($filename)) >= 26214400) # 25MB: Google's filesize limit on checking files for viruses
    { confirm_execute_command(); } # if the file is big
    else
    { confirm_execute_command_final(); return 1; } # if it's small, only one execution should do the job

    while (-s $tempfile < 100000) # only if the file isn't the download yet
    {
      open fTEMPFILE, '<', $tempfile;
      $check=0;
      foreach (<fTEMPFILE>)
      {
        if (/href="(\/uc\?export=download[^"]+)/)
        {
          $url='https://docs.google.com'.$1;
          $url=~s/&amp;/&/g;
          $confirm='';
          $check=1;
          last;
        }
        if (/confirm=([^;&]+)/)
        {
          $confirm=$1;
          $check=1;
          last;
        }
        if (/"downloadUrl":"([^"]+)/)
        {
          $url=$1;
          $url=~s/\\u003d/=/g;
          $url=~s/\\u0026/&/g;
          $confirm='';
          $check=1;
          last;
        }
      }
      close fTEMPFILE;
      exit_with_error("Couldn't confirm and download \"$filename\" :-(\n") if ($check == 0);
      $url=~s/confirm=([^;&]+)/confirm=$confirm/ if ($confirm ne '');
      
      # if a big file, the url redirects to docs.google.com/..., then redirects to another docs.google.com/... which is the final url
      if ($url=~/docs\.google\.com/)
      {
        if (defined $docs_flag)
        { confirm_execute_command_final(); return 1; }
        else
        { $docs_flag = 1; confirm_execute_command(); }
      }
      else
      { confirm_execute_command(); }
    }
  }

  sub confirm_execute_command
  { system($wget, '-q', $url, '-O', $tempfile, @wget_options); }
  #{ system($wget, '-q', '--load-cookie', $cookiefile, '--save-cookie', $cookiefile, $url, '-O', $tempfile, @wget_options); } # FIXME: two cookie files

  sub confirm_execute_command_final
  {
    #if (system($wget, '-c', '--load-cookie', $cookiefile, '--save-cookie', $cookiefile, $url, '-O', $downloadfile, @wget_options,
    if (system($wget, '-c', $url, '-O', $downloadfile, @wget_options,
               ($wget_version_1_16)?('-q', '--show-progress'):()) == 0) # if downloading finished successfully
    {
      #unlink($tempfile, $cookiefile, $urlfile);
      unlink($tempfile, $urlfile);
      move($downloadfile, $filename);
    }
    else
    { exit_with_error("\rDownload failed or interrupted\n"); }
    return 1;
  }
}

sub getidtitle  # is given the ids list file and returns a hash containing id-title pairs
{ # $_[0] is the name of the ids list file
  my %h;
  open FH, '<', $_[0] or return %h;

  $_ = <FH>;
  if ($_ =~ m|\t.*?\t|) # ids file is ID\tDATE\tTITLE
  {
    do {
      $_ =~ m|^[^\t]+\t([^\t]+)\t(.*)$|;
      $h{$1} = $2;
    } while(<FH>);
  } else { # ids file is ID\tTITLE
    do {
      $_ =~ m|^([^\t]+)\t(.*)$|;
      $h{$1} = $2;
    } while(<FH>);
  }

  close FH;
  return %h;
}

sub getiddate  # is given the ids list file and returns a hash containing id-date pairs
{ # $_[0] is the name of the ids list file
  my %h;
  open FH, '<', $_[0] or return %h;

  $_ = <FH>;
  if (not defined $_) { return %h; }
  if ($_ =~ m|\t.*?\t|) # ids file is ID\tDATE\tTITLE
  {
    do {
      $_ =~ m|^([^\t]+)\t([0-9]+)\t.*$|;
      $h{$1} = $2;
    } while(<FH>);
  } else { # ids file is ID\tTITLE
    %h = ();
  }

  close FH;
  return %h;
}

sub getids_sort  # is given the ids list file and a hash containing the required ids, and returns an array of these ids sorted according to the file
{ # $_[0] is the name of the ids list file, $_[1] is the hash (passed by ref: passed as \%h not %h)
  my %h = %{$_[1]};
  return () if (scalar(keys %h) == 0);
  return (keys %h) if (scalar(keys %h) == 1);
  my @a;
  open FH, '<', $_[0];
  while(<FH>)
  {
    /^([^\t]+)\t.*$/; # each line in the ids list file if "$id\t$title"
    push(@a, $1) if (defined $h{$1});
  }
  close FH;
  return @a;
}

sub get_filesize_str
{
  # based on the code on the page http://www.use-strict.de/perl-file-size-in-a-human-readable-format.html with a little change
  # License: Creative Commons Attribution
  my $size = (stat($_[0]))[7];

  if ($size > 1099511627776)  #   TiB: 1024 GiB
  { return sprintf("%.1fT", $size / 1099511627776); }
  elsif ($size > 1073741824)  #   GiB: 1024 MiB
  { return sprintf("%.1fG", $size / 1073741824); }
  elsif ($size > 1048576)     #   MiB: 1024 KiB
  { return sprintf("%.1fM", $size / 1048576); }
  elsif ($size > 1024)        #   KiB: 1024 B
  { return sprintf("%.1fK", $size / 1024); }
  else                        #   bytes
  { return "${size}B"; }
}

sub size_int
{
  # based on get_filesize_str's code
  my $str = shift;
  my ($int, $ltr) = $str=~/^([.0-9]+)([^0-9])?$/;

  if (defined $ltr)
  {
    if    ($ltr eq 'B') { return $int; }                # may not happen, as 'B' is usually omitted
    elsif ($ltr eq 'K') { return $int*1024; }
    elsif ($ltr eq 'M') { return $int*1048576; }        # 1024^2
    elsif ($ltr eq 'G') { return $int*1073741824; }     # 1024^3
    elsif ($ltr eq 'T') { return $int*1099511627776; }  # 1024^4
    else                { return $int; }                # should not happen anyway
  }
  else                  { return $int; }
}

sub get_ids_dir
{
  my $dir = $_[0];
  opendir DH, $dir or return ();
  my @d = grep { /^\.IDs_(.{28})/ and -f "$dir/$_" } readdir(DH);
  closedir DH;
  s/^\.IDs_(.{28}).*$/$1/ for (@d); # to get the id only
  my %h = map {$_ => 1} @d; # to get the unique ids only (if there is .IDs and .IDs_old files, for instance)
  return sort(keys %h); # to insure the same order is used always
}

sub exit_with_error # because die() prints the file name and the line number
{
  clean_exit();
  print STDERR $_[0];
  exit (defined $_[1])? $_[1] : 1; # TODO: exit codes
}

sub check_internet_connection
{
  exit_with_error("Cannot connect to the Google Drive server; check your Internet connection!\n") if (not check_online_url('https://drive.google.com'));
}

sub get_type # used with the IDs supplied by the user as arguments
{
  my $id = shift;
  
  if ($id =~ /^0.*/) # it's a regular file or a folder
  {
    if    (check_online_url("https://drive.google.com/drive/folders/$id"))          { return 'F'; } # Folder
    elsif (check_online_url("https://drive.google.com/file/d/$id/view"))            { return '' ; }  # Regular File
  }
  else # it's a Google file
  {
    if    (check_online_url("https://docs.google.com/document/d/$id/preview"))      { return 'D'; } # Google Document
    elsif (check_online_url("https://docs.google.com/presentation/d/$id/preview"))  { return 'P'; } # Google Presentation
    elsif (check_online_url("https://docs.google.com/spreadsheets/d/$id/preview"))  { return 'S'; } # Google Spreadsheets
    elsif (check_online_url("https://docs.google.com/drawings/d/$id/preview"))      { return 'G'; } # Google Drawings (Graphics)
  }
}

sub check_online_url
{
  return `sh -c "$wget --server-response -O - $_[0] 2>&1 | awk '/^  HTTP/{c=\\\$2}END{print c}'"` eq "200\n"; # PURIFY?
}

sub clean_exit
{ # used on exit
  unlink($gdl_cookiefile);
  unlink('/tmp/gdrive-dl-wget-tor');
}

sub outecho # echo the given string, surrounded by bold '*'s
{ print " \e[1m*\e[0m $_[0] \e[1m*\e[0m\n"; }

sub outget # outecho for "Getting"-messages
{ print " \e[1m*\e[0m Getting \"$_[0]\" \e[1m*\e[0m "; }

sub outupdate # outecho for "Updating"-messages
{ print " \e[1m*\e[0m Updating \"$_[0]\" \e[1m*\e[0m "; }

sub outdone # outecho for "Done"-messages
{ print "Done ($_[0]) \e[1m*\e[0m\n"; }

sub outmove # outecho for "Moving"-messages
{ print " \e[1m*\e[0m Moving \"$_[0]\" to \"$_[1]\" \e[1m*\e[0m\n"; }

sub outbold # echo in bold
{ print "\e[1m$_[0]\e[0m\n"; }

sub outfailed # output allcaps "failed" in bold red
{ print "\e[1;31mFAILED\e[0m \e[1m*\e[0m\n"; }

sub outconfirm # output all caps "confirmation required" in bold red
{ print "\e[1;31mCONFIRMATION REQUIRED ($_[0])\e[0m \e[1m*\e[0m\n"; }

sub outwarn # output warnings to stderr, bold red for $_[0], then bold for $_[1]
{ print STDERR "\e[1;31m$_[0]\e[0m \e[1m$_[1]\e[0m\n"; }
