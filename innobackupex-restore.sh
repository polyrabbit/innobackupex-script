#!/bin/sh
# 
# Script to prepare and restore full and incremental backups created with innobackupex-runner.
#
# This script is provided as-is; no liability can be accepted for use.
#

INNOBACKUPEX=innobackupex-1.5.1
INNOBACKUPEXFULL=/usr/bin/innobackupex
TMPFILE="/tmp/innobackupex-restore.$$.tmp"
MYCNF=/etc/mysql/my.cnf
BACKUPDIR=/data/backups/mysql # Backups base directory
FULLBACKUPDIR=$BACKUPDIR/full # Full backups directory
INCRBACKUPDIR=$BACKUPDIR/incr # Incremental backups directory
MEMORY=1024M # Amount of memory to use when preparing the backup

#############################################################################
# Display error message and exit
#############################################################################
error()
{
  echo "$1" 1>&2
  exit 1
}

#############################################################################
# Check for errors in innobackupex output
#############################################################################
check_innobackupex_error()
{
  if [ -z "`tail -1 $TMPFILE | grep 'completed OK!'`" ] ; then
    echo "$INNOBACKUPEX failed:"; echo
    echo "---------- ERROR OUTPUT from $INNOBACKUPEX ----------"
    cat $TMPFILE
    rm -f $TMPFILE
    exit 1
  fi
}

# Check options before proceeding
if [ ! -x $INNOBACKUPEXFULL ]; then
  error "$INNOBACKUPEXFULL does not exist."
fi

if [ ! -d $BACKUPDIR ]; then
  error "Backup destination folder: $BACKUPDIR does not exist."
fi

if [ $# != 1 ] ; then
  error "Usage: $0 /absolute/path/to/backup/to/restore"
fi

if [ ! -d $1 ]; then
  error "Backup to restore: $1 does not exist."
fi

# Some info output
echo "----------------------------"
echo
echo "$0: MySQL backup script"
echo "started: `date`"
echo

PARENT_DIR=`dirname $1`

if [ $PARENT_DIR = $FULLBACKUPDIR ]; then
  FULLBACKUP=$1
  
  echo "Restore `basename $FULLBACKUP`"
  echo
else
  if [ `dirname $PARENT_DIR` = $INCRBACKUPDIR ]; then
    INCR=`basename $1`
    FULL=`basename $PARENT_DIR`
    FULLBACKUP=$FULLBACKUPDIR/$FULL
    
    if [ ! -d $FULLBACKUP ]; then
      error "Full backup: $FULLBACKUP does not exist."
    fi
    
    echo "Restore $FULL up to incremental $INCR"
    echo
    
    echo "Replay committed transactions on full backup"
    $INNOBACKUPEXFULL --defaults-file=$MYCNF --apply-log --redo-only --use-memory=$MEMORY $FULLBACKUP > $TMPFILE 2>&1
    check_innobackupex_error
    
    # Apply incrementals to base backup
    for i in `find $PARENT_DIR -mindepth 1 -maxdepth 1 -type d -printf "%P\n" | sort -n`; do
      echo "Applying $i to full ..."
      $INNOBACKUPEXFULL --defaults-file=$MYCNF --apply-log --redo-only --use-memory=$MEMORY $FULLBACKUP --incremental-dir=$PARENT_DIR/$i > $TMPFILE 2>&1
      check_innobackupex_error
      
      if [ $INCR = $i ]; then
        break # break. we are restoring up to this incremental.
      fi
    done
  else
    error "unknown backup type"
  fi
fi

echo "Preparing ..."
$INNOBACKUPEXFULL --defaults-file=$MYCNF --apply-log --use-memory=$MEMORY $FULLBACKUP > $TMPFILE 2>&1
check_innobackupex_error

echo
echo "Restoring ..."
$INNOBACKUPEXFULL --defaults-file=$MYCNF --copy-back $FULLBACKUP > $TMPFILE 2>&1
check_innobackupex_error

rm -f $TMPFILE
echo "Backup restored successfully. You are able to start mysql now."
echo "Verify files ownership in mysql data dir."
echo "Run 'chown -R mysql:mysql /path/to/data/dir' if necessary."
echo
echo "completed: `date`"
exit 0