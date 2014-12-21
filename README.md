gdrive-dl
=========
Google Drive Public Folder Mass Downloader


License
-------
GPLv3+: GNU GPL version 3 or later (http://gnu.org/licenses/gpl.html).

Installation
------------
Just download the two files `gdrive-dl` and `gdown.pl` and give them the proper permissions, then use `gdrive-dl` as shown below in the Help (Usage) section.


Requirements
------------
* bash
* coreutils
* ncurses
* grep
* sed
* wget
* perl (for confirmation)


Help (Usage)
----
<pre>Usage: gdrive-dl [OPTION]... URL...
Download from Google Drive an entire folder recursively,
with all it's files and sub-folders.
It can, also, download the big files that Google does not allow
download them without confirmation.
URL can be a folder URL or a file URL.
Example: gdrive-dl https://drive.google.com/folderview?id=0BXXXXXXXXXXX

General Options:
  -h,  --help            display this help text
  -V,  --version         display version information
  -L,  --license         display license information
  -U,  --update          update to the latest version
  -cu, --check-update    check if up-to-date or not

Selection Options:
  -ch, --choose=NAME     choose a file or folder by its NAME,
                         and nothing else will be downloaded
  -ex, --exclude=NAME    exclude a file or folder by its NAME,
                         and everything else will be downloaded

Output Options:
  -q,  --quiet           suppress all normal output
  -v,  --verbose         output more information than usual
  -d,  --debug           output much debugging information

Confirming Options:
  to get the big files that google does not allow to download them
  directly without confirmation.

  -c,  --confirm[=NAME]  if no NAME is given, download all files
                         that need confirmation in the current
                         folder (recursively).
                         if a NAME of a file is given, then
                         confirm and download this file.
  -cc, --confirm-check   only display the relative path of the files
                         that need confirmation in the current folder
                         (recursively).

Notice that both Choose and Exclude can be used many times in the same time
to choose or exclude many files or folders.
Notice also that you cannot use both at the same time.

Not using either '--quiet' or '--verbose' means the normal (default) mode.

Notice that short options cannot be compound, that means you
cannot use '-qc' as equivalent to '-q -c'; it will not be recognized.
Also, you must use the equal sign '=' with both short and long options,
if you assign them a value.</pre>

The Stages (The develepment cycle)
----------------------------------
It's Unstable -> Testing -> Stable.

Unstable is the only version to be modified by the developers
and contributors. It's supposed to be used by the developers
only, not the end users; because it may be very buggy.<br/>
Its version number (a date) indicates when it's changed the last time.

Testing is nothing more than an unstable version that just works
fine without visible bugs. In this stage, it is tested just to make
sure that there are not any bugs.<br/>
Its version number (a date) indicates when it has become a testing
version.

Stable is a testing version after being tested to make sure that
it's stable enough for a very normal end user that expects no errors.<br/>
Its version number (a date) indicates when it has become a stable
version.

The first stable release will be in February, 2015.<br/>
Any contributions are  appreciated.

Authors
------------
 Nour eddin M. (noureddin95@gmail.com)

Please notice that `gdown.pl` is not developed by the author of `gdrive-dl`; it's developed by Circulosmeos. See below.

Resources used in `gdrive-dl`<br/>
-  http://www.funbutlearn.com/2013/02/direct-download-link-to-your-google.html<br/>
-  http://circulosmeos.wordpress.com/2014/04/12/google-drive-direct-download-of-big-files

