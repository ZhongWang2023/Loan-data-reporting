create or replace package pkg_pboc_xyd as
  v_data_version           varchar2(3) := '1.0'; --程序版本号
  v_pboc_format_version    varchar2(3) := '1.3';
  v_pboc_organization_code varchar2(14) := '##############';
  v_contact_name           nvarchar2(30) := rpad('王钟', 30, ' ');
  v_phone_number           varchar2(25) := rpad('13628465255', 25, ' ');

  function gen_int(str varchar2, len int) return varchar2;

  function gen_str(str varchar2,
                   len int,
                   sub varchar2 default '0',
                   sep varchar2 default ' ') return varchar2;

  function gen_rpt_name(data_month varchar2) return varchar2;

  function gen_header(rpt_cnt  integer,
                      min_date varchar2,
                      max_date varchar2) return nvarchar2;
  /*
  rpt_cnt      本次上报的贷款个数,
  min_date     本次上报的最早应还款日期,
  max_date     本次上报的最晚应还款日期,
  contact_name 联系人,
  phone_number 联系电话,
  data_version 数据版本号,
  is_rereport  是否是重报 1-非重报,
  rpt_type     报文类型 1-正常报文,
  rsrv         预留字段*/

  procedure gen_body(rpt_month varchar2);

  procedure installment_format(rpt_month varchar2);

end pkg_pboc_xyd;
/
create or replace package body pkg_pboc_xyd as

  function gen_int(str varchar2, len int) return varchar2 as
    --============================================================================--
    --CREATE DATE : 2017-06-01
    --PURPOSE     : format integer data
    --CREATED BY  : Wangzhong
    --USAGE       :
    --UPDATE_AT   : 
    --DESCRIPTION : 返回左边补0到指定长度的字符串
    --============================================================================--
    l_str varchar2(32767) := str;
    l_len int := len;
  begin
    l_str := nvl(lpad(l_str, l_len, '0'),
                 replace(rpad('1', l_len, '0'), '1', '0'));
    return l_str;
  end gen_int;

  function gen_str(str varchar2,
                   len int,
                   sub varchar2 default '0',
                   sep varchar2 default ' ') return varchar2 as
    --============================================================================--
    --CREATE DATE : 2017-06-01
    --PURPOSE     : format string data
    --CREATED BY  : Wangzhong
    --USAGE       :
    --UPDATE_AT   : 
    --DESCRIPTION : 返回右边补空格（或者指定的其他字符）的字符串
    --              这里这几道编码转换： 现在字符串右边添加指定长度的空格字符串；
    --              然后转换字符串为GB18030编码；
    --              接着使用substrb()函数截取GB18030编码下的指定字节数的字符串；
    --              最后转换字符串为UTF8编码（数据库编码）；
    --============================================================================--
    l_str varchar2(32767) := str;
    l_len int := len;
    l_sub varchar2(1) := sub;
    l_sep varchar2(1) := sep;
  begin
    l_str := trim(replace(replace(replace(l_str, ' ', ''), chr(13), ''),
                          chr(10),
                          ''));
    if l_sub = '1' then
      l_str := substr(l_str, 1, len / 2);
    end if;
  
    l_str := convert(substrb(convert(l_str || rpad(' ', l_len, l_sep),
                                     'ZHS32GB18030'),
                             1,
                             l_len),
                     'UTF8',
                     'ZHS32GB18030');
    --l_str := rpad(l_str || rpad(' ', l_len, l_sep), l_len, ' ');
    return l_str;
  end gen_str;

  function gen_rpt_name(data_month varchar2) return varchar2 as
    --============================================================================--
    --CREATE DATE : 2017-06-01
    --PURPOSE     : generate data file name
    --CREATED BY  : Wangzhong
    --USAGE       :
    --UPDATE_AT   : 
    --DESCRIPTION : 返回上报数据文件名
    --              1~14 小雨点的金融机构代码
    --              15~20 数据发生年月 YYYYMM
    --              21~23 表示报文流水号 0-9 A-Z（大写）组成
    --              24 表示报文类型 1-正常数据
    --              25~27 报文流水号补充位 0-9 A-Z 组成 这里取的是0DD，所以每天一个流水号
    --============================================================================--
    l_data_month        varchar2(6) := data_month;
    l_serial_numbe      varchar2(3) := 'XYD'; --报文流水号
    l_serial_numbe_sply varchar2(3) := '0' || to_char(sysdate, 'DD'); --报文补充流水号
    l_rpt_type          varchar2(1) := '1'; --正常报文
    l_rpt_name          varchar2(27);
  begin
    l_rpt_name := v_pboc_organization_code || l_data_month ||
                  l_serial_numbe || l_rpt_type || l_serial_numbe_sply;
    dbms_output.put_line(l_rpt_name);
    return l_rpt_name;
  end gen_rpt_name;

  function gen_header(rpt_cnt  integer,
                      min_date varchar2,
                      max_date varchar2) return nvarchar2 as
    --============================================================================--
    --CREATE DATE : 2017-06-01
    --PURPOSE     : generate report header
    --CREATED BY  : Wangzhong
    --USAGE       :
    --UPDATE_AT   : 
    --DESCRIPTION : 返回报文头字符串
    --              1~3 数据格式版本号 N.N 1.3
    --              4~17 金融机构代码
    --              18~31 报文生成时间 YYYYMMDDHH24MISS
    --              32~34 上传程序的版本号 1.0
    --              35~35 重报提示 1-非重报
    --              36~36 报文类别 1-正常数据
    --              37~46 账户记录总数 数据报文中的账户记录总数
    --              47~54 本报文中最早结算/应还款日期
    --              55~62 本报文中最晚结算/应还款日期
    --              63~92 联系人
    --              93~117 联系电话
    --              118~147 预留字段
    --============================================================================--
    /*
    rpt_cnt      本次上报的贷款个数,
    min_date     本次上报的最早发生日期, YYYYMMDD
    max_date     本次上报的最晚发生日期, YYYYMMDD
    contact_name 联系人,
    phone_number 联系电话,
    data_version 数据版本号,
    is_rereport  是否是重报 1-非重报,
    rpt_type     报文类型 1-正常报文,
    rsrv         预留字段*/
    l_rpt_cnt  varchar2(10) := lpad(to_char(rpt_cnt), 10, '0');
    l_min_date varchar2(8) := min_date;
    l_max_date varchar2(8) := max_date;
  
    l_is_rereport varchar2(1) := '1';
    l_rpt_type    varchar2(1) := '1';
    l_rsrv        varchar2(30) := '                              ';
  
    l_gen_time varchar2(14);
  
    l_header_str varchar2(200);
  begin
    l_gen_time   := to_char(sysdate, 'YYYYMMDDHH24MISS');
    l_header_str := v_pboc_format_version || v_pboc_organization_code ||
                    l_gen_time || v_data_version || l_is_rereport ||
                    l_rpt_type || l_rpt_cnt || l_min_date || l_max_date ||
                    v_contact_name || v_phone_number || l_rsrv;
    return l_header_str;
  end gen_header;

  procedure gen_body(rpt_month varchar2) as
    --============================================================================--
    --CREATE DATE : 2017-06-01
    --PURPOSE     : generate report body
    --CREATED BY  : Wangzhong
    --USAGE       :
    --UPDATE_AT   : 
    --DESCRIPTION : 
    --============================================================================--
    c_base   integer := 345;
    c_iden   integer := 371;
    c_job    integer := 199;
    c_reside integer := 68;
    --c_guarantee              integer := 61;
    --c_bizupdate              integer := 63;
    c_special    integer := 224;
    v_biz_type   varchar2(1) := '1'; --1 贷款 2 信用卡
    v_biz_type_d varchar2(2) := '91'; --91 个人消费贷款
  
    l_rpt_month varchar2(6) := rpt_month;
  begin
    execute immediate 'truncate table pboc_xyd_tmp_newloan'; --new loans
    execute immediate 'truncate table pboc_xyd_tmp_scheloan'; --loans which have schedule
    execute immediate 'truncate table pboc_xyd_tmp_paidloan'; --loans which have debit
    execute immediate 'truncate table pboc_xyd_tmp_clearm'; --loans which clear, but not in rpt_month
    execute immediate 'truncate table pboc_xyd_tmp_stat24';
    --要上报的贷款 part 1 上报月新放款
    --===============================================--
    -- 上报月的新放款列表
    --===============================================--
    insert into pboc_xyd_tmp_newloan
      select loan_number, product_no, 'new' as loan_type
        from bi_dm.dm_loan
       where trunc(funding_success_date, 'MM') =
             to_date(l_rpt_month, 'YYYYMM')
         and product_no <> '1A'; --12882
    commit;
    --要上报的贷款 part 2 本月有应还款（不含本月新放款）或本月有欠款
    --===============================================--
    -- 上报月有应还款金额的放款列表
    -- 月初的还款计划中本月有应还未还的放款 sche_new
    -- 月初的还款计划中本月有欠款的放款 sche_old
    -- Warning 应该关联dm_loan表来过滤掉失效的还款计划 fixed
    --===============================================--
    insert into pboc_xyd_tmp_scheloan
      select distinct inst.loan_number,
                      inst.product_no,
                      'sche_new' as loan_type
        from bi_ods.alch_installments_his inst
        join bi_dm.dm_loan loan
          on inst.loan_number = loan.loan_number
       where inst.status_dt =
             to_char(to_date(l_rpt_month, 'YYYYMM') - 1, 'YYYYMMDD')
         and trunc(inst.original_due_date, 'MM') =
             to_date(l_rpt_month, 'YYYYMM')
         and inst.product_no <> '1A' --月初本月有应还未还
         and inst.principal_not_paid + inst.interest_not_paid > 0
      union all
      select inst.loan_number, inst.product_no, 'sche_old' as loan_type
        from bi_ods.alch_installments_his inst
        join bi_dm.dm_loan loan
          on inst.loan_number = loan.loan_number
       where inst.status_dt =
             to_char(to_date(l_rpt_month, 'YYYYMM') - 1, 'YYYYMMDD')
         and inst.original_due_date < to_date(l_rpt_month, 'YYYYMM')
         and inst.product_no <> '1A'
       group by inst.loan_number, inst.product_no
      having(sum(inst.principal_not_paid) > 0); --月初有欠款
    commit;
    --要上报的贷款 part 3 本月有还款行为（可能存在没有提前还款之类非计划内的还款）
    --===============================================--
    -- 本月有还款行为的贷款
    -- Warning 这里使用的是清算时间作为还款时间的，可能存在漏报多报
    -- ?? 有没有必要关联dm_loan 如果有非放款用户的收款信息就需要关联了
    --===============================================--
    insert into pboc_xyd_tmp_paidloan
      select loan_number, product_no, 'paid' as loan_type
        from bi_dm.dm_debiting
       where trunc(nvl(complete_time, account_time), 'MM') =
             to_date(l_rpt_month, 'YYYYMM')
         and product_no <> '1A'
       group by loan_number, product_no;
    commit;
  
    --===============================================--
    -- 不是本月结清的贷款 排除
    --===============================================--
    insert into pboc_xyd_tmp_clearm
      select loan.loan_number, loan.product_no, 'nocurclear' as loan_type
        from bi_dm.dm_debiting debit
        join bi_dm.dm_loan loan
          on debit.loan_number = loan.loan_number
       where trunc(nvl(debit.complete_time, debit.account_time), 'MM') <=
             to_date(l_rpt_month, 'YYYYMM')
         and loan.product_no <> '1A'
       group by loan.loan_number, loan.loan_amount, loan.product_no
      having(loan.loan_amount = sum(debit.principal) and trunc(max(nvl(debit.complete_time, debit.account_time)), 'MM') != to_date(l_rpt_month, 'YYYYMM'));
    commit;
  
    -- stat24
    --===============================================--
    -- 24个月还款状态拼接
    -- 看上报月结束后10天的状态
    --===============================================--
    insert into pboc_xyd_tmp_stat24
    --clear
      select loan_number,
             product_no,
             substr(lpad(nvl(rtrim(max(case
                                         when installment_number = 1 then
                                          stat24
                                       end) || max(case
                                                     when installment_number = 2 then
                                                      stat24
                                                   end) ||
                                   max(case
                                         when installment_number = 3 then
                                          stat24
                                       end) || max(case
                                                     when installment_number = 4 then
                                                      stat24
                                                   end) ||
                                   max(case
                                         when installment_number = 5 then
                                          stat24
                                       end) || max(case
                                                     when installment_number = 6 then
                                                      stat24
                                                   end) ||
                                   max(case
                                         when installment_number = 7 then
                                          stat24
                                       end) || max(case
                                                     when installment_number = 8 then
                                                      stat24
                                                   end) ||
                                   max(case
                                         when installment_number = 9 then
                                          stat24
                                       end) || max(case
                                                     when installment_number = 10 then
                                                      stat24
                                                   end) ||
                                   max(case
                                         when installment_number = 11 then
                                          stat24
                                       end) || max(case
                                                     when installment_number = 12 then
                                                      stat24
                                                   end) ||
                                   max(case
                                         when installment_number = 13 then
                                          stat24
                                       end) || max(case
                                                     when installment_number = 14 then
                                                      stat24
                                                   end) ||
                                   max(case
                                         when installment_number = 15 then
                                          stat24
                                       end) || max(case
                                                     when installment_number = 16 then
                                                      stat24
                                                   end) ||
                                   max(case
                                         when installment_number = 17 then
                                          stat24
                                       end) || max(case
                                                     when installment_number = 18 then
                                                      stat24
                                                   end) ||
                                   max(case
                                         when installment_number = 19 then
                                          stat24
                                       end) || max(case
                                                     when installment_number = 20 then
                                                      stat24
                                                   end) ||
                                   max(case
                                         when installment_number = 21 then
                                          stat24
                                       end) || max(case
                                                     when installment_number = 22 then
                                                      stat24
                                                   end) ||
                                   max(case
                                         when installment_number = 23 then
                                          stat24
                                       end) || max(case
                                                     when installment_number = 24 then
                                                      stat24
                                                   end),
                                   'C'),
                             '/'),
                         24,
                         '/'),
                    1,
                    23) || 'C' as stat24 --结清的贷款至少最后一期是C
        from (select inst.loan_number,
                     inst.product_no,
                     inst.installment_number,
                     inst.original_due_date,
                     inst.principal_not_paid,
                     inst.interest_not_paid,
                     inst.days_in_default,
                     sum(inst.principal_not_paid + inst.interest_not_paid) over(partition by inst.loan_number) as rest_amt,
                     count(1) over(partition by inst.loan_number) as installments,
                     case
                       when trunc(original_due_date, 'MM') >
                            to_date(l_rpt_month, 'YYYYMM') then
                        'C' --未到期已提前结清
                       when inst.days_in_default between 0 and 10 then
                        'N' --已到期10内结清
                       when inst.days_in_default between 11 and 30 then
                        '1'
                       when inst.days_in_default between 31 and 60 then
                        '2'
                       when inst.days_in_default between 61 and 90 then
                        '3'
                       when inst.days_in_default between 91 and 120 then
                        '4'
                       when inst.days_in_default between 121 and 150 then
                        '5'
                       when inst.days_in_default between 151 and 180 then
                        '6'
                       when inst.days_in_default > 180 then
                        '7'
                     end as stat24
                from bi_ods.alch_installments_his inst
                join (select loan_number, product_no
                       from pboc_xyd_tmp_newloan
                     union
                     select loan_number, product_no
                       from pboc_xyd_tmp_scheloan
                     union
                     select loan_number, product_no
                       from pboc_xyd_tmp_paidloan
                     minus
                     select loan_number, product_no from pboc_xyd_tmp_clearm) scp
                  on inst.loan_number = scp.loan_number
               where inst.status_dt =
                     to_char(last_day(to_date(l_rpt_month, 'YYYYMM')) + 10,
                             'YYYYMMDD')
                 and inst.product_no <> '1A'
               order by inst.loan_number, inst.installment_number)
       where rest_amt = 0 --clear
       group by loan_number, product_no
      union all
      --in loan
      select loan_number,
             product_no,
             lpad(nvl(rtrim(max(case
                                  when installment_number = 1 then
                                   stat24
                                end) || max(case
                                              when installment_number = 2 then
                                               stat24
                                            end) ||
                            max(case
                                  when installment_number = 3 then
                                   stat24
                                end) || max(case
                                              when installment_number = 4 then
                                               stat24
                                            end) ||
                            max(case
                                  when installment_number = 5 then
                                   stat24
                                end) || max(case
                                              when installment_number = 6 then
                                               stat24
                                            end) ||
                            max(case
                                  when installment_number = 7 then
                                   stat24
                                end) || max(case
                                              when installment_number = 8 then
                                               stat24
                                            end) ||
                            max(case
                                  when installment_number = 9 then
                                   stat24
                                end) || max(case
                                              when installment_number = 10 then
                                               stat24
                                            end) ||
                            max(case
                                  when installment_number = 11 then
                                   stat24
                                end) || max(case
                                              when installment_number = 12 then
                                               stat24
                                            end) ||
                            max(case
                                  when installment_number = 13 then
                                   stat24
                                end) || max(case
                                              when installment_number = 14 then
                                               stat24
                                            end) ||
                            max(case
                                  when installment_number = 15 then
                                   stat24
                                end) || max(case
                                              when installment_number = 16 then
                                               stat24
                                            end) ||
                            max(case
                                  when installment_number = 17 then
                                   stat24
                                end) || max(case
                                              when installment_number = 18 then
                                               stat24
                                            end) ||
                            max(case
                                  when installment_number = 19 then
                                   stat24
                                end) || max(case
                                              when installment_number = 20 then
                                               stat24
                                            end) ||
                            max(case
                                  when installment_number = 21 then
                                   stat24
                                end) || max(case
                                              when installment_number = 22 then
                                               stat24
                                            end) ||
                            max(case
                                  when installment_number = 23 then
                                   stat24
                                end) || max(case
                                              when installment_number = 24 then
                                               stat24
                                            end),
                            '*'),
                      '*'),
                  24,
                  '/') as stat24
        from (select inst.loan_number,
                     inst.product_no,
                     inst.installment_number,
                     inst.original_due_date,
                     inst.principal_not_paid,
                     inst.interest_not_paid,
                     inst.days_in_default,
                     sum(inst.principal_not_paid + inst.interest_not_paid) over(partition by inst.loan_number) as rest_amt,
                     count(1) over(partition by inst.loan_number) as installments,
                     case
                       when trunc(original_due_date, 'MM') >
                            to_date(l_rpt_month, 'YYYYMM') and
                            inst.principal_not_paid + inst.interest_not_paid = 0 and
                            inst.days_in_default = 0 then
                        'N' --未到期提前还
                       when trunc(original_due_date, 'MM') >
                            to_date(l_rpt_month, 'YYYYMM') and
                            inst.principal_not_paid + inst.interest_not_paid != 0 then
                        '*' --未到期未还
                       when inst.days_in_default between 0 and 10 then
                        'N' --已到期逾期10天内
                       when inst.days_in_default between 11 and 30 then
                        '1'
                       when inst.days_in_default between 31 and 60 then
                        '2'
                       when inst.days_in_default between 61 and 90 then
                        '3'
                       when inst.days_in_default between 91 and 120 then
                        '4'
                       when inst.days_in_default between 121 and 150 then
                        '5'
                       when inst.days_in_default between 151 and 180 then
                        '6'
                       when inst.days_in_default > 180 then
                        '7'
                     end as stat24
                from bi_ods.alch_installments_his inst
                join (select loan_number, product_no
                       from pboc_xyd_tmp_newloan
                     union
                     select loan_number, product_no
                       from pboc_xyd_tmp_scheloan
                     union
                     select loan_number, product_no
                       from pboc_xyd_tmp_paidloan
                     minus
                     select loan_number, product_no from pboc_xyd_tmp_clearm) scp
                  on inst.loan_number = scp.loan_number
               where inst.status_dt =
                     to_char(last_day(to_date(l_rpt_month, 'YYYYMM')) + 10,
                             'YYYYMMDD')
                 and inst.product_no <> '1A'
               order by inst.loan_number, inst.installment_number)
       where rest_amt != 0
       group by loan_number, product_no;
    commit;
  
    --基础段  base
    delete from pboc_xyd_base where rpt_month = l_rpt_month;
    commit;
  
    --insert into pboc_xyd_base
    --===============================================--
    -- 基础段数据
    --===============================================--
    insert into pboc_xyd_base
      select null as rec_length, --账户记录长度 
             'A' as data_type, --A基础段信息
             v_pboc_organization_code as organization_code, --金融机构代码
             v_biz_type as biz_type, --业务种类 1贷款 2 信用卡
             v_biz_type_d as biz_type_dtl, --业务种类细分91个人消费贷款
             pkg_pboc_xyd.gen_str(rpt.loan_number, 40) as biz_number, --业务号 loan_number
             nvl(cust.home_city_id, '500000') as biz_area, --业务发生地 需要编码
             to_char(loan.funding_success_date, 'YYYYMMDD') as biz_start_dt, --开户日期(存在下月开始起息的情况，换成放款成功日期)
             to_char(inst.biz_end_dt, 'YYYYMMDD') as biz_end_dt, --到期日期
             'CNY' as currency, --币种
             pkg_pboc_xyd.gen_int(round(loan.loan_amount), 10) as credit_line, --授信额度
             pkg_pboc_xyd.gen_int(round(loan.loan_amount), 10) as shared_credit_line, --共享授信额度
             pkg_pboc_xyd.gen_int(round(loan.loan_amount), 10) as max_debit_amount, --最大负债额度
             '4' as guarantee_type, --担保方式
             '03' as repymnt_frequency, --还款频率
             pkg_pboc_xyd.gen_str(loan.installments_org, 3) as repymnt_months, --还款月数
             pkg_pboc_xyd.gen_str(inst.rest_repymnt_months, 3) as rest_repymnt_months, --剩余还款月数
             case
               when rpt.cur_status = 'new' then
                to_char(loan.funding_success_date, 'YYYYMMDD')
               when rpt.cur_status in ('newclear', 'clear') then
                to_char(loan.last_repmnt_dt, 'YYYYMMDD')
               else
                to_char(inst.schedule_repymnt_dt, 'YYYYMMDD')
             end as schedule_repymnt_dt, --结算、应还款日期
             case
               when debit.last_repymnt_dt is null or
                    debit.last_repymnt_dt < loan.funding_success_date then
                to_char(loan.funding_success_date, 'YYYYMMDD')
               else
                to_char(debit.last_repymnt_dt, 'YYYYMMDD')
             end as last_repymnt_dt, --最近一次实际还款日期(默认换成了放款成功时间)
             pkg_pboc_xyd.gen_int(round(sche.schedule_repymnt_amt), 10) as schedule_repymnt_amt, --本月应还款金额
             pkg_pboc_xyd.gen_int(round(debit.repymnt_amt), 10) as repymnt_amt, --本月实际还款金额
             pkg_pboc_xyd.gen_int(round(inst.balance), 10) as balance, --余额
             pkg_pboc_xyd.gen_int(inst.cur_pastdue_terms, 2) as cur_pastdue_terms, --当前逾期期数
             pkg_pboc_xyd.gen_int(round(inst.cur_pastdue_amt), 10) as cur_pastdue_amt, --当前逾期总额
             pkg_pboc_xyd.gen_int(round(inst.pastdue_amt3160), 10) as pastdue_amt3160, --逾期31-60天未归还贷款本金
             pkg_pboc_xyd.gen_int(round(inst.pastdue_amt6190), 10) as pastdue_amt6190, --逾期61-90天未归还贷款本金
             pkg_pboc_xyd.gen_int(round(inst.pastdue_amt91180), 10) as pastdue_amt91180, --逾期91-180天未归还贷款本金
             pkg_pboc_xyd.gen_int(round(inst.pastdue_amt181), 10) as pastdue_amt181, --逾期180天以上未归还贷款本金
             null as accu_pastdue_terms, --累计逾期期数
             null as max_pastdue_terms, --最高逾期期数
             case
               when inst.cur_default = 0 then
                '1'
               when inst.cur_default between 1 and 30 then
                '2'
               when inst.cur_default between 31 and 90 then
                '3'
               when inst.cur_default between 91 and 180 then
                '4'
               when inst.cur_default >= 181 then
                '5'
               else
                '9'
             end as class5_status, --五级分类状态
             rpt.account_status as account_status, --账户状态
             stat24.stat24 as status_24, --24个月（账户）还款状态
             '0000000000' as balance180, --透支180天以上未付余额
             case
               when rpt.cur_status in ('new', 'newclear') then
                '2'
               else
                '1'
             end as is_new, --账户拥有者信息提示（是新开户还是老账户）
             pkg_pboc_xyd.gen_str(replace(cust.name, '·', '.'), 30) as name, --客户姓名
             '0' as certificate_type, --证件类型
             pkg_pboc_xyd.gen_str(cust.national_id, 18) as certificate_number, --证件号码
             pkg_pboc_xyd.gen_str('', 30) as reserve, --预留字段
             sysdate as biz_tm, --数据抽取时间
             rpt.product_no as product_no, --贷款产品编码
             l_rpt_month as rpt_month --上报月
      --select count(1)
        from (select scp.loan_number,
                     scp.product_no,
                     case
                       when nw.cur_status = 'new' and
                            clr.cur_status = 'clear' then
                        'newclear'
                       when nw.cur_status = 'new' and clr.cur_status is null then
                        'new'
                       when clr.cur_status = 'clear' then
                        'clear'
                       else
                        'current'
                     end as cur_status,
                     case
                       when clr.cur_status = 'clear' then
                        '3'
                       when pdue.cur_status = 'pastdue' then
                        '2'
                       else
                        '1'
                     end as account_status
                from (select loan_number, product_no
                        from pboc_xyd_tmp_newloan
                      union
                      select loan_number, product_no
                        from pboc_xyd_tmp_scheloan
                      union
                      select loan_number, product_no
                        from pboc_xyd_tmp_paidloan
                      minus
                      select loan_number, product_no from pboc_xyd_tmp_clearm) scp
                left join (select loan.loan_number,
                                 loan.product_no,
                                 'clear' as cur_status
                            from bi_dm.dm_debiting debit
                            join bi_dm.dm_loan loan
                              on debit.loan_number = loan.loan_number
                           where trunc(nvl(debit.complete_time,
                                           debit.account_time),
                                       'MM') <=
                                 to_date(l_rpt_month, 'YYYYMM')
                             and loan.product_no <> '1A'
                           group by loan.loan_number,
                                    loan.loan_amount,
                                    loan.product_no
                          having(loan.loan_amount = sum(debit.principal))) clr
                  on scp.loan_number = clr.loan_number
                left join (select loan_number,
                                 product_no,
                                 'new' as cur_status
                            from bi_dm.dm_loan loan
                           where trunc(funding_success_date, 'MM') =
                                 to_date(l_rpt_month, 'YYYYMM')) nw
                  on scp.loan_number = nw.loan_number
                join bi_dm.dm_loan loan
                  on scp.loan_number = loan.loan_number
                left join (select loan_number,
                                 product_no,
                                 'pastdue' as cur_status
                            from bi_ods.alch_installments_his
                           where status_dt = to_char(last_day(to_date(l_rpt_month,
                                                                      'YYYYMM')),
                                                     'YYYYMMDD')
                             and trunc(original_due_date, 'MM') <=
                                 to_date(l_rpt_month, 'YYYYMM')
                           group by loan_number, product_no
                          having(sum(principal_not_paid + interest_not_paid) > 0)) pdue
                  on scp.loan_number = pdue.loan_number) rpt
        join bi_dm.dm_loan loan
          on rpt.loan_number = loan.loan_number
        join bi_dm.dm_cust cust
          on ((loan.account_id = cust.account_id and loan.product_no = '2A' and
             cust.product_no = '1A2A') or
             (loan.account_id = cust.account_id and
             loan.product_no = cust.product_no))
        join (select loan_number,
                     min(installment_interest_start_dt) as biz_start_dt,
                     max(original_due_date) as biz_end_dt,
                     max(case
                           when trunc(original_due_date, 'MM') <=
                                to_date(l_rpt_month, 'YYYYMM') then
                            case
                              when original_due_date <
                                   to_date(l_rpt_month, 'YYYYMM') then
                               to_date(l_rpt_month, 'YYYYMM')
                              else
                               original_due_date
                            end
                         end) as schedule_repymnt_dt, --如果上报月没有还款日可能取到上报月之前的日期fixed
                     sum(case
                           when original_due_date >
                                last_day(to_date(l_rpt_month, 'YYYYMM')) then
                            1
                           else
                            0
                         end) as rest_repymnt_months,
                     sum(principal_not_paid) as balance,
                     sum(case
                           when trunc(original_due_date, 'MM') <=
                                to_date(l_rpt_month, 'YYYYMM') and
                                principal_not_paid + interest_not_paid > 0 then
                            1
                           else
                            0
                         end) as cur_pastdue_terms, --当前逾期期数
                     sum(case
                           when trunc(original_due_date, 'MM') <=
                                to_date(l_rpt_month, 'YYYYMM') and
                                principal_not_paid + interest_not_paid > 0 then
                            principal_not_paid + interest_not_paid
                           else
                            0
                         end) as cur_pastdue_amt, --当前逾期总额
                     sum(case
                           when days_in_default between 31 and 60 then
                            principal_not_paid
                           else
                            0
                         end) as pastdue_amt3160, --逾期31-60天未归还贷款本金
                     sum(case
                           when days_in_default between 61 and 90 then
                            principal_not_paid
                           else
                            0
                         end) as pastdue_amt6190, --逾期61-90天未归还贷款本金
                     sum(case
                           when days_in_default between 91 and 180 then
                            principal_not_paid
                           else
                            0
                         end) as pastdue_amt91180, --逾期91-180天未归还贷款本金
                     sum(case
                           when days_in_default > 180 then
                            principal_not_paid
                           else
                            0
                         end) as pastdue_amt181, --逾期180天以上未归还贷款本金
                     max(case
                           when trunc(original_due_date, 'MM') <=
                                to_date(l_rpt_month, 'YYYYMM') and
                                principal_not_paid + interest_not_paid > 0 then
                            days_in_default
                           else
                            0
                         end) as cur_default
                from bi_ods.alch_installments_his
               where status_dt =
                     to_char(last_day(to_date(l_rpt_month, 'YYYYMM')) + 10,
                             'YYYYMMDD')
               group by loan_number) inst
          on loan.loan_number = inst.loan_number
        left join (select loan_number,
                          max(trunc(nvl(complete_time, account_time))) as last_repymnt_dt,
                          sum(case
                                when trunc(nvl(complete_time, account_time), 'MM') =
                                     to_date(l_rpt_month, 'YYYYMM') then
                                 principal + interest
                                else
                                 0
                              end) as repymnt_amt
                     from bi_dm.dm_debiting
                    where trunc(nvl(complete_time, account_time)) <=
                          last_day(to_date(l_rpt_month, 'YYYYMM'))
                    group by loan_number) debit
          on loan.loan_number = debit.loan_number
        join (select loan_number,
                     case
                       when due_date >
                            last_day(to_date(l_rpt_month, 'YYYYMM')) then
                        sum(case
                              when trunc(original_due_date, 'MM') =
                                   to_date(l_rpt_month, 'YYYYMM') then
                               sche_principal + sche_interest
                              else
                               0
                            end)
                       else
                        sum(principal_not_paid + interest_not_paid) +
                        sum(case
                              when trunc(debit_time, 'MM') =
                                   to_date(l_rpt_month, 'YYYYMM') then
                               principal_paid + interest_paid
                              else
                               0
                            end)
                     end as schedule_repymnt_amt
                from (select inst.loan_number,
                             inst.installment_number,
                             inst.original_due_date,
                             max(nvl(debit.complete_time, debit.account_time)) as debit_time,
                             inst.principal_not_paid,
                             inst.interest_not_paid,
                             nvl(sum(debit.principal), 0) as principal_paid,
                             nvl(sum(debit.interest), 0) as interest_paid,
                             inst.principal_not_paid +
                             nvl(sum(debit.principal), 0) as sche_principal,
                             inst.interest_not_paid +
                             nvl(sum(debit.interest), 0) as sche_interest,
                             max(inst.original_due_date) over(partition by inst.loan_number) as due_date
                        from bi_ods.alch_installments inst
                        left join bi_dm.dm_debiting debit
                          on inst.id = debit.installment_id
                       group by inst.loan_number,
                                inst.installment_number,
                                inst.original_due_date,
                                inst.principal_not_paid,
                                inst.interest_not_paid
                       order by loan_number, inst.installment_number) sche
               group by loan_number, due_date) sche
          on loan.loan_number = sche.loan_number
        join pboc_xyd_tmp_stat24 stat24
          on loan.loan_number = stat24.loan_number;
    commit;
  
    --身份信息段 iden
    delete from pboc_xyd_identity where rpt_month = l_rpt_month;
    commit;
  
    -- udpate 关联每月的基础段 ，减少数据插入量
    insert into pboc_xyd_identity
      select base.biz_number as biz_number,
             'B' as data_type,
             nvl(cust.gender_code, '0') as gender,
             nvl(to_char(cust.birth_date, 'YYYYMMDD'), '19010101') as birthday,
             nvl(cust.marital_code, '90') as marital_status,
             pkg_pboc_xyd.gen_int(nvl(cust.education_code, '99'), 2) as highest_education,
             nvl(cust.degree_code, '9') as highest_degree,
             pkg_pboc_xyd.gen_str(cust.home_phone, 25) as residence_telephone,
             pkg_pboc_xyd.gen_int(cust.primary_phone, 16) as cell_phone,
             pkg_pboc_xyd.gen_str(regexp_replace(cust.company_phone,
                                                 '[^0-9]+',
                                                 ''),
                                  25) as work_telephone,
             pkg_pboc_xyd.gen_str(cust.email, 30) as email,
             pkg_pboc_xyd.gen_str(cust.home_province_name ||
                                  cust.home_city_name ||
                                  cust.home_district_name,
                                  60) as postal_address,
             '999999' as postal_code,
             pkg_pboc_xyd.gen_str(cust.home_province_name ||
                                  cust.home_city_name ||
                                  cust.home_district_name,
                                  60) as home_address,
             pkg_pboc_xyd.gen_str('', 30) as spouse_name,
             'X' as spouse_certificate_type,
             pkg_pboc_xyd.gen_str('', 18) as spouse_certificate_number,
             pkg_pboc_xyd.gen_str('', 60) as spouse_company,
             pkg_pboc_xyd.gen_str('', 25) as spouse_phone,
             sysdate as biz_tm,
             l_rpt_month as rpt_month
        from bi_dm.dm_cust cust
        join (select * from pboc_xyd_base where is_new = '2') base
          on cust.national_id = base.certificate_number
         and ((cust.product_no = '1A2A' and base.product_no = '2A') or
             cust.product_no = base.product_no);
    commit;
  
    --职业信息段 job
    delete from pboc_xyd_job where rpt_month = l_rpt_month;
    commit;
  
    insert into pboc_xyd_job
      select base.biz_number as biz_number,
             'C' as data_type,
             nvl(cust.occupation_code, 'Z') as zhiye,
             pkg_pboc_xyd.gen_str(substr(nvl(trim(cust.company_name),
                                             '暂缺'),
                                         1,
                                         30),
                                  60) as company,
             nvl(cust.company_industry_code, 'Z') as industry,
             pkg_pboc_xyd.gen_str(cust.company_province_name ||
                                  cust.company_city_name ||
                                  cust.company_district_name,
                                  60) as company_address,
             '999999' as company_postal_code,
             '0000' as start_year,
             case
               when cust.work_type = '1' then
                '1'
               when cust.work_type = '2' then
                '1'
               when cust.work_type = '3' then
                '2'
               when cust.work_type = '4' then
                '2'
               when cust.work_type = '5' then
                '3'
               when cust.work_type = '6' then
                '3'
               when cust.work_type = '7' then
                '3'
               when cust.work_type = '8' then
                '3'
               when cust.work_type = '9' then
                '4'
               when cust.work_type = '10' then
                '9'
               else
                '9'
             end as zhiwu,
             case
               when cust.work_type = '1' then
                '1'
               when cust.work_type = '2' then
                '1'
               when cust.work_type = '3' then
                '2'
               when cust.work_type = '4' then
                '2'
               when cust.work_type = '5' then
                '3'
               when cust.work_type = '6' then
                '3'
               when cust.work_type = '7' then
                '3'
               when cust.work_type = '8' then
                '3'
               when cust.work_type = '9' then
                '9'
               when cust.work_type = '10' then
                '9'
               else
                '0'
             end as zhicheng,
             pkg_pboc_xyd.gen_int(round(nvl(cust.income_cash, 0) +
                                        nvl(cust.income_ddi, 0)) * 12,
                                  10) as annual_income,
             pkg_pboc_xyd.gen_str(cust.bank_card_number, 40) as payroll_account,
             pkg_pboc_xyd.gen_int('', 14) as payroll_bank_code,
             sysdate as biz_tm,
             l_rpt_month as rpt_month
        from bi_dm.dm_cust cust
        join (select * from pboc_xyd_base where is_new = '2') base
          on cust.national_id = base.certificate_number
         and ((cust.product_no = '1A2A' and base.product_no = '2A') or
             cust.product_no = base.product_no);
    commit;
    --居住地址段 reside
    delete from pboc_xyd_reside where rpt_month = l_rpt_month;
    commit;
    insert into pboc_xyd_reside
      select base.biz_number as biz_number,
             'D' as data_type,
             pkg_pboc_xyd.gen_str(nvl(trim(cust.home_province_name ||
                                           cust.home_city_name ||
                                           cust.home_district_name),
                                      '暂缺'),
                                  60) as reside_address,
             '999999' as reside_postal_code,
             nvl(cust.house_status_code, '9') as reside_status,
             sysdate as biz_tm,
             l_rpt_month as rpt_month
        from bi_dm.dm_cust cust
        join (select * from pboc_xyd_base where is_new = '2') base
          on cust.national_id = base.certificate_number
         and ((cust.product_no = '1A2A' and base.product_no = '2A') or
             cust.product_no = base.product_no);
    commit;
    --担保信息段 guarantee
    /*目前没有此数据*/
    --交易标识变更段 bizupdate
    /*此数据用于修改已经上报贷款的贷款合同号（业务号）和金融机构代码，目前不处理*/
    --特殊交易段 special
    delete from pboc_xyd_spec_trsn where rpt_month = l_rpt_month;
    commit;
    insert into pboc_xyd_spec_trsn
      select base.biz_number as biz_number,
             'G' as data_type,
             case
               when base.account_status = '3' then
                '5'
               else
                '4'
             end as spec_trsn_type,
             to_char(debit.clearance_date, 'YYYYMMDD') as happen_date,
             '0   ' as month_cnt,
             pkg_pboc_xyd.gen_int(round(debit.principal_paid +
                                        debit.interest_paid),
                                  10) as trsn_amount,
             pkg_pboc_xyd.gen_str('', 200) as trsn_dtl,
             sysdate as biz_tm,
             l_rpt_month as rpt_month
        from pboc_xyd_base base
        join (select loan_number as biz_number,
                     max(trunc(nvl(complete_time, account_time))) as clearance_date,
                     sum(principal) as principal_paid,
                     sum(interest) as interest_paid
                from bi_dm.dm_debiting debit
               where debit.installment_id is null
                 and trunc(nvl(complete_time, account_time), 'MM') =
                     to_date(l_rpt_month, 'YYYYMM')
                 and product_no <> '1A'
               group by loan_number) debit
          on trim(base.biz_number) = debit.biz_number;
    commit;
  
    delete from pboc_xyd_output where rpt_month = l_rpt_month;
    commit;
  
    insert into pboc_xyd_output
      select pkg_pboc_xyd.gen_int(c_base + case
                                    when iden.biz_number is not null then
                                     c_iden
                                    else
                                     0
                                  end + case
                                    when job.biz_number is not null then
                                     c_job
                                    else
                                     0
                                  end + case
                                    when resi.biz_number is not null then
                                     c_reside
                                    else
                                     0
                                  end + case
                                    when strsn.biz_number is not null then
                                     c_special
                                    else
                                     0
                                  end,
                                  4) || base.data_type ||
             base.organization_code || base.biz_type || base.biz_type_dtl ||
             base.biz_number || base.biz_area || base.biz_start_dt ||
             base.biz_end_dt || base.currency || base.credit_line ||
             base.shared_credit_line || base.max_debit_amount ||
             base.guarantee_type || base.repymnt_frequency ||
             base.repymnt_months || base.rest_repymnt_months ||
             base.schedule_repymnt_dt || base.last_repymnt_dt ||
             base.schedule_repymnt_amt || base.repymnt_amt || base.balance ||
             base.cur_pastdue_terms || base.cur_pastdue_amt ||
             base.pastdue_amt3160 || base.pastdue_amt6190 ||
             base.pastdue_amt91180 || base.pastdue_amt181 ||
             basea.accu_pastdue_terms || basea.max_pastdue_terms ||
             base.class5_status || base.account_status || base.status_24 ||
             base.balance180 || base.is_new || base.name ||
             base.certificate_type || base.certificate_number ||
             base.reserve || iden.data_type || iden.gender || iden.birthday ||
             iden.marital_status || iden.highest_education ||
             iden.highest_degree || iden.residence_telephone ||
             iden.cell_phone || iden.work_telephone || iden.email ||
             iden.postal_address || iden.postal_code || iden.home_address ||
             iden.spouse_name || iden.spouse_certificate_type ||
             iden.spouse_certificate_number || iden.spouse_company ||
             iden.spouse_phone || job.data_type || job.zhiye || job.company ||
             job.industry || job.company_address || job.company_postal_code ||
             job.start_year || job.zhiwu || job.zhicheng ||
             job.annual_income || job.payroll_account ||
             job.payroll_bank_code || resi.data_type || resi.reside_address ||
             resi.reside_postal_code || resi.reside_status ||
             strsn.data_type || strsn.spec_trsn_type || strsn.happen_date ||
             strsn.month_cnt || strsn.trsn_amount || strsn.trsn_dtl as output_str,
             sysdate as biz_tm,
             l_rpt_month as rpt_month
        from (select * from pboc_xyd_base where rpt_month = l_rpt_month) base
        left join (select *
                     from pboc_xyd_identity
                    where rpt_month = l_rpt_month) iden
          on base.biz_number = iden.biz_number
        left join (select * from pboc_xyd_job where rpt_month = l_rpt_month) job
          on base.biz_number = job.biz_number
        left join (select *
                     from pboc_xyd_reside
                    where rpt_month = l_rpt_month) resi
          on base.biz_number = resi.biz_number
        left join (select *
                     from pboc_xyd_spec_trsn
                    where rpt_month = l_rpt_month) strsn
          on base.biz_number = strsn.biz_number
        join (select *
                from (select rpt_month,
                             biz_number,
                             pkg_pboc_xyd.gen_int(sum(cur_pastdue_terms)
                                                  over(partition by
                                                       biz_number order by
                                                       rpt_month),
                                                  3) as accu_pastdue_terms,
                             pkg_pboc_xyd.gen_int(max(cur_pastdue_terms)
                                                  over(partition by
                                                       biz_number order by
                                                       rpt_month),
                                                  2) as max_pastdue_terms
                        from pboc_xyd_base)
               where rpt_month = l_rpt_month) basea
          on base.biz_number = basea.biz_number;
    commit;
  
  end gen_body;

  procedure installment_format(rpt_month varchar2) as
    --============================================================================--
    --CREATE DATE : 2017-07-14
    --PURPOSE     : PBOC for xyd
    --CREATED BY  : Wangzhong
    --USAGE       :
    --============================================================================--
    l_rpt_month      varchar2(6) := rpt_month;
    l_last_rpt_month varchar2(6) := to_char(add_months(to_date(l_rpt_month,
                                                               'YYYYMM'),
                                                       -1),
                                            'YYYYMM');
    l_pcnt           integer;
  
    l_log_id   number;
    l_sp_name  varchar2(400);
    l_row_cnt  number;
    l_log_info varchar2(4000);
    l_sql_txt  varchar2(4000);
    l_stat_id  number;
  begin
    --init log info
    select log_id_seq.nextval into l_log_id from dual;
    l_sp_name  := 'INSTALLMENT_FORMAT(''' || l_rpt_month || ''')';
    l_log_info := 'clear partition of installment_pboc';
    l_sql_txt  := '';
    l_stat_id  := 1;
    log_p(l_log_id, l_sp_name, l_stat_id, l_row_cnt, l_log_info, l_sql_txt);
  
    select count(1)
      into l_pcnt
      from dba_objects
     where object_name = 'INSTALLMENT_PBOC'
       and object_type = 'TABLE PARTITION'
       and subobject_name = 'P_' || l_rpt_month;
  
    if l_pcnt = 1 then
      execute immediate 'alter table installment_pboc truncate partition p_' ||
                        l_rpt_month;
    else
      execute immediate 'alter table installment_pboc add partition p_' ||
                        l_rpt_month || ' values(''' || l_rpt_month || ''')';
    end if;
    l_row_cnt := sql%rowcount;
    commit;
  
    l_log_info := 'insert data to installment_pboc';
    l_stat_id  := 1;
    log_p(l_log_id, l_sp_name, l_stat_id, l_row_cnt, l_log_info, l_sql_txt);
    --**************
    -- logic:
    -- 如果还款计划中的'应收本金'为0,则取 已收作为还款计划的应收
    --**************
  
    insert into installment_pboc
      (id,
       original_due_date,
       installment_interest_start_dt,
       installment_number,
       days_in_default,
       principal,
       interest,
       principal_not_paid,
       interest_not_paid,
       paid_off,
       account_id,
       loan_id,
       loan_number,
       override_interest,
       override_principal,
       override_amount,
       created_at,
       updated_at,
       status_dt,
       service_charge,
       late_fee,
       service_charge_not_paid,
       late_fee_not_paid,
       product_no,
       default_interest,
       principal_paid,
       interest_paid,
       debit_time,
       rpt_month)
      select inst.id,
             inst.original_due_date,
             inst.installment_interest_start_dt,
             inst.installment_number,
             case
               when inst.principal_not_paid > 0 then
                inst.days_in_default + 1
               else
                inst.days_in_default
             end as days_in_default,
             case
               when inst.principal != 0 then
                inst.principal
               else
                nvl(debit.principal, 0)
             end as principal,
             case
               when inst.principal != 0 then
                inst.interest
               else
                nvl(debit.interest, 0)
             end as interest,
             inst.principal_not_paid,
             inst.interest_not_paid,
             inst.paid_off,
             inst.account_id,
             inst.loan_id,
             inst.loan_number,
             inst.override_interest,
             inst.override_principal,
             inst.override_amount,
             inst.created_at,
             inst.updated_at,
             inst.status_dt,
             inst.service_charge,
             inst.late_fee,
             inst.service_charge_not_paid,
             inst.late_fee_not_paid,
             inst.product_no,
             inst.default_interest,
             nvl(debit.principal, 0) as principal_paid,
             nvl(debit.interest, 0) as interest_paid,
             debit.debit_time as debit_time,
             l_rpt_month as rpt_month
        from (select inst.*
                from (select *
                        from bi_ods.alch_installments_his
                       where status_dt =
                             to_char(last_day(to_date(l_rpt_month, 'YYYYMM')) + 10,
                                     'YYYYMMDD')
                         and product_no != '1A') inst
                join bi_dm.dm_loan loan
                  on inst.loan_number = loan.loan_number
               order by inst.loan_number, inst.installment_number) inst
        left join (select loan_number,
                          installment_number,
                          max(nvl(complete_time, account_time)) as debit_time,
                          sum(principal) as principal,
                          sum(interest) as interest
                     from bi_dm.dm_debiting
                    where product_no <> '1A'
                    group by loan_number, installment_number
                    order by loan_number, installment_number) debit
          on inst.loan_number = debit.loan_number
         and inst.installment_number = debit.installment_number;
    l_row_cnt := sql%rowcount;
    commit;
  
    l_log_info := 'clear partition of installment_pboc_std';
    l_stat_id  := 1;
    log_p(l_log_id, l_sp_name, l_stat_id, l_row_cnt, l_log_info, l_sql_txt);
  
    select count(1)
      into l_pcnt
      from dba_objects
     where object_name = 'INSTALLMENT_PBOC_STD'
       and object_type = 'TABLE PARTITION'
       and subobject_name = 'P_' || l_rpt_month;
  
    if l_pcnt = 1 then
      execute immediate 'alter table installment_pboc_std truncate partition p_' ||
                        l_rpt_month;
    else
      execute immediate 'alter table installment_pboc_std add partition p_' ||
                        l_rpt_month || ' values(''' || l_rpt_month || ''')';
    end if;
    l_row_cnt := sql%rowcount;
    commit;
  
    l_log_info := 'insert data to installment_pboc_std';
    l_stat_id  := 1;
    log_p(l_log_id, l_sp_name, l_stat_id, l_row_cnt, l_log_info, l_sql_txt);
    insert into installment_pboc_std
      (loan_number,
       sche_date,
       adj_sche_date,
       default_days,
       sche_principal,
       sche_interest,
       principal_not_paid,
       interest_not_paid,
       principal_paid,
       interest_paid,
       debit_time,
       loan_due_date,
       rpt_month)
      select inst.loan_number,
             case
               when inst.loan_due_date < to_date(l_rpt_month, 'YYYYMM') then
                last_day(to_date(l_rpt_month, 'YYYYMM'))
               else
                max(case
                      when inst.original_due_date <=
                           last_day(to_date(l_rpt_month, 'YYYYMM')) then
                       inst.original_due_date
                    end)
             end as sche_date,
             case
               when inst.loan_due_date < to_date(l_rpt_month, 'YYYYMM') then
                last_day(to_date(l_rpt_month, 'YYYYMM'))
               else
                max(case
                      when inst.original_due_date <=
                           last_day(to_date(l_rpt_month, 'YYYYMM')) then
                       inst.original_due_date
                    end)
             end + case
               when max(inst.days_in_default) > 10 then
                10
               else
                max(inst.days_in_default)
             --max(trunc(inst.debit_time)) - max(inst.original_due_date)
             end as adj_sche_date,
             max(inst.days_in_default) as default_days,
             sum(inst.principal) as sche_principal,
             sum(inst.interest) as sche_interest,
             sum(inst.principal_not_paid) as principal_not_paid,
             sum(inst.interest_not_paid) as interest_not_paid,
             sum(nvl(debit.principal_paid, 0)) as principal_paid,
             sum(nvl(debit.interest_paid, 0)) as interest_paid,
             max(debit.debit_time) as debit_time,
             inst.loan_due_date,
             l_rpt_month as rpt_month
        from (select inst.loan_number,
                     inst.installment_number,
                     inst.original_due_date,
                     inst.days_in_default,
                     inst.principal,
                     inst.interest,
                     inst.principal_not_paid,
                     inst.interest_not_paid,
                     inst.loan_due_date,
                     inst.debit_time
                from (select inst.*,
                             max(inst.original_due_date) over(partition by inst.loan_number) as loan_due_date
                        from installment_pboc inst
                       where rpt_month = l_rpt_month) inst
                left join (select *
                            from bi_dm.dm_loan
                           where is_instal_clar = 1) clrl
                  on inst.loan_number = clrl.loan_number
               where (clrl.loan_number is null --未结清
                     or inst.original_due_date < clrl.last_repmnt_dt)
                 and trunc(inst.original_due_date, 'MM') =
                     to_date(l_rpt_month, 'YYYYMM')) inst
        left join (select loan_number,
                          installment_number,
                          max(nvl(complete_time, account_time)) as debit_time,
                          sum(principal) as principal_paid,
                          sum(interest) as interest_paid
                     from bi_dm.dm_debiting
                   /*where trunc(nvl(complete_time, account_time), 'MM') <=
                   to_date(l_rpt_month, 'YYYYMM')*/
                    group by loan_number, installment_number) debit
          on inst.loan_number = debit.loan_number
         and inst.installment_number = debit.installment_number
       group by inst.loan_number, inst.loan_due_date;
  
    l_row_cnt := sql%rowcount;
    commit;
  
    l_log_info := 'clear partition of pboc_xyd_scope';
    l_stat_id  := 1;
    log_p(l_log_id, l_sp_name, l_stat_id, l_row_cnt, l_log_info, l_sql_txt);
  
    select count(1)
      into l_pcnt
      from dba_objects
     where object_name = 'PBOC_XYD_SCOPE'
       and object_type = 'TABLE PARTITION'
       and subobject_name = 'P_' || l_rpt_month;
  
    if l_pcnt = 1 then
      execute immediate 'alter table pboc_xyd_scope truncate partition p_' ||
                        l_rpt_month;
    else
      execute immediate 'alter table pboc_xyd_scope add partition p_' ||
                        l_rpt_month || ' values(''' || l_rpt_month || ''')';
    end if;
    l_row_cnt := sql%rowcount;
    commit;
  
    l_log_info := 'insert new loan info to pboc_xyd_scope';
    l_stat_id  := 1;
    log_p(l_log_id, l_sp_name, l_stat_id, l_row_cnt, l_log_info, l_sql_txt);
  
    insert into pboc_xyd_scope
      (loan_number,
       loan_type,
       schedule_repymnt_dt,
       rpt_month,
       adj_sche_date)
      select loan_number,
             'new' as loan_type,
             funding_success_date as schedule_repymnt_dt,
             l_rpt_month as rpt_month,
             funding_success_date as adj_sche_date
        from bi_dm.dm_loan
       where product_no != '1A'
         and trunc(funding_success_date, 'MM') =
             to_date(l_rpt_month, 'YYYYMM');
    l_row_cnt := sql%rowcount;
    commit;
  
    l_log_info := 'insert scheduled loan info to pboc_xyd_scope';
    l_stat_id  := 1;
    log_p(l_log_id, l_sp_name, l_stat_id, l_row_cnt, l_log_info, l_sql_txt);
  
    insert into pboc_xyd_scope
      (loan_number,
       loan_type,
       schedule_repymnt_dt,
       rpt_month,
       adj_sche_date)
      select loan_number,
             'scheduled' as loan_type,
             sche_date as schedule_repymnt_dt,
             l_rpt_month as rpt_month,
             adj_sche_date as adj_sche_date
        from installment_pboc_std
       where rpt_month = l_rpt_month
         and trunc(sche_date, 'MM') = to_date(l_rpt_month, 'YYYYMM');
    l_row_cnt := sql%rowcount;
    commit;
  
    l_log_info := 'insert clear loan info to pboc_xyd_scope';
    l_stat_id  := 1;
    log_p(l_log_id, l_sp_name, l_stat_id, l_row_cnt, l_log_info, l_sql_txt);
  
    insert into pboc_xyd_scope
      (loan_number,
       loan_type,
       schedule_repymnt_dt,
       rpt_month,
       adj_sche_date)
      select loan_number,
             'clear' as loan_type,
             last_repmnt_dt as schedule_repymnt_dt,
             l_rpt_month as rpt_month,
             last_repmnt_dt as adj_sche_date
        from bi_dm.dm_loan
       where product_no != '1A'
         and is_instal_clar = 1
         and trunc(last_repmnt_dt, 'MM') = to_date(l_rpt_month, 'YYYYMM');
    l_row_cnt := sql%rowcount;
    commit;
  
    l_log_info := 'insert adjust to clear loan info to pboc_xyd_scope';
    l_stat_id  := 1;
    log_p(l_log_id, l_sp_name, l_stat_id, l_row_cnt, l_log_info, l_sql_txt);
  
    insert into pboc_xyd_scope
      (loan_number,
       loan_type,
       schedule_repymnt_dt,
       rpt_month,
       adj_sche_date)
      select loan.loan_number,
             'adjust2clear' as loan_type,
             loan.last_repmnt_dt as schedule_repymnt_dt,
             l_rpt_month as rpt_month,
             loan.last_repmnt_dt as adj_sche_date
        from (select loan_number,
                     max(case
                           when principal_not_paid != 0 then
                            days_in_default + 1
                           else
                            0
                         end) as cur_due_days
                from bi_ods.alch_installments_his
               where status_dt =
                     to_char(last_day(to_date(l_rpt_month, 'YYYYMM')),
                             'YYYYMMDD')
                 and original_due_date <=
                     last_day(to_date(l_rpt_month, 'YYYYMM'))
               group by loan_number) inst
        join (select loan_number, last_repmnt_dt
                from bi_dm.dm_loan
               where product_no != '1A'
                 and is_instal_clar = 1
                 and trunc(last_repmnt_dt) between
                     last_day(to_date(l_rpt_month, 'YYYYMM')) + 1 and
                     last_day(to_date(l_rpt_month, 'YYYYMM')) + 10) loan
          on inst.loan_number = loan.loan_number
       where inst.cur_due_days > 0;
    l_row_cnt := sql%rowcount;
    commit;
  
    l_log_info := 'insert no scheduled loan info to pboc_xyd_scope';
    l_stat_id  := 1;
    log_p(l_log_id, l_sp_name, l_stat_id, l_row_cnt, l_log_info, l_sql_txt);
  
    insert into pboc_xyd_scope
      (loan_number,
       loan_type,
       schedule_repymnt_dt,
       rpt_month,
       adj_sche_date)
      select al.loan_number,
             'noschedule' as loan_type,
             last_day(to_date(l_rpt_month, 'YYYYMM')) as schedule_repymnt_dt,
             l_rpt_month as rpt_month,
             last_day(to_date(l_rpt_month, 'YYYYMM')) as adj_sche_date
        from (select loan_number
                from bi_dm.dm_loan
               where product_no != '1A'
                 and funding_success_date <=
                     last_day(to_date(l_rpt_month, 'YYYYMM'))
              minus
              select loan_number
                from bi_dm.dm_loan
               where product_no != '1A'
                 and is_instal_clar = 1
                 and last_repmnt_dt < to_date(l_rpt_month, 'YYYYMM')) al
        left join (select distinct loan_number
                     from pboc_xyd_scope
                    where rpt_month = l_rpt_month
                      and loan_type <> 'noschedule') sche
          on al.loan_number = sche.loan_number
       where sche.loan_number is null;
    l_row_cnt := sql%rowcount;
    commit;
  
    l_log_info := 'clear partition of pboc_xyd_scope_std';
    l_stat_id  := 1;
    log_p(l_log_id, l_sp_name, l_stat_id, l_row_cnt, l_log_info, l_sql_txt);
  
    select count(1)
      into l_pcnt
      from dba_objects
     where object_name = 'PBOC_XYD_SCOPE_STD'
       and object_type = 'TABLE PARTITION'
       and subobject_name = 'P_' || l_rpt_month;
  
    if l_pcnt = 1 then
      execute immediate 'alter table pboc_xyd_scope_std truncate partition p_' ||
                        l_rpt_month;
    else
      execute immediate 'alter table pboc_xyd_scope_std add partition p_' ||
                        l_rpt_month || ' values(''' || l_rpt_month || ''')';
    end if;
    l_row_cnt := sql%rowcount;
    commit;
  
    l_log_info := 'insert data to pboc_xyd_scope_std';
    l_stat_id  := 1;
    log_p(l_log_id, l_sp_name, l_stat_id, l_row_cnt, l_log_info, l_sql_txt);
  
    insert into pboc_xyd_scope_std
      (loan_number,
       loan_type,
       schedule_repymnt_dt,
       st_dt,
       rpt_month,
       adj_sche_date,
       st_adj_sche_date)
      with sche as
       ( --new clear
        select loan_number,
                loan_type,
                schedule_repymnt_dt,
                rpt_month,
                adj_sche_date
          from pboc_xyd_scope
         where rpt_month = l_rpt_month
           and loan_type in ('new', 'clear')
        union all
        --adjust2clear(noneed repayment)
        select ad.*
          from (select loan_number,
                       'noneedrepay' as loan_type,
                       last_day(to_date(l_rpt_month, 'YYYYMM')) as schedule_repymnt_dt,
                       rpt_month,
                       adj_sche_date
                  from pboc_xyd_scope
                 where rpt_month = l_rpt_month
                   and loan_type in ('adjust2clear')) ad
          left join (select loan_number,
                            loan_type,
                            schedule_repymnt_dt,
                            rpt_month,
                            adj_sche_date
                       from pboc_xyd_scope
                      where rpt_month = l_rpt_month
                        and loan_type in ('new', 'clear')) nc
            on ad.loan_number = nc.loan_number
         where nc.loan_number is null
        union all
        --scheduled
        select sche.*
          from (select loan_number,
                       loan_type,
                       schedule_repymnt_dt,
                       rpt_month,
                       adj_sche_date
                  from pboc_xyd_scope
                 where rpt_month = l_rpt_month
                   and loan_type in ('scheduled')) sche
          left join (select *
                       from pboc_xyd_scope
                      where rpt_month = l_rpt_month
                        and loan_type in ('adjust2clear')) sdjclr
            on sche.loan_number = sdjclr.loan_number
          left join (select *
                       from pboc_xyd_scope
                      where rpt_month = l_rpt_month
                        and loan_type in ('new', 'clear')) nc
            on sche.loan_number = nc.loan_number
         where sdjclr.loan_number is null
           and nc.loan_number is null
        union all
        select ns.*
          from (select loan_number,
                       'noneedrepay' as loan_type,
                       schedule_repymnt_dt,
                       rpt_month,
                       adj_sche_date
                  from pboc_xyd_scope
                 where rpt_month = l_rpt_month
                   and loan_type in ('noschedule')) ns
          left join (select *
                       from pboc_xyd_scope
                      where rpt_month = l_rpt_month
                        and loan_type in ('new', 'clear')) nc
            on ns.loan_number = nc.loan_number
          left join (select loan_number,
                            'noneedrepay' as loan_type,
                            last_day(to_date(l_rpt_month, 'YYYYMM')) as schedule_repymnt_dt,
                            rpt_month
                       from pboc_xyd_scope
                      where rpt_month = l_rpt_month
                        and loan_type in ('adjust2clear')) adjclr
            on ns.loan_number = adjclr.loan_number
         where nc.loan_number is null
           and adjclr.loan_number is null),
      scheold as
       ( --new clear
        select loan_number,
                loan_type,
                schedule_repymnt_dt,
                rpt_month,
                adj_sche_date
          from pboc_xyd_scope
         where rpt_month = l_last_rpt_month
           and loan_type in ('new', 'clear')
        union all
        --adjust2clear(noneed repayment)
        select ad.*
          from (select loan_number,
                       'noneedrepay' as loan_type,
                       last_day(to_date(l_last_rpt_month, 'YYYYMM')) as schedule_repymnt_dt,
                       rpt_month,
                       adj_sche_date
                  from pboc_xyd_scope
                 where rpt_month = l_last_rpt_month
                   and loan_type in ('adjust2clear')) ad
          left join (select *
                       from pboc_xyd_scope
                      where rpt_month = l_last_rpt_month
                        and loan_type in ('new', 'clear')) nc
            on ad.loan_number = nc.loan_number
         where nc.loan_number is null
        union all
        --scheduled
        select sche.*
          from (select loan_number,
                       loan_type,
                       schedule_repymnt_dt,
                       rpt_month,
                       adj_sche_date
                  from pboc_xyd_scope
                 where rpt_month = l_last_rpt_month
                   and loan_type in ('scheduled')) sche
          left join (select *
                       from pboc_xyd_scope
                      where rpt_month = l_last_rpt_month
                        and loan_type in ('adjust2clear')) sdjclr
            on sche.loan_number = sdjclr.loan_number
          left join (select *
                       from pboc_xyd_scope
                      where rpt_month = l_last_rpt_month
                        and loan_type in ('new', 'clear')) nc
            on sche.loan_number = nc.loan_number
         where sdjclr.loan_number is null
           and nc.loan_number is null
        union all
        select ns.*
          from (select loan_number,
                       'noneedrepay' as loan_type,
                       schedule_repymnt_dt,
                       rpt_month,
                       adj_sche_date
                  from pboc_xyd_scope
                 where rpt_month = l_last_rpt_month
                   and loan_type in ('noschedule')) ns
          left join (select *
                       from pboc_xyd_scope
                      where rpt_month = l_last_rpt_month
                        and loan_type in ('new', 'clear')) nc
            on ns.loan_number = nc.loan_number
          left join (select loan_number,
                            'noneedrepay' as loan_type,
                            last_day(to_date(l_last_rpt_month, 'YYYYMM')) as schedule_repymnt_dt,
                            rpt_month
                       from pboc_xyd_scope
                      where rpt_month = l_last_rpt_month
                        and loan_type in ('adjust2clear')) adjclr
            on ns.loan_number = adjclr.loan_number
         where nc.loan_number is null
           and adjclr.loan_number is null),
      usche as
       (select t.*,
               row_number() over(partition by loan_number order by schedule_repymnt_dt desc) as odr
          from (select *
                  from sche
                union all
                select * from scheold) t)
      select loan_number,
             loan_type,
             schedule_repymnt_dt,
             st_dt,
             rpt_month,
             adj_sche_date,
             st_adj_sche_date
        from (select sche1.loan_number,
                     sche1.loan_type,
                     sche1.schedule_repymnt_dt,
                     nvl(sche2.schedule_repymnt_dt,
                         to_date('200001', 'YYYYMM')) as st_dt,
                     sche1.adj_sche_date as adj_sche_date,
                     sche2.adj_sche_date as st_adj_sche_date
                from (select *
                        from usche
                       where odr = 1
                         and rpt_month = l_rpt_month) sche1
                left join (select * from usche where odr = 2) sche2
                  on sche1.loan_number = sche2.loan_number
              union all
              select sche2.loan_number,
                     sche2.loan_type,
                     sche2.schedule_repymnt_dt,
                     nvl(sche3.schedule_repymnt_dt,
                         to_date('200001', 'YYYYMM')) as st_dt,
                     sche2.adj_sche_date as adj_sche_date,
                     sche3.adj_sche_date as st_adj_sche_date
                from (select *
                        from usche
                       where odr = 2
                         and rpt_month = l_rpt_month) sche2
                left join (select * from usche where odr = 3) sche3
                  on sche2.loan_number = sche3.loan_number
              union all
              select sche3.loan_number,
                     sche3.loan_type,
                     sche3.schedule_repymnt_dt,
                     nvl(sche4.schedule_repymnt_dt,
                         to_date('200001', 'YYYYMM')) as st_dt,
                     sche3.adj_sche_date as adj_sche_date,
                     sche4.adj_sche_date as st_adj_sche_date
                from (select *
                        from usche
                       where odr = 3
                         and rpt_month = l_rpt_month) sche3
                left join (select * from usche where odr = 4) sche4
                  on sche3.loan_number = sche4.loan_number);
    l_row_cnt := sql%rowcount;
    commit;
  
    l_log_info := 'clear partition of pboc_xyd_data';
    l_stat_id  := 1;
    log_p(l_log_id, l_sp_name, l_stat_id, l_row_cnt, l_log_info, l_sql_txt);
  
    select count(1)
      into l_pcnt
      from dba_objects
     where object_name = 'PBOC_XYD_DATA'
       and object_type = 'TABLE PARTITION'
       and subobject_name = 'P_' || l_rpt_month;
  
    if l_pcnt = 1 then
      execute immediate 'alter table pboc_xyd_data truncate partition p_' ||
                        l_rpt_month;
    else
      execute immediate 'alter table pboc_xyd_data add partition p_' ||
                        l_rpt_month || ' values(''' || l_rpt_month || ''')';
    end if;
    l_row_cnt := sql%rowcount;
    commit;
  
    l_log_info := 'insert data to pboc_xyd_data';
    l_stat_id  := 1;
    log_p(l_log_id, l_sp_name, l_stat_id, l_row_cnt, l_log_info, l_sql_txt);
    insert into pboc_xyd_data
      (rec_length,
       data_type,
       organization_code,
       biz_type,
       biz_type_dtl,
       biz_number,
       biz_area,
       biz_start_dt,
       biz_end_dt,
       currency,
       credit_line,
       shared_credit_line,
       max_debit_amount,
       guarantee_type,
       repymnt_frequency,
       repymnt_months,
       rest_repymnt_months,
       schedule_repymnt_dt,
       last_repymnt_dt,
       schedule_repymnt_amt,
       repymnt_amt,
       balance,
       cur_pastdue_terms,
       cur_pastdue_amt,
       pastdue_amt3160,
       pastdue_amt6190,
       pastdue_amt91180,
       pastdue_amt181,
       accu_pastdue_terms,
       max_pastdue_terms,
       class5_status,
       account_status,
       status_24,
       balance180,
       is_new,
       name,
       certificate_type,
       certificate_number,
       reserve,
       biz_tm,
       product_no,
       rpt_month)
      select /*+ no_merge(loan) no_merge(inst) */
       null as rec_length, --账户记录长度 
       'A' as data_type, --A基础段信息
       '12341234123412' as organization_code, --金融机构代码
       '1' as biz_type, --业务种类 1贷款 2 信用卡
       '91' as biz_type_dtl, --业务种类细分91个人消费贷款
       scp.loan_number as biz_number, --业务号 loan_number
       nvl(loan.home_city_id, '500000') as biz_area, --业务发生地 需要编码
       to_char(loan.funding_success_date, 'YYYYMMDD') as biz_start_dt, --开户日期(存在下月开始起息的情况，换成放款成功日期)
       to_char(loan.last_due_date, 'YYYYMMDD') as biz_end_dt, --到期日期
       'CNY' as currency, --币种
       round(loan.loan_amount) as credit_line, --授信额度
       round(loan.loan_amount) as shared_credit_line, --共享授信额度
       round(loan.loan_amount) as max_debit_amount, --最大负债额度
       '4' as guarantee_type, --担保方式
       '03' as repymnt_frequency, --还款频率
       months_between(trunc(loan.last_due_date, 'MM'),
                      trunc(loan.first_due_date, 'MM')) + 1 as repymnt_months, --还款月数
       case
         when trunc(loan.last_due_date, 'MM') <
              to_date(l_rpt_month, 'YYYYMM') then
          0
         when to_date(l_rpt_month, 'YYYYMM') <
              trunc(loan.first_due_date, 'MM') then
          months_between(trunc(loan.last_due_date, 'MM'),
                         trunc(loan.first_due_date, 'MM')) + 1
         else
          months_between(trunc(loan.last_due_date, 'MM'),
                         to_date(l_rpt_month, 'YYYYMM')) + 1
       end as rest_repymnt_months, --剩余还款月数
       to_char(scp.schedule_repymnt_dt, 'YYYYMMDD') as schedule_repymnt_dt, --结算、应还款日期
       to_char(case
                 when scp.last_repymnt_dt is null then
                  loan.funding_success_date
                 else
                  scp.last_repymnt_dt
               end,
               'YYYYMMDD') as last_repymnt_dt, --最近一次实际还款日期(默认换成了放款成功时间)
       case
         when scp.schedule_repymnt_dt <= loan.last_due_date then
          inst.schedule_repymnt_amt
         else
          inst.still_not_paid_amt + scp.repymnt_amt
       end as schedule_repymnt_amt, --本月应还款金额
       scp.repymnt_amt as repymnt_amt, --本月实际还款金额
       inst.balance_p1 + scp.balance_p2 as balance, --余额
       inst.cur_pastdue_terms as cur_pastdue_terms, --当前逾期期数
       inst.cur_pastdue_amt as cur_pastdue_amt, --当前逾期总额
       inst.pastdue_amt3160 as pastdue_amt3160, --逾期31-60天未归还贷款本金
       inst.pastdue_amt6190 as pastdue_amt6190, --逾期61-90天未归还贷款本金
       inst.pastdue_amt91180 as pastdue_amt91180, --逾期91-180天未归还贷款本金
       inst.pastdue_amt181 as pastdue_amt181, --逾期180天以上未归还贷款本金
       null as accu_pastdue_terms, --累计逾期期数
       null as max_pastdue_terms, --最高逾期期数
       case
         when inst.cur_default between 0 and 10 then
          '1'
         when inst.cur_default between 11 and 30 then
          '2'
         when inst.cur_default between 31 and 90 then
          '3'
         when inst.cur_default between 91 and 180 then
          '4'
         when inst.cur_default >= 181 then
          '5'
         else
          '9'
       end as class5_status, --五级分类状态(1-10天已调整为正常)
       case
         when scp.loan_type = 'clear' then
          '3'
         when scp.loan_type in ('new', 'noneedrepay') then
          '1'
         when scp.loan_type = 'scheduled' and inst.cur_pastdue_terms = 0 then
          '1'
         when scp.loan_type = 'scheduled' and inst.cur_pastdue_terms > 0 then
          '2'
       end as account_status, --账户状态
       case
         when scp.loan_type = 'clear' then
          'C'
         when scp.loan_type = 'new' then
          'N'
         when scp.loan_type = 'noneedrepay' then
          '*'
         when scp.loan_type = 'scheduled' and inst.cur_default between 0 and 10 then
          'N'
         when scp.loan_type = 'scheduled' and inst.cur_default between 11 and 30 then
          '1'
         when scp.loan_type = 'scheduled' and inst.cur_default between 31 and 60 then
          '2'
         when scp.loan_type = 'scheduled' and inst.cur_default between 61 and 90 then
          '3'
         when scp.loan_type = 'scheduled' and inst.cur_default between 91 and 120 then
          '4'
         when scp.loan_type = 'scheduled' and inst.cur_default between 121 and 150 then
          '5'
         when scp.loan_type = 'scheduled' and inst.cur_default between 151 and 180 then
          '6'
         when scp.loan_type = 'scheduled' and inst.cur_default > 180 then
          '7'
       end as status_24, --24个月（账户）还款状态
       '0000000000' as balance180, --透支180天以上未付余额
       case
         when scp.loan_type = 'new' then
          '2'
         else
          '1'
       end as is_new, --账户拥有者信息提示（是新开户还是老账户）
       loan.name as name, --客户姓名
       '0' as certificate_type, --证件类型
       loan.national_id as certificate_number, --证件号码
       '                              ' as reserve, --预留字段
       sysdate as biz_tm, --数据抽取时间
       loan.product_no as product_no, --贷款产品编码
       l_rpt_month as rpt_month --上报月
        from (select scp.loan_number,
                     scp.loan_type,
                     scp.schedule_repymnt_dt,
                     scp.st_dt,
                     scp.adj_sche_date,
                     scp.st_adj_sche_date,
                     max(case
                           when nvl(debit.complete_time, debit.account_time) <=
                                scp.adj_sche_date then
                            nvl(debit.complete_time, debit.account_time)
                         end) as last_repymnt_dt,
                     sum(case
                           when nvl(debit.complete_time, debit.account_time) >
                                scp.st_adj_sche_date and
                                nvl(debit.complete_time, debit.account_time) <=
                                scp.adj_sche_date then
                            debit.principal + debit.interest
                           else
                            0
                         end) as repymnt_amt,
                     sum(case
                           when nvl(debit.complete_time, debit.account_time) >
                                scp.adj_sche_date and
                                nvl(debit.complete_time, debit.account_time) <=
                                last_day(to_date(l_rpt_month, 'YYYYMM')) + 10 then
                            debit.principal
                           else
                            0
                         end) as balance_p2 --调整后的宽限期到次月10号见的本金还款
                from (select *
                        from pboc_xyd_scope_std
                       where rpt_month = l_rpt_month) scp
                left join bi_dm.dm_debiting debit
                  on scp.loan_number = debit.loan_number
               group by scp.loan_number,
                        scp.loan_type,
                        scp.schedule_repymnt_dt,
                        scp.st_dt,
                        scp.adj_sche_date,
                        scp.st_adj_sche_date) scp
        join (select loan.loan_number,
                     cust.home_city_id,
                     loan.funding_success_date,
                     loan.first_due_date,
                     loan.last_due_date,
                     loan.loan_amount,
                     cust.name,
                     cust.national_id,
                     loan.product_no
                from (select * from bi_dm.dm_loan where product_no != '1A') loan
                join bi_dm.dm_cust cust
                  on loan.account_id = cust.account_id
                 and ((loan.product_no = '2A' and cust.product_no = '1A2A') or
                     loan.product_no = cust.product_no)) loan
          on scp.loan_number = loan.loan_number
        join (select scp.loan_number,
                     scp.schedule_repymnt_dt,
                     sum(case
                           when inst.original_due_date > scp.st_dt and
                                inst.original_due_date <= schedule_repymnt_dt then
                            inst.principal + inst.interest
                           else
                            0
                         end) as schedule_repymnt_amt, --本月应还款金额，没有到期的贷款使用此金额
                     sum(case
                           when inst.original_due_date <= scp.adj_sche_date then
                            inst.principal_not_paid + inst.interest_not_paid
                           else
                            0
                         end) as still_not_paid_amt, --截至次月10号的应还未还，如果贷款已到期就用此金额+当月已还作为当月应还
                     sum(inst.principal_not_paid) as balance_p1, --余额(次月10好的余额 + 调整后的宽限期到10号之见的已经本金)
                     sum(case
                           when inst.principal_not_paid > 0 and
                                inst.days_in_default > 10 then
                            1
                           when inst.original_due_date <= scp.schedule_repymnt_dt and
                                inst.principal_not_paid = 0 and
                                inst.debit_time > scp.adj_sche_date and
                                inst.days_in_default > 10 then
                            1
                           else
                            0
                         end) as cur_pastdue_terms, --当前逾期期数（次月10号的状态，少算了一些，宽限期到10号之间的还款会导致逾期期数减少）
                     sum(case
                           when inst.principal_not_paid > 0 and
                                inst.days_in_default > 10 then
                            inst.principal_not_paid + inst.interest_not_paid
                           when inst.original_due_date <= scp.schedule_repymnt_dt and
                                inst.principal_not_paid = 0 and
                                inst.debit_time > scp.adj_sche_date and
                                inst.days_in_default > 10 then
                            inst.principal + inst.interest
                           else
                            0
                         end) as cur_pastdue_amt, --当前逾期总额(次月10号的状态)
                     sum(case
                           when inst.principal_not_paid > 0 and
                                inst.days_in_default between 31 and 60 then
                            inst.principal_not_paid
                           else
                            0
                         end) as pastdue_amt3160, --逾期31-60天未归还贷款本金
                     sum(case
                           when inst.principal_not_paid > 0 and
                                inst.days_in_default between 61 and 90 then
                            inst.principal_not_paid
                           else
                            0
                         end) as pastdue_amt6190, --逾期61-90天未归还贷款本金
                     sum(case
                           when inst.principal_not_paid > 0 and
                                inst.days_in_default between 91 and 180 then
                            inst.principal_not_paid
                           else
                            0
                         end) as pastdue_amt91180, --逾期91-180天未归还贷款本金
                     sum(case
                           when inst.principal_not_paid > 0 and
                                inst.days_in_default > 180 then
                            inst.principal_not_paid
                           else
                            0
                         end) as pastdue_amt181, --逾期180天以上未归还贷款本金
                     max(case
                           when inst.principal_not_paid > 0 and
                                inst.days_in_default > 10 then
                            case
                              when inst.days_in_default + 1 -
                                   (last_day(to_date(l_rpt_month, 'YYYYMM')) + 10 -
                                   scp.adj_sche_date) <= 10 then
                               11
                              else
                               inst.days_in_default + 1 -
                               (last_day(to_date(l_rpt_month, 'YYYYMM')) + 10 -
                               scp.adj_sche_date)
                            end
                           when inst.principal_not_paid > 0 and
                                inst.days_in_default <= 10 then
                            9 --宽限期内结清逾期天数记为9
                           when inst.principal_not_paid = 0 and
                                inst.debit_time > scp.adj_sche_date then -- 应该修改为宽限期后有还款的条件
                            inst.days_in_default
                           else
                            0
                         end) as cur_default --次月10号的逾期天数+1(因为24：00才翻牌)-宽限期到10号的天数
                from (select *
                        from pboc_xyd_scope_std
                       where rpt_month = l_rpt_month) scp
                join (select inst.*,
                            max(original_due_date) over(partition by inst.loan_number) as loan_due_date
                       from installment_pboc inst
                      where inst.rpt_month = l_rpt_month) inst
                  on scp.loan_number = inst.loan_number
               group by scp.loan_number,
                        scp.schedule_repymnt_dt,
                        inst.loan_due_date,
                        scp.adj_sche_date) inst
          on scp.loan_number = inst.loan_number
         and scp.schedule_repymnt_dt = inst.schedule_repymnt_dt;
    l_row_cnt := sql%rowcount;
    commit;
  
    l_log_info := 'analyze table pboc_xyd_data compute statistics;';
    l_stat_id  := 1;
    log_p(l_log_id, l_sp_name, l_stat_id, l_row_cnt, l_log_info, l_sql_txt);
    execute immediate 'analyze table pboc_xyd_data compute statistics';
    l_row_cnt := sql%rowcount;
    commit;
  
    l_log_info := 'clear partition of pboc_xyd_stat24';
    l_stat_id  := 1;
    log_p(l_log_id, l_sp_name, l_stat_id, l_row_cnt, l_log_info, l_sql_txt);
  
    select count(1)
      into l_pcnt
      from dba_objects
     where object_name = 'PBOC_XYD_STAT24'
       and object_type = 'TABLE PARTITION'
       and subobject_name = 'P_' || l_rpt_month;
  
    if l_pcnt = 1 then
      execute immediate 'alter table pboc_xyd_stat24 truncate partition p_' ||
                        l_rpt_month;
    else
      execute immediate 'alter table pboc_xyd_stat24 add partition p_' ||
                        l_rpt_month || ' values(''' || l_rpt_month || ''')';
    end if;
    l_row_cnt := sql%rowcount;
    commit;
  
    l_log_info := 'insert data to pboc_xyd_stat24';
    l_stat_id  := 1;
    log_p(l_log_id, l_sp_name, l_stat_id, l_row_cnt, l_log_info, l_sql_txt);
    insert into pboc_xyd_stat24
      select l.biz_number,
             l_rpt_month as rpt_month,
             l.schedule_repymnt_dt,
             lpad(max(case
                        when st.rpt_month =
                             to_char(add_months(to_date(l_rpt_month, 'YYYYMM'), -23),
                                     'YYYYMM') then
                         st.status_24
                        when trunc(to_date(l.biz_start_dt, 'YYYYMMDD'), 'MM') <=
                             add_months(to_date(l_rpt_month, 'YYYYMM'), -23) then
                         '#'
                      end) || max(case
                                    when st.rpt_month =
                                         to_char(add_months(to_date(l_rpt_month, 'YYYYMM'), -22),
                                                 'YYYYMM') then
                                     st.status_24
                                    when trunc(to_date(l.biz_start_dt, 'YYYYMMDD'), 'MM') <=
                                         add_months(to_date(l_rpt_month, 'YYYYMM'), -22) then
                                     '#'
                                  end) || max(case
                                                when st.rpt_month =
                                                     to_char(add_months(to_date(l_rpt_month, 'YYYYMM'), -21),
                                                             'YYYYMM') then
                                                 st.status_24
                                                when trunc(to_date(l.biz_start_dt, 'YYYYMMDD'), 'MM') <=
                                                     add_months(to_date(l_rpt_month, 'YYYYMM'), -21) then
                                                 '#'
                                              end) ||
                  max(case
                        when st.rpt_month =
                             to_char(add_months(to_date(l_rpt_month, 'YYYYMM'), -20),
                                     'YYYYMM') then
                         st.status_24
                        when trunc(to_date(l.biz_start_dt, 'YYYYMMDD'), 'MM') <=
                             add_months(to_date(l_rpt_month, 'YYYYMM'), -20) then
                         '#'
                      end) || max(case
                                    when st.rpt_month =
                                         to_char(add_months(to_date(l_rpt_month, 'YYYYMM'), -19),
                                                 'YYYYMM') then
                                     st.status_24
                                    when trunc(to_date(l.biz_start_dt, 'YYYYMMDD'), 'MM') <=
                                         add_months(to_date(l_rpt_month, 'YYYYMM'), -19) then
                                     '#'
                                  end) || max(case
                                                when st.rpt_month =
                                                     to_char(add_months(to_date(l_rpt_month, 'YYYYMM'), -18),
                                                             'YYYYMM') then
                                                 st.status_24
                                                when trunc(to_date(l.biz_start_dt, 'YYYYMMDD'), 'MM') <=
                                                     add_months(to_date(l_rpt_month, 'YYYYMM'), -18) then
                                                 '#'
                                              end) ||
                  max(case
                        when st.rpt_month =
                             to_char(add_months(to_date(l_rpt_month, 'YYYYMM'), -17),
                                     'YYYYMM') then
                         st.status_24
                        when trunc(to_date(l.biz_start_dt, 'YYYYMMDD'), 'MM') <=
                             add_months(to_date(l_rpt_month, 'YYYYMM'), -17) then
                         '#'
                      end) || max(case
                                    when st.rpt_month =
                                         to_char(add_months(to_date(l_rpt_month, 'YYYYMM'), -16),
                                                 'YYYYMM') then
                                     st.status_24
                                    when trunc(to_date(l.biz_start_dt, 'YYYYMMDD'), 'MM') <=
                                         add_months(to_date(l_rpt_month, 'YYYYMM'), -16) then
                                     '#'
                                  end) || max(case
                                                when st.rpt_month =
                                                     to_char(add_months(to_date(l_rpt_month, 'YYYYMM'), -15),
                                                             'YYYYMM') then
                                                 st.status_24
                                                when trunc(to_date(l.biz_start_dt, 'YYYYMMDD'), 'MM') <=
                                                     add_months(to_date(l_rpt_month, 'YYYYMM'), -15) then
                                                 '#'
                                              end) ||
                  max(case
                        when st.rpt_month =
                             to_char(add_months(to_date(l_rpt_month, 'YYYYMM'), -14),
                                     'YYYYMM') then
                         st.status_24
                        when trunc(to_date(l.biz_start_dt, 'YYYYMMDD'), 'MM') <=
                             add_months(to_date(l_rpt_month, 'YYYYMM'), -14) then
                         '#'
                      end) || max(case
                                    when st.rpt_month =
                                         to_char(add_months(to_date(l_rpt_month, 'YYYYMM'), -13),
                                                 'YYYYMM') then
                                     st.status_24
                                    when trunc(to_date(l.biz_start_dt, 'YYYYMMDD'), 'MM') <=
                                         add_months(to_date(l_rpt_month, 'YYYYMM'), -13) then
                                     '#'
                                  end) || max(case
                                                when st.rpt_month =
                                                     to_char(add_months(to_date(l_rpt_month, 'YYYYMM'), -12),
                                                             'YYYYMM') then
                                                 st.status_24
                                                when trunc(to_date(l.biz_start_dt, 'YYYYMMDD'), 'MM') <=
                                                     add_months(to_date(l_rpt_month, 'YYYYMM'), -12) then
                                                 '#'
                                              end) ||
                  max(case
                        when st.rpt_month =
                             to_char(add_months(to_date(l_rpt_month, 'YYYYMM'), -11),
                                     'YYYYMM') then
                         st.status_24
                        when trunc(to_date(l.biz_start_dt, 'YYYYMMDD'), 'MM') <=
                             add_months(to_date(l_rpt_month, 'YYYYMM'), -11) then
                         '#'
                      end) || max(case
                                    when st.rpt_month =
                                         to_char(add_months(to_date(l_rpt_month, 'YYYYMM'), -10),
                                                 'YYYYMM') then
                                     st.status_24
                                    when trunc(to_date(l.biz_start_dt, 'YYYYMMDD'), 'MM') <=
                                         add_months(to_date(l_rpt_month, 'YYYYMM'), -10) then
                                     '#'
                                  end) || max(case
                                                when st.rpt_month =
                                                     to_char(add_months(to_date(l_rpt_month, 'YYYYMM'), -9),
                                                             'YYYYMM') then
                                                 st.status_24
                                                when trunc(to_date(l.biz_start_dt, 'YYYYMMDD'), 'MM') <=
                                                     add_months(to_date(l_rpt_month, 'YYYYMM'), -9) then
                                                 '#'
                                              end) ||
                  max(case
                        when st.rpt_month =
                             to_char(add_months(to_date(l_rpt_month, 'YYYYMM'), -8),
                                     'YYYYMM') then
                         st.status_24
                        when trunc(to_date(l.biz_start_dt, 'YYYYMMDD'), 'MM') <=
                             add_months(to_date(l_rpt_month, 'YYYYMM'), -8) then
                         '#'
                      end) || max(case
                                    when st.rpt_month =
                                         to_char(add_months(to_date(l_rpt_month, 'YYYYMM'), -7),
                                                 'YYYYMM') then
                                     st.status_24
                                    when trunc(to_date(l.biz_start_dt, 'YYYYMMDD'), 'MM') <=
                                         add_months(to_date(l_rpt_month, 'YYYYMM'), -7) then
                                     '#'
                                  end) || max(case
                                                when st.rpt_month =
                                                     to_char(add_months(to_date(l_rpt_month, 'YYYYMM'), -6),
                                                             'YYYYMM') then
                                                 st.status_24
                                                when trunc(to_date(l.biz_start_dt, 'YYYYMMDD'), 'MM') <=
                                                     add_months(to_date(l_rpt_month, 'YYYYMM'), -6) then
                                                 '#'
                                              end) ||
                  max(case
                        when st.rpt_month =
                             to_char(add_months(to_date(l_rpt_month, 'YYYYMM'), -5),
                                     'YYYYMM') then
                         st.status_24
                        when trunc(to_date(l.biz_start_dt, 'YYYYMMDD'), 'MM') <=
                             add_months(to_date(l_rpt_month, 'YYYYMM'), -5) then
                         '#'
                      end) || max(case
                                    when st.rpt_month =
                                         to_char(add_months(to_date(l_rpt_month, 'YYYYMM'), -4),
                                                 'YYYYMM') then
                                     st.status_24
                                    when trunc(to_date(l.biz_start_dt, 'YYYYMMDD'), 'MM') <=
                                         add_months(to_date(l_rpt_month, 'YYYYMM'), -4) then
                                     '#'
                                  end) || max(case
                                                when st.rpt_month =
                                                     to_char(add_months(to_date(l_rpt_month, 'YYYYMM'), -3),
                                                             'YYYYMM') then
                                                 st.status_24
                                                when trunc(to_date(l.biz_start_dt, 'YYYYMMDD'), 'MM') <=
                                                     add_months(to_date(l_rpt_month, 'YYYYMM'), -3) then
                                                 '#'
                                              end) ||
                  max(case
                        when st.rpt_month =
                             to_char(add_months(to_date(l_rpt_month, 'YYYYMM'), -2),
                                     'YYYYMM') then
                         st.status_24
                        when trunc(to_date(l.biz_start_dt, 'YYYYMMDD'), 'MM') <=
                             add_months(to_date(l_rpt_month, 'YYYYMM'), -2) then
                         '#'
                      end) || max(case
                                    when st.rpt_month =
                                         to_char(add_months(to_date(l_rpt_month, 'YYYYMM'), -1),
                                                 'YYYYMM') then
                                     st.status_24
                                    when trunc(to_date(l.biz_start_dt, 'YYYYMMDD'), 'MM') <=
                                         add_months(to_date(l_rpt_month, 'YYYYMM'), -1) then
                                     '#'
                                  end) || l.status_24,
                  24,
                  '/') as status_24,
             l.account_status
        from (select t.* from pboc_xyd_data t where rpt_month = l_rpt_month) l
        left join (select *
                     from (select t.*,
                                  row_number() over(partition by rpt_month, biz_number order by schedule_repymnt_dt desc, account_status desc) as odr
                             from (select *
                                     from pboc_xyd_data
                                    where rpt_month < l_rpt_month) t)
                    where odr = 1) st
          on l.biz_number = st.biz_number
       group by l.biz_number,
                l.schedule_repymnt_dt,
                l.status_24,
                l.account_status;
  
    l_row_cnt := sql%rowcount;
    commit;
  
    l_log_info := 'clear partition of pboc_xyd_data_std';
    l_stat_id  := 1;
    log_p(l_log_id, l_sp_name, l_stat_id, l_row_cnt, l_log_info, l_sql_txt);
  
    select count(1)
      into l_pcnt
      from dba_objects
     where object_name = 'PBOC_XYD_DATA_STD'
       and object_type = 'TABLE PARTITION'
       and subobject_name = 'P_' || l_rpt_month;
  
    if l_pcnt = 1 then
      execute immediate 'alter table pboc_xyd_data_std truncate partition p_' ||
                        l_rpt_month;
    else
      execute immediate 'alter table pboc_xyd_data_std add partition p_' ||
                        l_rpt_month || ' values(''' || l_rpt_month || ''')';
    end if;
    l_row_cnt := sql%rowcount;
    commit;
  
    l_log_info := 'insert data to pboc_xyd_data_std';
    l_stat_id  := 1;
    log_p(l_log_id, l_sp_name, l_stat_id, l_row_cnt, l_log_info, l_sql_txt);
    insert into pboc_xyd_data_std
      select dat.rec_length,
             dat.data_type,
             dat.organization_code,
             dat.biz_type,
             dat.biz_type_dtl,
             gen_str(dat.biz_number, 40) as biz_number,
             dat.biz_area,
             dat.biz_start_dt,
             dat.biz_end_dt,
             dat.currency,
             gen_int(round(dat.credit_line), 10) as credit_line,
             gen_int(round(dat.shared_credit_line), 10) as shared_credit_line,
             gen_int(round(dat.max_debit_amount), 10) as max_debit_amount,
             dat.guarantee_type,
             dat.repymnt_frequency,
             gen_int(dat.repymnt_months, 3) as repymnt_months,
             gen_int(dat.rest_repymnt_months, 3) as rest_repymnt_months,
             dat.schedule_repymnt_dt,
             dat.last_repymnt_dt,
             gen_int(round(dat.schedule_repymnt_amt), 10) as schedule_repymnt_amt,
             gen_int(round(dat.repymnt_amt), 10) as repymnt_amt,
             gen_int(round(dat.balance), 10) as balance,
             gen_int(dat.cur_pastdue_terms, 2) as cur_pastdue_terms,
             gen_int(round(dat.cur_pastdue_amt), 10) as cur_pastdue_amt,
             gen_int(round(dat.pastdue_amt3160), 10) as pastdue_amt3160,
             gen_int(round(dat.pastdue_amt6190), 10) as pastdue_amt6190,
             gen_int(round(dat.pastdue_amt91180), 10) as pastdue_amt91180,
             gen_int(round(dat.pastdue_amt181), 10) as pastdue_amt181,
             gen_int(pdt.accu_pastdue_terms, 3) as accu_pastdue_terms,
             gen_int(pdt.max_pastdue_terms, 2) as max_pastdue_terms,
             dat.class5_status,
             dat.account_status,
             st.status_24,
             dat.balance180,
             dat.is_new,
             gen_str(replace(dat.name, '·', '.'), 30) as name,
             dat.certificate_type,
             gen_str(dat.certificate_number, 18) as certificate_number,
             dat.reserve,
             dat.biz_tm,
             dat.product_no,
             l_rpt_month as rpt_month
        from (select * from pboc_xyd_data where rpt_month = l_rpt_month) dat
        join (select biz_number,
                     schedule_repymnt_dt,
                     cur_pastdue_terms,
                     account_status,
                     sum(cur_pastdue_terms) over(partition by biz_number order by schedule_repymnt_dt) as accu_pastdue_terms,
                     max(cur_pastdue_terms) over(partition by biz_number order by schedule_repymnt_dt) as max_pastdue_terms
                from pboc_xyd_data
               where rpt_month <= l_rpt_month) pdt
          on dat.biz_number = pdt.biz_number
         and dat.schedule_repymnt_dt = pdt.schedule_repymnt_dt
         and dat.account_status = pdt.account_status
        join (select * from pboc_xyd_stat24 where rpt_month = l_rpt_month) st
          on dat.biz_number = st.biz_number
         and dat.schedule_repymnt_dt = st.schedule_repymnt_dt
         and dat.account_status = st.account_status;
    l_row_cnt := sql%rowcount;
    commit;
  
    l_log_info := 'clear partition of pboc_xyd_identity_std';
    l_stat_id  := 1;
    log_p(l_log_id, l_sp_name, l_stat_id, l_row_cnt, l_log_info, l_sql_txt);
  
    select count(1)
      into l_pcnt
      from dba_objects
     where object_name = 'PBOC_XYD_IDENTITY_STD'
       and object_type = 'TABLE PARTITION'
       and subobject_name = 'P_' || l_rpt_month;
  
    if l_pcnt = 1 then
      execute immediate 'alter table pboc_xyd_identity_std truncate partition p_' ||
                        l_rpt_month;
    else
      execute immediate 'alter table pboc_xyd_identity_std add partition p_' ||
                        l_rpt_month || ' values(''' || l_rpt_month || ''')';
    end if;
    l_row_cnt := sql%rowcount;
    commit;
  
    l_log_info := 'insert data to pboc_xyd_identity_std';
    l_stat_id  := 1;
    log_p(l_log_id, l_sp_name, l_stat_id, l_row_cnt, l_log_info, l_sql_txt);
    insert into pboc_xyd_identity_std
      select base.biz_number as biz_number,
             'B' as data_type,
             nvl(cust.gender_code, '0') as gender,
             nvl(to_char(cust.birth_date, 'YYYYMMDD'), '19010101') as birthday,
             nvl(cust.marital_code, '90') as marital_status,
             gen_int(nvl(cust.education_code, '99'), 2) as highest_education,
             nvl(cust.degree_code, '9') as highest_degree,
             gen_str(cust.home_phone, 25) as residence_telephone,
             gen_int(cust.primary_phone, 16) as cell_phone,
             gen_str(regexp_replace(cust.company_phone, '[^0-9]+', ''), 25) as work_telephone,
             gen_str(cust.email, 30) as email,
             gen_str(cust.home_province_name || cust.home_city_name ||
                     cust.home_district_name,
                     60) as postal_address,
             '999999' as postal_code,
             gen_str(cust.home_province_name || cust.home_city_name ||
                     cust.home_district_name,
                     60) as home_address,
             gen_str('', 30) as spouse_name,
             'X' as spouse_certificate_type,
             gen_str('', 18) as spouse_certificate_number,
             gen_str('', 60) as spouse_company,
             gen_str('', 25) as spouse_phone,
             sysdate as biz_tm,
             l_rpt_month as rpt_month
        from bi_dm.dm_cust cust
        join bi_dm.dm_loan loan
          on cust.account_id = loan.account_id
         and ((cust.product_no = '1A2A' and loan.product_no = '2A') or
             cust.product_no = loan.product_no)
        join (select *
                from pboc_xyd_data
               where is_new = '2'
                 and rpt_month = l_rpt_month) base
          on loan.loan_number = base.biz_number;
    l_row_cnt := sql%rowcount;
    commit;
  
    l_log_info := 'clear partition of pboc_xyd_job_std';
    l_stat_id  := 1;
    log_p(l_log_id, l_sp_name, l_stat_id, l_row_cnt, l_log_info, l_sql_txt);
  
    select count(1)
      into l_pcnt
      from dba_objects
     where object_name = 'PBOC_XYD_JOB_STD'
       and object_type = 'TABLE PARTITION'
       and subobject_name = 'P_' || l_rpt_month;
  
    if l_pcnt = 1 then
      execute immediate 'alter table pboc_xyd_job_std truncate partition p_' ||
                        l_rpt_month;
    else
      execute immediate 'alter table pboc_xyd_job_std add partition p_' ||
                        l_rpt_month || ' values(''' || l_rpt_month || ''')';
    end if;
    l_row_cnt := sql%rowcount;
    commit;
  
    l_log_info := 'insert data to pboc_xyd_job_std';
    l_stat_id  := 1;
    log_p(l_log_id, l_sp_name, l_stat_id, l_row_cnt, l_log_info, l_sql_txt);
    insert into pboc_xyd_job_std
      select base.biz_number as biz_number,
             'C' as data_type,
             nvl(cust.occupation_code, 'Z') as zhiye,
             gen_str(substr(nvl(trim(cust.company_name), '暂缺'), 1, 30),
                     60) as company,
             nvl(cust.company_industry_code, 'Z') as industry,
             gen_str(cust.company_province_name || cust.company_city_name ||
                     cust.company_district_name,
                     60) as company_address,
             '999999' as company_postal_code,
             '0000' as start_year,
             case
               when cust.work_type = '1' then
                '1'
               when cust.work_type = '2' then
                '1'
               when cust.work_type = '3' then
                '2'
               when cust.work_type = '4' then
                '2'
               when cust.work_type = '5' then
                '3'
               when cust.work_type = '6' then
                '3'
               when cust.work_type = '7' then
                '3'
               when cust.work_type = '8' then
                '3'
               when cust.work_type = '9' then
                '4'
               when cust.work_type = '10' then
                '9'
               else
                '9'
             end as zhiwu,
             case
               when cust.work_type = '1' then
                '1'
               when cust.work_type = '2' then
                '1'
               when cust.work_type = '3' then
                '2'
               when cust.work_type = '4' then
                '2'
               when cust.work_type = '5' then
                '3'
               when cust.work_type = '6' then
                '3'
               when cust.work_type = '7' then
                '3'
               when cust.work_type = '8' then
                '3'
               when cust.work_type = '9' then
                '9'
               when cust.work_type = '10' then
                '9'
               else
                '0'
             end as zhicheng,
             gen_int(round(nvl(cust.income_cash, 0) +
                           nvl(cust.income_ddi, 0)) * 12,
                     10) as annual_income,
             gen_str(cust.bank_card_number, 40) as payroll_account,
             gen_int('', 14) as payroll_bank_code,
             sysdate as biz_tm,
             l_rpt_month as rpt_month
        from bi_dm.dm_cust cust
        join bi_dm.dm_loan loan
          on cust.account_id = loan.account_id
         and ((cust.product_no = '1A2A' and loan.product_no = '2A') or
             cust.product_no = loan.product_no)
        join (select *
                from pboc_xyd_data
               where is_new = '2'
                 and rpt_month = l_rpt_month) base
          on loan.loan_number = base.biz_number;
    l_row_cnt := sql%rowcount;
    commit;
  
    l_log_info := 'clear partition of pboc_xyd_reside_std';
    l_stat_id  := 1;
    log_p(l_log_id, l_sp_name, l_stat_id, l_row_cnt, l_log_info, l_sql_txt);
  
    select count(1)
      into l_pcnt
      from dba_objects
     where object_name = 'PBOC_XYD_RESIDE_STD'
       and object_type = 'TABLE PARTITION'
       and subobject_name = 'P_' || l_rpt_month;
  
    if l_pcnt = 1 then
      execute immediate 'alter table pboc_xyd_reside_std truncate partition p_' ||
                        l_rpt_month;
    else
      execute immediate 'alter table pboc_xyd_reside_std add partition p_' ||
                        l_rpt_month || ' values(''' || l_rpt_month || ''')';
    end if;
    l_row_cnt := sql%rowcount;
    commit;
  
    l_log_info := 'insert data to pboc_xyd_reside_std';
    l_stat_id  := 1;
    log_p(l_log_id, l_sp_name, l_stat_id, l_row_cnt, l_log_info, l_sql_txt);
    insert into pboc_xyd_reside_std
      select base.biz_number as biz_number,
             'D' as data_type,
             pkg_pboc_xyd.gen_str(nvl(trim(cust.home_province_name ||
                                           cust.home_city_name ||
                                           cust.home_district_name),
                                      '暂缺'),
                                  60) as reside_address,
             '999999' as reside_postal_code,
             nvl(cust.house_status_code, '9') as reside_status,
             sysdate as biz_tm,
             l_rpt_month as rpt_month
        from bi_dm.dm_cust cust
        join bi_dm.dm_loan loan
          on cust.account_id = loan.account_id
         and ((cust.product_no = '1A2A' and loan.product_no = '2A') or
             cust.product_no = loan.product_no)
        join (select *
                from pboc_xyd_data
               where is_new = '2'
                 and rpt_month = l_rpt_month) base
          on loan.loan_number = base.biz_number;
    l_row_cnt := sql%rowcount;
    commit;
  
    l_log_info := 'clear partition of pboc_xyd_spec_trsn_std';
    l_stat_id  := 1;
    log_p(l_log_id, l_sp_name, l_stat_id, l_row_cnt, l_log_info, l_sql_txt);
  
    select count(1)
      into l_pcnt
      from dba_objects
     where object_name = 'PBOC_XYD_SPEC_TRSN_STD'
       and object_type = 'TABLE PARTITION'
       and subobject_name = 'P_' || l_rpt_month;
  
    if l_pcnt = 1 then
      execute immediate 'alter table pboc_xyd_spec_trsn_std truncate partition p_' ||
                        l_rpt_month;
    else
      execute immediate 'alter table pboc_xyd_spec_trsn_std add partition p_' ||
                        l_rpt_month || ' values(''' || l_rpt_month || ''')';
    end if;
    l_row_cnt := sql%rowcount;
    commit;
  
    l_log_info := 'insert data to pboc_xyd_spec_trsn_std';
    l_stat_id  := 1;
    log_p(l_log_id, l_sp_name, l_stat_id, l_row_cnt, l_log_info, l_sql_txt);
    insert into pboc_xyd_spec_trsn_std
      select base.biz_number as biz_number,
             'G' as data_type,
             '4' as spec_trsn_type,
             to_char(debit.clearance_date, 'YYYYMMDD') as happen_date,
             '0   ' as month_cnt,
             gen_int(round(debit.principal_paid + debit.interest_paid), 10) as trsn_amount,
             gen_str('', 200) as trsn_dtl,
             sysdate as biz_tm,
             l_rpt_month as rpt_month
        from (select biz_number,
                     max(schedule_repymnt_dt) as schedule_repymnt_dt
                from pboc_xyd_data
               where rpt_month = l_rpt_month
               group by biz_number) base
        join (select loan_number as biz_number,
                     max(trunc(nvl(complete_time, account_time))) as clearance_date,
                     sum(principal) as principal_paid,
                     sum(interest) as interest_paid
                from bi_dm.dm_debiting debit
               where debit.installment_id is null
                 and trunc(nvl(complete_time, account_time), 'MM') =
                     to_date(l_rpt_month, 'YYYYMM')
                 and product_no <> '1A'
               group by loan_number) debit
          on base.biz_number = debit.biz_number;
    l_row_cnt := sql%rowcount;
    commit;
  
    --close log
    l_stat_id := 2;
    log_p(l_log_id, l_sp_name, l_stat_id, l_row_cnt, l_log_info, l_sql_txt);
  exception
    when others then
      rollback;
      l_stat_id  := 3;
      l_log_info := substr(sqlerrm, 1, 1000);
      log_p(l_log_id,
            l_sp_name,
            l_stat_id,
            l_row_cnt,
            l_log_info,
            l_sql_txt);
  end installment_format;

end pkg_pboc_xyd;
/
