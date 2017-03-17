gdrive-dl
=========
Google Drive Public Folder Mass Downloader


License
-------
GPLv3+: GNU GPL version 3 (http://gnu.org/licenses/gpl.html).

Installation
------------
Just download `gdrive-dl` and give it the proper permissions, then use it as shown below in the Help (Usage) section.

Or run these commands in the terminal:
````sh
mkdir -p $HOME/.bin
echo PATH=$PATH:$HOME/.bin >> $HOME/.bashrc
wget https://raw.githubusercontent.com/noureddin/gdrive-dl/master/gdrive-dl.pl -qO $HOME/.bin/gdrive-dl
chmod +x $HOME/.bin/gdrive-dl
````

Requirements
------------
Mainly Perl and Wget, but other Unix tools like `grep`, `find`, or `awk` are used.

Help (Usage)
----
<pre>  Gdrive-dl is a public Google Drive downloader without needing an account.
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
</pre>

### Using gdrive-dl with Tor
#### Installing and Configuring:
  You can use gdrive-dl with Tor, if you have

1. Tor Browser Bundle (downloadable from https://torproject.org/), and
2. `torsocks` (could be obtained from your distro's repos).

  To configure torsocks to work with you Tor Browser Bundle, run this
command in the terminal:

    sudo sed 's/^TorPort .*/TorPort 9150/' -i /etc/tor/torsocks.conf

#### Running:

1. run Tor Browser Bundle, and leave it running
2. run gdrive-dl with `-tor` switch

Any contributions are appreciated.

Author
------------
Nour eddin M. (noureddin95@gmail.com)

GPLv3 Code from [Circulosmeos](http://circulosmeos.wordpress.com/2014/04/12/google-drive-direct-download-of-big-files) is [modified](https://github.com/noureddin/gdrive-dl/blob/b04158a2d967ac5dfdca54b62ca78087d5c92114/gdown.pl) and included in gdrive-dl with more modification.

