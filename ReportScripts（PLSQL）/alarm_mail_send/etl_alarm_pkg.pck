create or replace package etl_alarm_pkg as
  --============================================================================--
  --CREATE DATE : 2019-01-28
  --PURPOSE     : ETL alarm
  --CREATED BY  : Wangzhong
  --USAGE       :
  --UPDATED_AT  :
  --============================================================================--

  function get_alarm_status(alarm_id integer) return varchar2;

end etl_alarm_pkg;
/
create or replace package body etl_alarm_pkg as
  --============================================================================--
  --CREATE DATE : 2019-01-28
  --PURPOSE     : ETL alarm
  --CREATED BY  : Wangzhong
  --USAGE       :
  --UPDATED_AT  :
  --============================================================================--

  function get_alarm_status(alarm_id integer) return varchar2 as
    --============================================================================--
    --CREATE DATE : 2019-01-28
    --PURPOSE     : ETL alarm
    --CREATED BY  : Wangzhong
    --USAGE       : return 1 alarm, return 0 no alarm
    --UPDATED_AT  :
    --============================================================================--
    l_alarm_id integer;
    l_value    number;
    l_result   varchar2(4000);
    l_str      varchar2(200);
  
    p_alarm_name      varchar2(400);
    p_alarm_sql       varchar2(4000);
    p_alarm_column    varchar2(60);
    p_alarm_condition varchar2(400);
    p_alarm_email     varchar2(400);
  begin
    l_alarm_id := alarm_id;
    -- get metadata
    select alarm_sql,
           alarm_column,
           alarm_condition,
           alarm_name,
           alarm_email
      into p_alarm_sql,
           p_alarm_column,
           p_alarm_condition,
           p_alarm_name,
           p_alarm_email
      from etl_alarm_meta
     where alarm_id = l_alarm_id;
    -- exexute sql get value
    execute immediate p_alarm_sql
      into l_value;
    -- handel alarm condition string
    select replace(p_alarm_condition, p_alarm_column, l_value)
      into l_str
      from dual;
    -- generate alarm result from condition
    execute immediate '
    select case
             when ' || l_str || ' then
              1
             else
              0
           end
      from dual'
      into l_result;
    l_result := l_result || '|' || p_alarm_email || '|' || l_alarm_id ||
                ' | ' || p_alarm_name || '|' || p_alarm_condition;
    return l_result;
  exception
    when others then
      l_result := 9 || '|' || p_alarm_email || '|' || l_alarm_id;
      return l_result;
  end get_alarm_status;

end etl_alarm_pkg;
/
