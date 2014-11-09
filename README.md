# mysql 备份脚本

From: https://gist.github.com/DamianCaruso/931358

USEROPTIONS选项修改密码

# mysql 备份恢复

## example

备份目录

```
root@prd-db01:/data/backups/mysql#
root@prd-db01:/data/backups/mysql# tree -L 2
.
├── full
│   ├── 2014-10-10_15-46-08
│   └── 2014-10-11_16-00-01
└── incr
    └── 2014-10-10_15-46-08
```

计划任务执行脚本

    /root/mysql_backup/db01_mysql.sh
    
备份策略

每次脚本执行时，如果有full backup(全备份)，会做增量备份

多久做一次full backup，可以修改脚本

    FULLBACKUPLIFE=`expr 86400 \* 1` # Lifetime of the latest full backup in seconds


crontab(whenever): 

```ruby
every :day, :at => '2:00am' do
  command "/root/mysql_backup/db01_mysql.sh"
end
```

```
0 2 * * * /bin/bash -l -c '/root/mysql_backup/db01_mysql.sh'
```
