#!/bin/sh
#########################################################################
# created_at : 2019-01-28
# created_by : wangzhong
# purpose    : elt_alarm from etl_alarm_meta
# updated_at : 
# usage      : ./dw_alarm_entry.sh [test]
########################################################################
# init env.
. /etc/profile
. ~/.bash_profile
. /home/simplecredit/project/kettle/webapps/env/kettle.env
time_str=` date +%Y%m%d `
script_name=` basename $0 `
time_info=` date +'[Info] %Y-%m-%d %H:%M:%S' `

# setup log file path
LOG_FILE=${kettle_log_path}/${script_name}${time_str}.log
touch ${LOG_FILE}

mode=$1

biz_script=${kettle_spath}/shell/dw_alarm_logic.sh
# get alarm task count
alarm_id_list=""
if [ "${mode}"x = "test"x  ] ; then
  # test mode
  alarm_id_list=` sqlplus -S ${olapuser} << EOF
  set heading off;
  set pagesize 0;
  set feedback off;
  set verify off;
  set echo off;
  select alarm_id from etl_alarm_meta where stat = 2;
  exit;
EOF`
else
  # running mode
  alarm_id_list=` sqlplus -S ${olapuser} << EOF
  set heading off;
  set pagesize 0;
  set feedback off;
  set verify off;
  set echo off;
  select alarm_id from etl_alarm_meta where stat in (1,2);
  exit;
EOF`
fi

# handel null task list
alarm_cnt=`echo "${alarm_id_list}" | wc -l`
if [ ${alarm_cnt} -eq 0 ]
then
  echo "${time_info} no alarm task in etl_alarm_meta, process will exit" >> ${LOG_FILE}
  exit 0
fi
echo "${alarm_id_list}" >> ${LOG_FILE}

# call business logic
echo "${alarm_id_list}" | while read line
do
  ${biz_script} ${line}
done
