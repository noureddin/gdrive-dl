gdrive-dl
=========
Google Drive Public Folder Mass Downloader


License
-------
GPLv3+: GNU GPL version 3 or later (http://gnu.org/licenses/gpl.html).

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
Mainly Perl and Wget only, but also `grep` and `find` are used a few times.

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
  confirm [FILES]             confirm and download either FILES if supplied, or all the big
                             files in the current folder recursively.
  confirm-check               print a list of the big files in the current folder recursively
                             that are not yet confirmed and downloaded
  list [ID]... [URL]...       print the contents of the folders given by theirs IDs or URLs
  list-nodups [ID]... [URL]...  like 'list' but without duplicate-checking

Options:
  -ch, --choose=NAME           specify a file or folder to download only it
  -ex, --exclude=NAME          specify a file or folder to skip downloading it
  -f,  --force                 download (and complete) any non-downloaded files
  -ns, --no-scan               use the current IDs files and don't scan the online drive
                               use --no-scan with --force to complete downloading
  -c,  --confirm[=FILE]        like 'confirm' command, but after downloading the drive
  -cc, --confirm-check         like 'confirm-check' command, but after downloading the drive
  -ad, --autodetect-dirs       download into a folder named the same as the given drive
  -mso,--microsoft-office      download Google files as docx, pptx, and xlsx, not pdf
  -odf,--opendocument-format   download Google files as odt, odp, and ods, not pdf
  *                            anything else is passed to Wget as an option

Notes:
  - Short options cannot be bundled; using '-fc' instead of '-f -c' is NOT allowed.
  - Short options with a value also require an "="; use '-ch=big.pdf' NOT "-ch big.pdf".
  - The arguments order in the downloading/syncing form doesn't matter; all the options are
    parsed first, then all the IDs are downloaded, then all the URLs.
  - You can use many choose (or exclude) switches to choose (or exclude) many files/folders,
    but you cannot use both choose and exclude at the same time.

License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>.
To get updates or send feedback: https://github.com/noureddin/gdrive-dl
To contact the author: noureddin95@gmail.com
</pre>

Any contributions are appreciated.

Author
------------
Nour eddin M. (noureddin95@gmail.com)

####Resources used in `gdrive-dl`  
-  http://www.funbutlearn.com/2013/02/direct-download-link-to-your-google.html
-  http://www.labnol.org/internet/direct-links-for-google-drive/28356/
-  http://circulosmeos.wordpress.com/2014/04/12/google-drive-direct-download-of-big-files
-  http://mywiki.wooledge.org/BashPitfalls

