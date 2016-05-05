#! /bin/sh

# A script that will download the OpenBSD source files, update them, build a
# release, build the ports that you want, and bundle it all up into a new
# archive that can be put onto an FTP site with the same layout as the 
# OpenBSD FTP site.

# TODO:
# Copy public signatures across
# Add public signatures in install media
# Create functions for uninstall, removing old unpack, sources, etc.
# Create cleanup paramater, that jsut cleans up

# Crash on unset variables
set -u
# Stop if something fails
set -e

# We use this variable to calculate the interval between log entries
LASTLOG=`date +%s`

# Backup the file, jsut in case
cp install.sh /

# Store the OS version, so we can override it with a commandline option
OSVER=`uname -r`

# Setup switches that can be changed by commandline options
# Set to YES to use Checkout, rather than http/cvs update
CHECKOUT=NO

# Build base only, no ports
# Set to NO to not build ports
BUILDPORTS=YES

# Process command string
set +e
set +u
ARGS=`getopt v: $*`

if [ $? -ne 0 ]; then
	echo $0 \[-v version\]
	echo -v version	Set the version to use for key creation/CVS update
	exit 2
fi
set -e
set -u
set -- $ARGS
while [ $# -ne 0 ]
do
	case "$1"
	in
		-v)
			OSVER=$2
			CHECKOUT=YES
			BUILDPORTS=NO
			shift; shift;;
		--)
			shift; break;;
	esac
done

# Site specific stuff goes here, to make management of different
# scripts for different sites easier.

# The base filename of the signatures
SIGNATURENAME=berserk

# The FTP sites to download from
FTP_HOSTS[0]=http://192.168.36.1/pub/OpenBSD/$OSVER
FTP_HOSTS[1]=http://192.168.36.1/pub/OpenBSD/$OSVER
FTP_HOSTS[2]=http://ftp.openbsd.org/pub/OpenBSD/$OSVER

# The files we use for signatures downloaded from each FTP site.
# They must match the FTP sites, and can not be called "unset"
SIG_FILE[0]=berserk
SIG_FILE[1]=openbsd
SIG_FILE[2]=openbsd

# The ports we want to install.
install_ports ()
{
	install_port sysutils/smartmontools
	install_port devel/git -s -main
	install_port net/openmdns
	install_port net/avahi -f no_gui -f no_mono -f no_qt3 -f no_qt4
	install_port devel/splint
	install_port devel/cppcheck
	install_port devel/llvm
	install_port devel/subversion -f no_bindings -f no_ap2 -s -main
	# cmocka was added as of OpenBSD 5.6. If we are not there, then
	# add cmake, so taht we can build it ourselves.
	if is_atleast_version 5 6 ; then
		install_port devel/cmocka
	else
		install_port devel/cmake
	fi	
}

# End site specific section.
# Everything below here should not need to be customised on a site-by-site
# basis.

# CVS infomation

CVS_HOST_NUMBER=0

CVS_HOSTS[0]=anoncvs@anoncvs1.usa.openbsd.org:/cvs
RSA[0]="(RSA) SHA256:PFKE28DFbJLmqoLkq9xfBuiYl9GN2LABsvUpzNk+LlE"
DSA[0]="(DSA) SHA256:KgFHf4YO6nVgCxEEPzgT/jT7QEqSWr56HC2P/PkOKa0"
ECDSA[0]="(ECDSA) SHA256:Ofstc7xq/W+73vBMUpb3A4ZqLNhKI3u2FdzbOkJpOHI"
ED25519[0]="(ED25519) SHA256:IYHq/zKqYnd2wy71Br6X8Q1Jk0XGjOJA4PU6CAr6pDo"
RSAMD5[0]="(RSA) MD5:49:67:9a:46:62:8a:3f:4e:b3:63:ca:d6:41:29:2a:2f"
DSAMD5[0]="(DSA) MD5:a7:75:49:77:f3:47:d1:3c:5e:65:84:84:3b:03:f1:33"
ECDSAMD5[0]="(ECDSA) MD5:d3:b2:b5:68:87:3b:f6:93:21:fd:28:ea:cc:b6:e1:13"
ED25519MD5[0]="(ED25519) MD5:0d:83:33:eb:8a:ee:f9:b0:5f:77:a8:0e:48:65:ba:e1"
CVS_HOSTS[1]=anoncvs@anoncvs3.usa.openbsd.org:/cvs
RSA[1]="(RSA) SHA256:ZjlsP/GTTyMEKKkUNWTTA3p/+keRIxvp1kc6s+lQqTw"
DSA[1]="(DSA) SHA256:/+o+ogn8mzH+VQ8ZC85n4lItkx92YWrPFraLMrC2r3s"
ECDSA[1]="(ECDSA) SHA256:UAjbt7WxQff1I2ZEp5Vgkpr0JGN5MmFX8PYMaZgIP24"
ED25519[1]="(ED25519) SHA256:OuuKkSAzHjSA4TPjY9tHZyyKDUB5cpbIiXGFla2Xd1E"
RSAMD5[1]="(RSA) MD5:49:6f:4a:be:02:63:0d:c0:54:b0:57:f0:48:7f:ce:16"
DSAMD5[1]="(DSA) MD5:f9:ab:fc:60:a3:15:8f:9c:47:24:9e:92:15:78:0d:f3"
ECDSAMD5[1]="(ECDSA) MD5:99:4f:c8:23:6a:bf:75:1c:de:c9:11:bf:a4:fe:0a:51"
ED25519MD5[1]="(ED25519) MD5:7a:6c:1e:53:36:4c:06:74:9e:0c:0d:d6:ff:20:aa:03"
CVS_HOSTS[2]=anoncvs@openbsd.cs.toronto.edu:/cvs
RSA[2]="(RSA) SHA256:BosSX+gUL/17cUdppQlmXht1S5GGHrHNrL6+U3hyG+o"
DSA[2]="(DSA) SHA256:/wH3qgWOjC1iXh8PxWFl3Mv+IdgXHoPdLmFxJ0vAGgo"
ECDSA[2]="(ECDSA) SHA256:4I5R4/tGayGG0KDEsj6CY1eCqt2sbcYtA3nqnhUaD04"
ED25519[2]="(ED25519) SHA256:AqblfWV4KT2ptlpV3mq3gb4jNPzgYtjDvlBBcaeohxQ"
RSAMD5[2]="(RSA) MD5:bc:59:dc:6f:52:c9:80:2d:63:96:cd:34:e2:5a:fc:fd"
DSAMD5[2]="(DSA) MD5:46:df:59:8c:e9:e3:5d:2c:1d:e3:d8:9f:61:8a:3c:ab"
ECDSAMD5[2]="(ECDSA) MD5:9b:39:30:30:63:01:fa:ec:66:4f:63:3d:9a:7e:76:38"
ED25519MD5[2]="(ED25519) MD5:e2:38:fc:a8:a0:17:ad:7b:03:8a:49:b7:94:40:a0:d5"

# Calculate the CVS tag based on the version of OpenBSD installed
CVS_TAG=OPENBSD_`echo $OSVER | sed 's/\./_/g'`

# The filename of the official OpenBSD signature for this release
OBSD_SIG_FILE=openbsd-`echo $OSVER | sed 's/\.//g'`-base.pub

# OpenBSD's /bin/sh does not have pushd/popd, so jsut remember where we
# were when we started.
CURRENT_DIR=`pwd`

# Where we keep the logfiles.
CVS_LOGFILE=$CURRENT_DIR/cvsupdate.log
BUILD_LOGFILE=$CURRENT_DIR/build.log

# Where we do our temporary unpack of the source directories to CVS update them
UNPACK_DIR=$CURRENT_DIR/unpack

# Where we create the pub directory
SITE_DEST=$CURRENT_DIR/pub
# This is the location for all the release files
SITE_LOCATION=$SITE_DEST/OpenBSD/$OSVER

# Grab the major and minor versions of OpenBSD so we can use it for 
# CVS tags, Signature names, etc
OPENBSDMAJOR=`echo $OSVER| sed 's/^\([^.]*\)\..*/\1/g'`
OPENBSDMINOR=`echo $OSVER| sed 's/^[^.]*\.\(.*\)/\1/g'`

# The OpenBSD version as a string without spaces, used for signature names, to
# match what the OpenBSD team use
OPENBSDVER=`echo $OSVER | sed 's/^\([0-9]*\)\.\([0-9]\)/\1\2/g'`
# The version of the next version of OpenBSD. OpenBSD keep the signatures for
# this version and the next version.
OPENBSDNEXTVER=`expr $OPENBSDVER + 1`

# Where OpenBSD keeps the signatures. This is also where we will put ours.
SIGNIFYDIR=/etc/signify

# The names for our signatures
THISBASESIG=$SIGNIFYDIR/$SIGNATURENAME-$OPENBSDVER-base
THISPKGSIG=$SIGNIFYDIR/$SIGNATURENAME-$OPENBSDVER-pkg
NEXTBASESIG=$SIGNIFYDIR/$SIGNATURENAME-$OPENBSDNEXTVER-base
NEXTPKGSIG=$SIGNIFYDIR/$SIGNATURENAME-$OPENBSDNEXTVER-pkg

# log message
# Write a message to the log, and also display it to the screen.
# message: the message to log.
log ()
{
	currentlog=`date +%s`
	duration=`echo $currentlog - $LASTLOG | bc`
	hours=`echo $duration / 3600 | bc`
	remainder=`echo $duration % 3600 | bc`
	minutes=`echo $remainder / 60 | bc`
	seconds=`echo $remainder % 60 | bc`
	echo "$* (`date`) Elapsed: ` printf "%02s\n" $hours`:`printf "%02s\n" $minutes`:`printf "%02s\n" $seconds`" | tee -a $BUILD_LOGFILE
	LASTLOG=`date +%s`
	unset currentlog
	unset DURATION
	unset HOURS
	unset REMAINDER
	unset MINUTES
	unset SECONDS
}

# download_file [-f] [-v] filename
# Download the file from one of the FTP servers, starting at the first host
# and continuing along the list until we find an FTP that works
#
# -f force a re-download by removing the file first
# -v verify the file against the appropriate SHA256.sig file
# filename The file to download from the FTP_HOSTS[] array
# NOTE: filename can not be "unset"
download_file ()
{
	VERIFY="NO"

	# Loop through the paramaters until the only one left is th filename.
	while [ ${2:-unset} != unset ]; do
		# If the user supplied -f we want to remove the file first
		if [ x"$1" = "x-f" ]; then
			shift
			rm -f $1
		fi

		# We want to validate the file
		if [ x"$1" = "x-v" ]; then
			# OpenBSD 5.4 and earlier don't have signify(1), so ignore
			# the request to get the file
			if is_atleast_version 5 5 ; then
				VERIFY="YES"
			fi
			shift
		fi
	done
	
	if [ -f $1 ] ; then 
		# if the file exists, make sure it matches the 
		# signature
		if [ x$VERIFY  = xYES ] ; then
			if ! verify_signature $1 ; then
				log download_file: $1 exists but signature check failed. Removing.
				rm -f $1
			else
				log download_file: $1 exists and has a valid signature.
				return 0
			fi
		# If we are not checking signatures, and the file exists, 
		# we are done
		else
			log download_file: $1 exists. Not re-downloading.
			return 0
		fi
	fi

	log downloading $1

	k=0

	# Go through the hosts and try to download the file
	while [ $k -lt ${#FTP_HOSTS[@]} ] ; do

		# Get the file, and check if it succeeded
		if ftp ${FTP_HOSTS[$k]}/$1 ; then

			# Verify can only be set if we are using 
			# OpenBSD 5.5 or later, so no need to check 
			# the version again here.
			if [ x$VERIFY  = xYES ] ; then
				# If the signature matches, then we
				# have the right file, and there
				# is nothing more to do
				if verify_signature $1 ; then
					unset k
					return 0
				# If it didn't verify, remove the file
				# that we downloaded, so we can try
				# again.
				else
					rm $1
				fi
			else
				# If we aren't, or can not attempt to
				# validate the file, the best we can 
				# do here is check that the file
				# exists.
				if [ -f $1 ] ; then
					unset k
					return 0
				fi
			fi
		fi

		# if we get to here, the file didn't download, so go
		# onto the next FTP_HOSTS
		k=$(expr $k + 1)

	done

	# If we get here, the download has failed
	unset k
	log could not download $1.
	return 1
}

get_signatures ()
{
	i=0

	while [ "${FTP_HOSTS[*]:-unset}" != unset ] && [ $i -lt ${#FTP_HOSTS[@]} ] ; do
		if ! ftp -o SHA256-${SIG_FILE[$i]} ${FTP_HOSTS[$i]}/SHA256.sig ; then
			unset FTP_HOSTS[$i]
			unset SIG_FILE[$i]
			rebuild_array
			i=$(expr \( $i \) - 1)
		fi

		set +e
		i=`expr \( $i \) + 1`
		set -e
	done

	if [ "${FTP_HOSTS[*]:-unset}" = unset ] ; then
		log No valid FTP sites found.
		exit
	fi

	unset i
}

verify_signature_files ()
{
	j=0
	while [ "${SIG_FILE[*]:-unset}" != unset ] && [ $j -lt ${#SIG_FILE[@]} ] ; do
		if signify -V -q -e -p /etc/signify/$OBSD_SIG_FILE -x SHA256-${SIG_FILE[$j]} -m /dev/null > /dev/null 2>&1 ; then
			j=$(expr $j + 1)
			continue
		fi
		if signify -V -q -e -p $THISBASESIG.pub -x SHA256-${SIG_FILE[$j]} -m /dev/null > /dev/null 2>&1 ; then
			j=$(expr $j + 1)
			continue
		fi
		log SHA256-${SIG_FILE[$j]} signature check failed.
		unset FTP_HOSTS[$j]
		unset SIG_FILE[$j]
		rebuild_array
	done

	if [ "${SIG_FILE[*]:-unset}" = unset ] ; then
		log No valid signature files found.
		exit
	fi
	
	unset j
}

verify_signature ()
{
	l=0

	while [ $l -lt ${#FTP_HOSTS[@]} ] ; do
		if [ -f SHA256-${SIG_FILE[$l]} ] ; then
			if signify -C -q -p /etc/signify/$OBSD_SIG_FILE -x SHA256-${SIG_FILE[$l]} $1 > /dev/null 2>&1 ; then
				unset l
				return 0
			fi
			if signify -C -q -p $THISBASESIG.pub -x SHA256-${SIG_FILE[$l]} $1 > /dev/null 2>&1 ; then
				unset l
				return 0
			fi
		fi
		l=$(expr $l + 1)
	done
	log signify: verification of $1 failed
	unset l
	return 1
}

rebuild_array ()
{
	if [ "${SIG_FILE[*]:-unset}" = unset ] ; then
		return 0
	fi
	counter=0
	for element in ${SIG_FILE[@]} ; do
		SIG_FILE[$counter]=$element
		counter=$( expr $counter + 1 )	
	done
	while [ $counter -lt ${#SIG_FILE[@]} ] ; do
		unset SIG_FILE[$counter]
		counter=$( expr $counter + 1 )	
	done
	counter=0
	for element in ${FTP_HOSTS[@]} ; do
		FTP_HOSTS[$counter]=$element
		counter=$( expr $counter + 1 )	
	done
	while [ $counter -lt ${#FTP_HOSTS[@]} ] ; do
		unset FTP_HOSTS[$counter]
		counter=$( expr $counter + 1 )	
	done
	unset counter
	unset element
}

# $1 is the destination directory
update_cvs ()
{
	touch $CVS_LOGFILE
	log Updating $1 
	echo "Updating $1 (`date`)"| tee -a $CVS_LOGFILE
	old_pwd=`pwd`
	cd $1
	cvs -q -d ${CVS_HOSTS[$CVS_HOST_NUMBER]} update -r $CVS_TAG -Pd | tee -a $CVS_LOGFILE
	log Finish updating $1 
	echo "Finish updating $1 (`date`)" | tee -a $CVS_LOGFILE
	cd $old_pwd
	unset old_pwd
}

# $1 is the destination's parent directory
# $2 is the CVS repository to checkout
#
# example:
# checkout_cvs unpack src
# will checkout src to unpac/src
checkout_cvs ()
{
	touch $CVS_LOGFILE
	log checkout $2 
	echo "checkout $2 (`date`)"| tee -a $CVS_LOGFILE
	old_pwd=`pwd`
	cd $1
	cvs -q -d ${CVS_HOSTS[$CVS_HOST_NUMBER]} co -r $CVS_TAG -P $2 | tee -a $CVS_LOGFILE
	log Finish check out $2
	echo "Finish check out $2 (`date`)" | tee -a $CVS_LOGFILE
	cd $old_pwd
	unset old_pwd
}

# $1 is the directory
# $2 is the filename
# $3 is the regex
apply_regex_to_file ()
{
	if [ ! -d $1 ]; then
		log $1 does not exist no need to  apply regex ${3} 
		return 0
	fi

	old_pwd=`pwd`
	cd $1
	if [ ! -f $2 ]; then
		log $2 does not exist no need to  apply regex ${3} 
		return 0
	fi

	log Applying regex to $1/$2

	mv $2 $2.orig

	sed "$3" $2.orig > $2

	rm $2.orig
	cd $old_pwd
	unset old_pwd
}

# $1 is the cvs base directory
# $2 is the direcory that we want to patch up
# $3 is the major version that we want to use
# $4 is the minor version that we want to use
update_cvs_to_version ()
{
	if is_atleast_version $3 $4 ; then
		return 0
	fi
	if [ ! -d $1/$2 ]; then
		log $1/$2 does not exist, no need to update to OPENBSD_${3}_${4}
		echo "$1/$2 does not exist, no need to update to OPENBSD_${3}_${4} (`date`)" | tee -a $CVS_LOGFILE

		return 0
	fi

	touch $CVS_LOGFILE
	log Updating $1/$2 to OPENBSD_${3}_${4}
	echo "Updating $1/$2 to OPENBSD_${3}_${4} (`date`)" | tee -a $CVS_LOGFILE
	old_pwd=`pwd`
	cd $1/$2
	cvs -q -d ${CVS_HOSTS[$CVS_HOST_NUMBER]} update -r OPENBSD_${3}_${4} -Pd | tee -a $CVS_LOGFILE
	cd $old_pwd
	unset old_pwd
}

# update_cvs_to_date ()
#
# Update the CVS directory up to a certain date on the HEAD
#
# $1 is the cvs base directory
# $2 is the direcory that we want to patch up
# $3 is the date
# Example:
# update_cvs_to_date $UNPACK_DIR/ports www/lynx "Thu Jan 14 10:50:00 2016 UTC"
update_cvs_to_date ()
{

	touch $CVS_LOGFILE
	log Updating $1/$2 to HEAD
	echo "Updating $1/$2 to HEAD (`date`)" | tee -a $CVS_LOGFILE
	old_pwd=`pwd`
	cd $1/$2
	cvs -q -d ${CVS_HOSTS[$CVS_HOST_NUMBER]} update -r HEAD -Pd | tee -a $CVS_LOGFILE
	log Updating $1/$2 to ${3}
	echo "Updating $1/$2 to ${3} (`date`)" | tee -a $CVS_LOGFILE
	cvs -q -d ${CVS_HOSTS[$CVS_HOST_NUMBER]} update -D "${3}" -Pd | tee -a $CVS_LOGFILE
	cd $old_pwd
	unset old_pwd
}

# $1 is the name of the kernel to build
build_kernel ()
{
	log Start Kernel $1
	old_pwd=`pwd`
	cd /usr/src/sys/arch/`machine`/conf
	log Configuring $1
	config $1
	cd ../compile/$1
	log Building $1
	make clean && make && make install
	log Finish Kernel $1
	cd $old_pwd
}

install_port ()
{
        old_pwd=`pwd`
	PORTNAME=$1
        cd /usr/ports/$1
        shift
        PORTFLAVOR=""
        PORTSPACE=""
        SUBPKGFLAVOR=""
        SUBPKGSPACE=""
	MAKETARGET="install-all"
	touch $BUILD_LOGFILE
	log Start port $PORTNAME

        while [ $# -ne 0 ]; do
		if [ x"$1" = "x-f" ]; then
			shift
			PORTFLAVOR="$PORTFLAVOR$PORTSPACE$1"
			shift
			PORTSPACE=" "
		elif [ x"$1" = "x-s" ]; then
			shift
			SUBPKGFLAVOR="$SUBPKGFLAVOR$SUBPKGSPACE$1"
			MAKETARGET=install
			shift
			SUBPKGSPACE=" "
		elif [ x"$1" = "x-m" ]; then
			shift
			MAKETARGET="$1"
			shift
		else
			echo Unknown option %1 in call to install_port >&2
			exit
		fi
        done

	if [ "$PORTFLAVOR" -a "$SUBPKGFLAVOR" ] ; then
		log $PORTNAME: env FLAVOR=\"$PORTFLAVOR\" SUBPACKAGE=\"$SUBPKGFLAVOR\" make $MAKETARGET
		env FLAVOR="$PORTFLAVOR" SUBPACKAGE="$SUBPKGFLAVOR" make $MAKETARGET
	elif [ "$PORTFLAVOR" ] ; then
		log $PORTNAME: env FLAVOR=\"$PORTFLAVOR\" make $MAKETARGET
		env FLAVOR="$PORTFLAVOR" make $MAKETARGET
	elif [ "$SUBPKGFLAVOR" ] ; then
		log $PORTNAME: env SUBPACKAGE=\"$SUBPKGFLAVOR\" make $MAKETARGET
		env SUBPACKAGE="$SUBPKGFLAVOR" make $MAKETARGET
	else
        	log $PORTNAME: make $MAKETARGET
        	make $MAKETARGET
        fi
	log Finish port $PORTNAME

        cd $old_pwd
}

is_version ()
{
	if [ $OPENBSDMAJOR -eq $1 -a $OPENBSDMINOR -eq $2 ] ; then
		return 0
	else
		return 1
	fi	
}

is_atleast_version ()
{
	if [ $OPENBSDMAJOR -lt $1 -o \( $OPENBSDMAJOR -eq $1 -a $OPENBSDMINOR -lt $2 \) ] ; then
		return 1
	else
		return 0
	fi	
}

generate_sig ()
{
	if [ ! -f $1.sec ]; then
		if [ -f $1.pub ]; then
			echo Public signature without private found.
			exit
		fi
		log Creating signature files: $1
		signify -G -n -s $1.sec -p $1.pub
	fi
}


DATESTRING=`date "+%Y%m%d"`

echo "Ignore the \"cannot find module \`/stc\'\" message."
echo "SSH fingerprints:"

if is_atleast_version 5 7 ; then
	echo "${RSA[$CVS_HOST_NUMBER]}"
	echo "${DSA[$CVS_HOST_NUMBER]}"
	echo "${ECDSA[$CVS_HOST_NUMBER]}"
	echo "${ED25519[$CVS_HOST_NUMBER]}"
else
	echo "${RSAMD5[$CVS_HOST_NUMBER]}"
	echo "${DSAMD5[$CVS_HOST_NUMBER]}"
	echo "${ECDSAMD5[$CVS_HOST_NUMBER]}"
	echo "${ED25519MD5[$CVS_HOST_NUMBER]}"
fi

# this will fail, so make sure to disable error checking
set +e
cvs -qd ${CVS_HOSTS[$CVS_HOST_NUMBER]} co /stc
set -e

log "## Begin Build"

log Uninstalling Packages

while [ `pkg_info -q | grep -v -- -firmware- | wc -l ` -ne 0 ] ; do
	pkg_delete `pkg_info -tq`
done

log Removing Old pub

rm -rf $SITE_DEST
mkdir -p $SITE_LOCATION

# These may not be moutned, they can fail...
set +e
umount /dev/vnd0a
vnconfig -u vnd0
set -e

if is_atleast_version 5 5 ; then
	generate_sig $THISBASESIG
	generate_sig $THISPKGSIG
	generate_sig $NEXTBASESIG
	generate_sig $NEXTPKGSIG

	echo 'SIGNING_PARAMETERS=-s signify -s '$THISPKGSIG'.sec' > /etc/mk.conf
fi

log Removing unpacked sources
rm -rf $UNPACK_DIR

mkdir -p $UNPACK_DIR

if [ $CHECKOUT = NO ]; then
	 
	# Get the source
	if is_atleast_version 5 5 ; then
		get_signatures
		verify_signature_files
	fi

	download_file -v src.tar.gz
	download_file -v sys.tar.gz
	download_file -v ports.tar.gz
	download_file -v xenocara.tar.gz

	cd $UNPACK_DIR

	mkdir src

	# Untar the source
	cd $UNPACK_DIR/src
	log Unpacking src
	tar -xzf $CURRENT_DIR/src.tar.gz

	log Unpacking sys
	tar -xzf $CURRENT_DIR/sys.tar.gz
	cd $UNPACK_DIR

	log Unpacking xenocara
	tar -xzf $CURRENT_DIR/xenocara.tar.gz

	log Unpacking ports
	tar -xzf $CURRENT_DIR/ports.tar.gz

	# Update the source
	update_cvs $UNPACK_DIR/src
	update_cvs $UNPACK_DIR/xenocara
	update_cvs $UNPACK_DIR/ports
else
	checkout_cvs $UNPACK_DIR src
	checkout_cvs $UNPACK_DIR xenocara
	checkout_cvs $UNPACK_DIR ports
fi	

update_cvs_to_version $UNPACK_DIR/ports devel/p5-Error 5 7
update_cvs_to_version $UNPACK_DIR/ports lang/ruby/2.0 5 7
if ! is_atleast_version 5 9 ; then
	update_cvs_to_date $UNPACK_DIR/ports mail/p5-Email-MIME "Wed Sep 23 14:00:00 2015 UTC"
fi
if ! is_atleast_version 5 9 ; then
	update_cvs_to_date $UNPACK_DIR/ports sysutils/p5-File-Which "Fri Aug 14 17:00:00 2015 UTC"
fi

# Change the download URL to the new one. We no longer need to cvs update to
# a later version of OpenBSD's Makefile
if ! is_atleast_version 5 8 ; then
	apply_regex_to_file $UNPACK_DIR/ports/www/lynx Makefile 's/http:\/\/lynx.isc.org\/current\//http:\/\/invisible-mirror.net\/archives\/lynx\/tarballs\//g'
fi


# Rebuild the source dist files
log Rebuild src.tar.gz
cd $UNPACK_DIR/src
(tar -cf - ./!(sys) | gzip -9 > $SITE_LOCATION/src.tar.gz) 2>> $BUILD_LOGFILE

log Rebuild sys.tar.gz
(tar -cf - sys | gzip -9 > $SITE_LOCATION/sys.tar.gz) 2>> $BUILD_LOGFILE

log Rebuild ports.tar.gz
cd $UNPACK_DIR
(tar -cf - ports | gzip -9 > $SITE_LOCATION/ports.tar.gz) 2>> $BUILD_LOGFILE

log Rebuild xenocara.tar.gz
(tar -cf - xenocara | gzip -9 > $SITE_LOCATION/xenocara.tar.gz) 2>> $BUILD_LOGFILE

cd $SITE_LOCATION
sha256 src.tar.gz sys.tar.gz ports.tar.gz xenocara.tar.gz | sort > SHA256

if is_atleast_version 5 5 ; then
	signify -S -s $THISBASESIG.sec -m SHA256 -e -x SHA256.sig
fi

cd /usr/src

log Removing old /usr/src
rm -rf *

log Unpacking src
tar -xzf $SITE_LOCATION/src.tar.gz
log Unpacking sys
tar -xzf $SITE_LOCATION/sys.tar.gz

cd /usr
log Removing old /usr/xenocara
rm -rf xenocara

log Unpacking xenocara
tar -xzf $SITE_LOCATION/xenocara.tar.gz


log Removing old /usr/ports
rm -rf ports

log Unpacking ports
tar -xzf $SITE_LOCATION/ports.tar.gz

# There is a file whose name is too long to tar up. Restore it this way.
if is_version 5 8 ; then
	update_cvs /usr/ports/sysutils/logstash/logstash/patches
fi

# Build Kernel
if [ $(sysctl -n hw.ncpu) -eq 1 ]; then
	build_kernel GENERIC
else
	build_kernel GENERIC.MP
fi

# Build Userland
rm -rf /usr/obj/*
log Start build
cd /usr/src
log make obj
make obj
log make distrib-dirs
cd /usr/src/etc && env DESTDIR=/ make distrib-dirs
cd /usr/src
log make build
make build
log Finish build

# Build X
log Start X build
cd /usr/xenocara
rm -rf /usr/xobj/*
make bootstrap
make obj
make build
log Finish X build

log Start release
# Build the release
DESTDIR=/usr/dest
RELEASEDIR=/usr/release
export DESTDIR
export RELEASEDIR

rm -rf ${DESTDIR}
rm -rf ${DESTDIR}-base
rm -rf ${DESTDIR}-x
rm -rf ${RELEASEDIR}
mkdir -p ${DESTDIR}
mkdir -p ${RELEASEDIR}

cd /usr/src/etc
log make release
make release
cd /usr/src/distrib/sets
log sh checkflist
sh checkflist

cp ${RELEASEDIR}/SHA256 ${CURRENT_DIR}/release.SHA256

cd /usr

mv dest dest-base

log release completed

log xenocara release
rm -rf ${DESTDIR}
mkdir -p ${DESTDIR}
cd /usr/xenocara
log make release
make release

cd /usr

mv dest dest-x

mv dest-base dest

cp ${RELEASEDIR}/SHA256 ${CURRENT_DIR}/xenocara.SHA256

log Create iso
if [ -d /usr/src/distrib/$(machine -a)/iso ]; then
	# Build the ISO Install CD
	cd /usr/src/distrib/$(machine -a)/iso
	log make clean
	make clean
	log make ISO
	make RELXDIR=${RELEASEDIR} RELDIR=${RELEASEDIR}

	cp obj/install* ${RELEASEDIR}

	cd ${RELEASEDIR}

	sha256 install* > ${CURRENT_DIR}/iso.SHA256

fi

log Finish release

cd ${RELEASEDIR}

cat ${CURRENT_DIR}/release.SHA256 ${CURRENT_DIR}/xenocara.SHA256 ${CURRENT_DIR}/iso.SHA256 | sort > SHA256

if is_atleast_version 5 5 ; then
	signify -S -s $THISBASESIG.sec -m SHA256 -e -x SHA256.sig
fi
/bin/ls -1 >index.txt

rm -rf ${DESTDIR}
rm -rf ${DESTDIR}-base
rm -rf ${DESTDIR}-x

# RELEASEDIR and DESTDIR were causing problems with some ports
# Clear them out, but remember RELEASEDIR
RELEASEDIRX=${RELEASEDIR}
unset RELEASEDIR
unset DESTDIR
RELEASEDIR=${RELEASEDIRX}
unset RELEASEDIRX

cd ~
mkdir -p $SITE_LOCATION/`machine -a`
cp "${RELEASEDIR}/"* "$SITE_LOCATION/`machine -a`"

if [ $BUILDPORTS = YES ]; then

	install_ports

	PKGDIR=/usr/ports/packages/`machine -a`/all

	cd ${PKGDIR}
	/bin/ls -1 >index.txt

	mkdir -p $SITE_LOCATION/packages/`machine -a`
	cp "${PKGDIR}/"* $SITE_LOCATION/packages/`machine -a`
fi
cd ~

log Creating archive...
tar -czf "OpenBSD-$OSVER-`machine -a`-$DATESTRING.tar.gz" pub
log "## Complete Build"
