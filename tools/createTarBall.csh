#!/bin/csh -f
#
# $Id$
#

if ($#argv != 3) then
   echo "usage:  $0  dev|rel  2|3  py3-bin-dir (only used if py3)"
   exit 1
endif
set isdev = 0
if ($argv[1] == "dev") then
   set isdev = 1
endif
set pyver = 2
if ($argv[2] == "3") then
   set pyver = 3
endif
set py3bin = $argv[3]

set svnbin = svn
if (`uname -n` == "arzach.stsci.edu") then
   set svnbin = /usr/bin/svn
endif

set out2to3 = ~/.pyraf_2to3_out
if (($pyver == 3) && (!(-e $py3bin))) then
   echo ERROR - py3bin dir does not exist - $py3bin - needed for 2to3ing
   exit 1
endif

set workDir = ~/.pyraf_py${pyver}_tar_ball
echo Creating work area: $workDir
/bin/rm -rf $workDir
mkdir $workDir
cd $workDir
if ($status != 0) then
   exit 1
endif
#
if ($isdev == 1) then
   set pyr = "pyraf-dev"
   set co_pyraf = 'co -q -r HEAD http://svn6.assembla.com/svn/pyraf/trunk'
   set co_tools = 'co -q -r HEAD https://svn.stsci.edu/svn/ssb/stsci_python/stsci_python/trunk/tools'
else
   set pyr = "pyraf-2.1"
   echo -n 'What will the pyraf dir name be? ('$pyr'): '
   set ans = $<
   if ($ans != '') then
      set pyr = $ans
   endif
   set brn = "release_2013_07"
   echo -n 'What is branch name? ('$brn'): '
   set ans = $<
   if ($ans != '') then
      set brn = $ans
   endif
   set co_pyraf = "co -q http://svn6.assembla.com/svn/pyraf/branches/$brn"
   set co_tools = "co -q https://svn.stsci.edu/svn/ssb/stsci_python/stsci_python/branches/$brn/tools"
endif

# get all source via SVN
echo "Downloading source for: $pyr"
$svnbin $co_pyraf $pyr
if ($status != 0) then
   echo ERROR svn-ing pyraf
   exit 1
endif
if ($pyver == 3) then
   cd $workDir
   /bin/rm -f $out2to3.p
   $py3bin/2to3 -w -n --no-diffs $pyr >& $out2to3.p
   if ($status != 0) then
      echo ERROR 2to3-ing pyraf
      exit 1
   endif
   cat $out2to3.p |grep -v ': Skipping implicit ' |grep -v 'gTool: Refactored ' |grep -v 'gTool: No changes to' |grep -v '^RefactoringTool: pyraf' |grep -v '^RefactoringTool: tools/' |grep -v '^RefactoringTool: distutils/'
endif

# for now, add svninfo file manually
cd $workDir/$pyr
set rev = `$svnbin info | grep '^Revision:' | sed 's/.* //'`
cd $workDir/$pyr/lib/pyraf
if (!(-e svninfo.py)) then
   echo '__svn_version__ = "'${rev}'"' > svninfo.py
   echo '__full_svn_info__ = ""' >> svninfo.py
   echo '__setup_datetime__ = "'`date`'"' >> svninfo.py
endif

# for now, remove new_setup* (it's confusing to users)
cd $workDir/$pyr
echo Removing:
/bin/rm new_setup*

# get extra pkgs into a subdir
cd $workDir/$pyr
mkdir required_pkgs
cd $workDir/$pyr/required_pkgs
echo "Downloading source for: tools, d2to1"
#
$svnbin co -q -r '{2012-12-12}' https://svn.stsci.edu/svn/ssb/stsci_python/d2to1/trunk d2to1
# $svnbin co -q -r HEAD         https://...
# the HEAD is not qwuite stable right now for PY3K uses - get back to this later
if ($status != 0) then
   echo ERROR svn-ing d2to1
   exit 1
endif
#
$svnbin co -q -r HEAD https://svn.stsci.edu/svn/ssb/stsci_python/stsci.distutils/trunk stsci.distutils
if ($status != 0) then
   echo ERROR svn-ing stsci.distutils
   exit 1
endif
#
#if ($pyver == 3) then
#   cd $workDir/$pyr/required_pkgs
#   /bin/rm -f $out2to3.d
#   $py3bin/2to3 -w -n --no-diffs distutils >& $out2to3.d
#   if ($status != 0) then
#      echo ERROR 2to3-ing distutils
#      exit 1
#   endif
#   cat $out2to3.d |grep -v ': Skipping implicit ' |grep -v 'gTool: Refactored ' |grep -v 'gTool: No changes to' |grep -v '^RefactoringTool: pyraf' |grep -v '^RefactoringTool: tools/' |grep -v '^RefactoringTool: distutils/'
#endif
$svnbin $co_tools tools
if ($status != 0) then
   echo ERROR svn-ing tools
   exit 1
endif
if ($pyver == 3) then
   cd $workDir/$pyr/required_pkgs
   /bin/rm -f $out2to3.t
   $py3bin/2to3 -w -n --no-diffs tools >& $out2to3.t
   if ($status != 0) then
      echo ERROR 2to3-ing tools
      exit 1
   endif
   cat $out2to3.t |grep -v ': Skipping implicit ' |grep -v 'gTool: Refactored ' |grep -v 'gTool: No changes to' |grep -v '^RefactoringTool: pyraf' |grep -v '^RefactoringTool: tools/' |grep -v '^RefactoringTool: distutils/'
endif

# for now, remove new_setup* (it's confusing to users)
cd $workDir/$pyr/required_pkgs/tools
echo Removing:
/bin/rm new_setup*

# get version info
set verinfo1 = `grep '__version__ *=' $workDir/$pyr/lib/pyraf/__init__.py | sed 's/.*= *//' | sed 's/"//g'`
set verinfo2 = `grep '__svn_version__' $workDir/$pyr/lib/pyraf/sv*.py | sed 's/.*= *//' | sed 's/"//g'`
set verinfo3 = "${verinfo1}-r$verinfo2"
echo "This build will show a version number of:  $verinfo3"
echo "$verinfo3" > ~/.pyraf_tar_ball_ver

# remove svn dirs
cd $workDir/$pyr
/bin/rm -rf `find . -name '.svn'`
if ($status != 0) then
   echo ERROR cleaning out .svn dirs
   exit 1
endif

# edit setup to comment out pyfits requirement (we dont need it for pyraf)
cd $workDir/$pyr/required_pkgs/tools
if (-e setup.cfg) then
   /bin/cp setup.cfg setup.cfg.orig
#  sed 's/^\(  *numpy .*\)/#\1/' > setup.cfg
   cat setup.cfg.orig |sed 's/^\(  *pyfits .*\)/#\1/' > setup.cfg
   echo DIFF for all required pkgs/versions
   diff setup.cfg.orig setup.cfg
endif

# edit pyraf setup stuff to use the required_pkgs sub-dir
cd $workDir/$pyr
# change line to: find-links = required_pkgs
if (-e setup.cfg) then
   /bin/cp setup.cfg setup.cfg.orig
   cat setup.cfg.orig | sed 's/^ *find-links *=.*/find-links = required_pkgs/' > setup.cfg
   echo DIFF for find-links
   diff setup.cfg.orig setup.cfg
endif
# change line to use: os.path.abspath("required_pkgs/distutils/lib")
#/bin/cp setup.py setup.py.orig
#cat setup.py.orig | sed 's/^\( *stsci_distutils *=\).*/\1 os.path.abspath("required_pkgs"+os.sep+"distutils"+os.sep+"lib")/' > setup.py
#echo DIFF for required_pkgs
#diff setup.py.orig setup.py

# tar and zip it - regular (non-win) version
cd $workDir
tar cf $pyr.tar $pyr
if ($status != 0) then
   echo ERROR tarring up
   exit 1
endif
gzip $pyr.tar
if ($status != 0) then
   echo ERROR gzipping
   exit 1
endif

# Now tar/zip the Windows version (via "zip")
if ($isdev == 1) then
   cd $workDir
   zip -rq ${pyr}-win $pyr
   if ($status != 0) then
      echo ERROR zipping up
      exit 1
   endif
endif

echo Successfully created tar-ball
