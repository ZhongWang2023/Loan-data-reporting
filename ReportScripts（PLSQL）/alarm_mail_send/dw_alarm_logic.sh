#!/bin/sh
#########################################################################
# created_at : 2019-01-28
# created_by : wangzhong
# purpose    : step 1 :get alarm status
#              step 2 :send alarm according alarm status
# script_name: dw_alarm_logic.sh
# updated_at : 
# usage      : ./dw_alarm_logic.sh <alarm_id>
########################################################################
# init env.
. /etc/profile
. ~/.bash_profile
. /home/simplecredit/project/kettle/webapps/env/kettle.env
time_str=` date +%Y%m%d `
script_name=` basename $0 `
log_time_info=` date +'[Info] %Y-%m-%d %H:%M:%S' `
log_time_error=` date +'[Error] %Y-%m-%d %H:%M:%S' `

# setup log file path
LOG_FILE=${kettle_log_path}/${script_name}${time_str}.log
touch ${LOG_FILE}

alarm_id=$1

# step 1 :get alarm status
export NLS_LANG="AMERICAN_AMERICA.UTF8"
alarm_status=` sqlplus -S ${olapuser} << EOF
  set heading off;
  set pagesize 0;
  set feedback off;
  set verify off;
  set echo off;
  select etl_alarm_pkg.get_alarm_status(${alarm_id}) from dual;
  exit;
EOF`
rs=$?
if [ ${rs} -ne 0 ]; then
  echo "${log_time_error} step 1 :get alarm status meet error" >> ${LOG_FILE}
  exit 1
fi

l_status=` echo ${alarm_status} | awk -F"|" '{print $1}' `

echo "${log_time_info} step 1 :get alarm status successfully. alarm_status : [	${alarm_status}	]" >> ${LOG_FILE}

# step 2 :send alarm according alarm status
etl_dt=` date +%Y%m%d `
if [ ${l_status} -eq 1 ]; then
  # send alarm email
  l_alarm_email=` echo ${alarm_status} | awk -F"|" '{print $2}' `
  l_alarm_id=` echo ${alarm_status} | awk -F"|" '{print $3}' `
  l_alarm_name=` echo ${alarm_status} | awk -F"|" '{print $4}' `
  l_alarm_condition=` echo ${alarm_status} | awk -F"|" '{print $5}' `
  p_content="<b>${l_alarm_id} : ${l_alarm_name} warning!!!<br>${l_alarm_condition}<br></b>"
  kitchen.sh -rep local_file -file ${kettle_spath}/alarm/alarm_send_email.kjb -level=basic "-param:MAIL_NAME=${l_alarm_email}" \
  "-param:ETL_DT=${etl_dt}" "-param:CONTENT=${p_content}"  >> ${LOG_FILE} 2>&1
elif [ ${l_status} -eq 9 ]; then
  l_alarm_email=` echo ${alarm_status} | awk -F"|" '{print $2}' `
  l_alarm_id=` echo ${alarm_status} | awk -F"|" '{print $3}' `
  p_content="<b>${l_alarm_id} : task meet error!!!<br></b>"
  kitchen.sh -rep local_file -file ${kettle_spath}/alarm/alarm_send_email.kjb -level=basic "-param:MAIL_NAME=${l_alarm_email}" \
  "-param:ETL_DT=${etl_dt}" "-param:CONTENT=${p_content}"  >> ${LOG_FILE} 2>&1
fi

