create or replace procedure PRO_PSKU_GENERATE_DUMMY_IN_EAN(in_v_mkt_name in psku_mkt_hier_uprc.geo_name%type)
is
    ------------------------------------------------------------------------------------
  -- Procedure    : PRO_PSKU_GENERATE_DUMMY_IN_EAN                                   --
  -- Author       : Wang Zhong                                                --
  -- Date         : 2013-10-11                                                      --
  -- Purpose      : generate Dummy EAN for india market, and modification related 
  --                two stageing table psku_new_fpc_sdim and psku_new_ean_sdim respectively --
  -- Parameters   :                                                                 --
  --               - in_v_mkt_name - e.g 'India','Eastern Europe' and 'Arabian Peninsula'                              --
  ------------------------------------------------------------------------------------
  
  l_v_mkt_id VARCHAR2(20);
  l_v_sqlstr varchar2(1000);
  l_v_fpc_csku_count number;
    
begin
  
  select geo_id
    into l_v_mkt_id
    from psku_mkt_hier_uprc
   where geo_lvl_code = 'MKT'
     and geo_name = in_v_mkt_name;
     
  select count(*) 
  into l_v_fpc_csku_count
  from fpc_csku_temp;

if l_v_fpc_csku_count = 0 
/* if table fpc_csku_temp count=0 means there don't have any FPC->CSKU from business side.
   in other word, we cannot ensure what FPCs are scope of business from G11. 
   So, delete all EAN and FPC of India in stage table */
   then
delete from psku_new_fpc_sdim where mkt_id = l_v_mkt_id; -- delete India FPC in stage table
delete from psku_new_ean_sdim where mkt_id = l_v_mkt_id; -- delete India EAN in stage table
delete from psku_prod_hier_uprc -- delete new EAN of India in hierarchy main table
 where mkt_id = l_v_mkt_id
   and prod_lvl_code = 'EAN'
   and valid_ind = 'N'
   and trunc(creat_datetm) = trunc(sysdate);
commit;

  else
-- step 1:
l_v_sqlstr := 'truncate table psku_fpc_csku_linkage_india';
execute immediate l_v_sqlstr;
-- according to FPC->CSKU_name relationship from business side, generating FPC->CSKU_ID relationship.
insert into psku_fpc_csku_linkage_india
select a.fpc_id, b.orig_prod_id csku_id, a.csku_name, b.prod_id
  from fpc_csku_temp a, -- need load FPC->CSKU relationship from business side manually
       (select *
          from psku_prod_hier_uprc
         where mkt_id = l_v_mkt_id
           and prod_lvl_code = 'CSKU') b
 where b.prod_name = a.csku_name;
 
 
--- setp 2:
l_v_sqlstr := 'truncate table psku_csku_ean_fpc_india';
execute immediate l_v_sqlstr;
/* accroding to FPC->EAN linkage from G11 and FPC->CSKU linkage from business side, 
   generate FPC->EAN->CSKU relationship for India market */
insert into psku_csku_ean_fpc_india
select b.mkt_id,
       a.fpc_id,
       b.sales_org_code,
       b.dist_chanl_code,
       b.fpc_englh_desc,
       b.ean_id,
       a.csku_id csku_orig_id,
       a.prod_id csku_prod_id,
       b.prod_lfcyl_stage_code
  from psku_fpc_csku_linkage_india a,
       (select distinct mkt_id,
                        fpc_id,
                         t.sales_org_code,
                         t.dist_chanl_code,
                         t.prod_lfcyl_stage_code,
                         ean_id,
                         fpc_englh_desc
           from psku_new_fpc_sdim t -- G11's EAN->FPC linkage information would flow into this table
         where t.mkt_id = l_v_mkt_id) b
 where a.fpc_id = b.fpc_id
 order by b.ean_id;
 
 
-- step 3:

-- empty table psku_dummy_ean_request
l_v_sqlstr := 'truncate table psku_dummy_ean_request';
execute immediate l_v_sqlstr;
/* checking if these EAN have already existe in Echelon for certain market,if yes, that means 
   we should replace these exsiting EAN to dummy EAN in order to eliminate duplicate EANs */
insert into psku_dummy_ean_request
 select a.mkt_id,    
        a.fpc_id,
        a.sales_org_code,
        a.dist_chanl_code,
        a.prod_lfcyl_stage_code,
        a.ean_id real_ean_id,
        a.ean_id || a.fpc_id dummy_ean_id, -- combine EAN_ID and FPC_ID for getting unique EAN_ID
        a.csku_orig_id csku_orig_id,
        a.csku_prod_id csku_prod_id
   from psku_csku_ean_fpc_india a,
        (select * from psku_prod_hier_uprc 
          where mkt_id = l_v_mkt_id 
            and prod_lvl_code = 'EAN' 
            and valid_ind = 'Y') y
  where a.ean_id = y.orig_prod_id;
  

-- step 4:

-- finding one EAN related to multiple CSKU situation in the rest of New EAN scope
merge into psku_dummy_ean_request a
using (select /*distinct*/
                a.mkt_id,    
                a.fpc_id,
                a.sales_org_code,
                a.dist_chanl_code,
                a.prod_lfcyl_stage_code,
                a.ean_id real_ean_id,
                a.ean_id || a.fpc_id dummy_ean_id, -- combine EAN_ID and FPC_ID for getting unique EAN_ID
                a.csku_orig_id csku_orig_id,
                a.csku_prod_id csku_prod_id
          from psku_csku_ean_fpc_india a,
               (select ean_id, count(*) /* Finding one EAN_ID relate to multiple CSKU_ID situation,
                                        this sub table just for extracting all these EAN_IDs */
                  from  (select distinct ean_id,csku_orig_id from psku_csku_ean_fpc_india a
                          where not exists (select 1 
                                              from psku_prod_hier_uprc b
                                             where mkt_id = l_v_mkt_id 
                                               and prod_lvl_code = 'EAN' 
                                               and valid_ind = 'Y'
                                               and a.ean_id = b.orig_prod_id))
                 group by ean_id
                having count(*) > 1) x
         where a.ean_id = x.ean_id) b
    on (a.mkt_id = b.mkt_id
    and a.fpc_id = b.fpc_id
    and a.sales_org_code = b.sales_org_code
    and a.dist_chanl_code = b.dist_chanl_code
    and a.prod_lfcyl_stage_code = b.prod_lfcyl_stage_code
    and a.dummy_ean_id = b.dummy_ean_id)
 when not matched then
 insert (a.mkt_id,a.fpc_id,a.sales_org_code,a.dist_chanl_code,a.prod_lfcyl_stage_code,a.real_ean_id,a.dummy_ean_id,a.csku_orig_id,a.csku_prod_id)
 values (b.mkt_id,b.fpc_id,b.sales_org_code,b.dist_chanl_code,b.prod_lfcyl_stage_code,b.real_ean_id,b.dummy_ean_id,b.csku_orig_id,b.csku_prod_id);
 
 
--- step 5: 

--- delete EAN_ID which would be generated to dummy EAN in table psku_new_ean_sdim
delete from psku_new_ean_sdim -- minus 62 EAN which would be replaced by dummy EAN
 where mkt_id = l_v_mkt_id
   and ean_id in (
select real_ean_id from psku_dummy_ean_request
minus
select ean_id from psku_csku_ean_fpc_india a
 where not exists (select 1 from psku_dummy_ean_request b
                   where a.fpc_id = b.fpc_id
                     and a.sales_org_code = b.sales_org_code
                     and a.dist_chanl_code = b.dist_chanl_code
                     and a.prod_lfcyl_stage_code = b.prod_lfcyl_stage_code));
Dbms_Output.put_line('step 5: ' || sql%rowcount);


--- step 6: 

--- delete EAN_ID which would be generated to dummy EAN in table psku_prod_hier_uprc
delete from psku_prod_hier_uprc -- same as before
 where mkt_id = l_v_mkt_id
   and prod_lvl_code = 'EAN'
   and orig_prod_id in (
select real_ean_id from psku_dummy_ean_request
minus
select ean_id from psku_csku_ean_fpc_india a
 where not exists (select 1 from psku_dummy_ean_request b
                   where a.fpc_id = b.fpc_id
                     and a.sales_org_code = b.sales_org_code
                     and a.dist_chanl_code = b.dist_chanl_code
                     and a.prod_lfcyl_stage_code = b.prod_lfcyl_stage_code));
Dbms_Output.put_line('step 6: ' || sql%rowcount);


--- step 7:
                     
--- delete all EAN which are out of scope from business side
delete from psku_new_ean_sdim -- minus 3622 EAN which are not scope in business side
 where mkt_id = l_v_mkt_id
   and ean_id not in (select ean_id from psku_csku_ean_fpc_india);
Dbms_Output.put_line('step 7: ' || sql%rowcount);   


--- step 8:

--- delete all EAN which are out of scope from business side
delete from psku_prod_hier_uprc
 where mkt_id = l_v_mkt_id
   and prod_lvl_code = 'EAN'
   and valid_ind = 'N'
   and orig_prod_id not in (select ean_id from psku_csku_ean_fpc_india);
Dbms_Output.put_line('step 8: ' || sql%rowcount);


--- step 9:
                
--- delete all FPC which are out of scope from business side                  
delete from psku_new_fpc_sdim a -- minus 114342 FPC which are not scope of business side
 where mkt_id = l_v_mkt_id
   and not exists (select 1 from psku_csku_ean_fpc_india b
                where mkt_id = l_v_mkt_id
                  and a.fpc_id = b.fpc_id
                  and a.sales_org_code = b.sales_org_code
                  and a.dist_chanl_code = b.dist_chanl_code
                  and a.prod_lfcyl_stage_code = b.prod_lfcyl_stage_code);
Dbms_Output.put_line('step 9: ' || sql%rowcount);

                  
--- step 10:

/*
 put dummy EAN_ID into psku_new_ean_sdim
 Note: we should extend length of psku_new_ean_sdim.ean_id field to VARCHAR2(30 CHAR) from VARCHAR2(15 CHAR)
*/
insert into psku_new_ean_sdim -- adding 315 dummy EANs into EAN stage table
 select distinct dummy_ean_id,
                 mkt_id,
                 sysdate
   from psku_dummy_ean_request;
Dbms_Output.put_line('step 10: ' || sql%rowcount);


--- step 11:

-- put special dummy EAN information into psku_prod_hier_uprc
insert into psku_prod_hier_uprc -- adding 315 dummy EANs into main hierarchy table
SELECT psku_prod_id_seq.nextval   AS prod_id,
                     vw.orig_prod_id,
                     vw.parnt_id,
                     vw.mkt_id,
                     vw.prod_name,
                     vw.prod_dsply_name,
                     vw.prod_local_1_desc,
                     vw.prod_local_2_desc,
                     vw.prod_lvl_code,
                     vw.valid_ind,
                     vw.creat_datetm,
                     vw.creat_by_name,
                     vw.updt_datetm,
                     vw.updt_by_name,
                     vw.last_load_datetm,
                     vw.prod_attr_1_name,
                     vw.prod_attr_2_name,
                     vw.prod_attr_3_name  
    FROM (
          SELECT DISTINCT
                 dummy_ean_id               AS orig_prod_id,
                 csku_prod_id               AS parnt_id,
                 mkt_id,
                 dummy_ean_id               AS prod_name,
                 dummy_ean_id ||' ('||dummy_ean_id||')' AS prod_dsply_name,
                 NULL                       AS prod_local_1_desc,
                 NULL                       AS prod_local_2_desc,
                 'EAN'                      AS prod_lvl_code,
                 'Y'                        AS valid_ind,
                 sysdate                AS creat_datetm,
                 NULL                       AS creat_by_name,
                 sysdate                AS updt_datetm,
                 NULL                       AS updt_by_name,
                 sysdate                AS last_load_datetm,
                 NULL                       AS prod_attr_1_name,
                 NULL                       AS prod_attr_2_name,
                 NULL                       AS prod_attr_3_name  
          FROM psku_dummy_ean_request) vw;
Dbms_Output.put_line('step 11: ' || sql%rowcount);


--- step 12:

-- adding the rest of ean_id's related csku_prod_id        
merge into (select * from psku_prod_hier_uprc  
             where mkt_id = l_v_mkt_id
               and prod_lvl_code = 'EAN'
               and valid_ind = 'N') x
     using (select distinct ean_id, csku_prod_id
              from psku_csku_ean_fpc_india a
             where not exists (select 1 from psku_dummy_ean_request b
                                where a.fpc_id = b.fpc_id
                                  and a.sales_org_code = b.sales_org_code
                                  and a.dist_chanl_code = b.dist_chanl_code
                                  and a.prod_lfcyl_stage_code = b.prod_lfcyl_stage_code)) y
        on (x.orig_prod_id = y.ean_id)
when matched then
 update set x.parnt_id = y.csku_prod_id,
            x.valid_ind = 'Y';
         
            
--- step 13:
            
/*
replace the real ean with the dummy ean in table psku_new_fpc_sdim,
Note: we should extend length of psku_new_fpc_sdim.ean_id field to VARCHAR2(30 CHAR) from VARCHAR2(15 CHAR)
*/
merge into psku_new_fpc_sdim x
     using psku_dummy_ean_request y
        on (x.Mkt_Id = y.mkt_id
        and x.fpc_id = y.fpc_id
        and x.sales_org_code = y.sales_org_code
        and x.dist_chanl_code = y.dist_chanl_code
        and x.prod_lfcyl_stage_code = y.prod_lfcyl_stage_code)
 when matched then
 update set x.ean_id = y.dummy_ean_id;

 
--- step 14:

-- empty table fpc_csku_temp
l_v_sqlstr := 'truncate table fpc_csku_temp';
execute immediate l_v_sqlstr;
COMMIT;
end if;

  ------------------------------------------------------------------------------------
  -- STEP 100 log that procedure is finished
  ------------------------------------------------------------------------------------
  pro_chm_load_updt_log_plc(chm_log_id_seq.nextval, 'PSKU', 'COMPLETED OK',
                            'PRO_PSKU_GENERATE_DUMMY_IN_EAN', SYSDATE);


  EXCEPTION
  WHEN OTHERS THEN
    ------------------------------------------------------------------------------------
    -- STEP 100 log that procedure is finished with error
    ------------------------------------------------------------------------------------

    pro_chm_load_updt_log_plc(chm_log_id_seq.nextval, 'PSKU', 'FAILED',
                             'PRO_PSKU_GENERATE_DUMMY_IN_EAN'||CHR(13)||SQLERRM, SYSDATE);
  ROLLBACK;
  RAISE;
  
end PRO_PSKU_GENERATE_DUMMY_IN_EAN;
/
