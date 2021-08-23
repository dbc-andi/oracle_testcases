--prophylactic cleanup
drop table asc_stores;
drop table asc_sales; 

--create tables
create table asc_stores
as
select rownum store_id, -rownum store_id_2, 'STORE_' || rownum store_name
  from dual
 connect by level <= 10;

create table asc_sales
as
select rownum sales_id, s.store_id, -s.store_id store_id_2, round(dbms_random.value(1,10)) amount
  from asc_stores s
 cross join (select level id from dual connect by level <= 10);

--create pk on ASC_STORES (holds NDK statistic of STORE_ID, STORE_ID_2 combinations)  
create unique index asc_stores_pk on asc_stores(store_id, store_id_2);

--check statistics; NDK = NUM_ROWS = 10 -> OK
select distinct_keys, num_rows, last_analyzed 
  from user_ind_statistics 
 where index_name = 'ASC_STORES_PK';    

explain plan for  
select s.store_name
  from asc_sales f
  left join asc_stores s
    on (s.store_id = f.store_id and s.store_id_2 = f.store_id_2);
	
select *
  from table(dbms_xplan.display(format=>'BASIC +rows'));	

/*  
---------------------------------------------------------
| Id  | Operation                  | Name       | Rows  |
---------------------------------------------------------
|   0 | SELECT STATEMENT           |            |   100 |
|*  1 |  HASH JOIN OUTER           |            |   100 | --> perfectly accurate -> (10 * 100) * (1/10)
|   2 |   TABLE ACCESS STORAGE FULL| ASC_SALES  |   100 |
|   3 |   TABLE ACCESS STORAGE FULL| ASC_STORES |    10 |
---------------------------------------------------------
*/
  
    
merge /*+ enable_parallel_dml parallel(2) */into asc_stores a
using (select store_id, store_id_2, dbms_random.string('U', 5) store_name
         from asc_stores
        where rownum < 5
     ) b   
  on (    a.store_id = b.store_id 
      and a.store_id_2 = b.store_id_2)
when matched then
     update set a.store_name = b.store_name
when not matched then 
     insert (store_id, store_id_2, store_name)
     values (b.store_id, b.store_id_2, b.store_name); 

--4 rows merged (all updates, no inserts)
commit;

--NDK = 0; NUM_ROWS = 10 -> NOK
--NDK seems to reflect the number of rows updated in the insert branch of the merge
select distinct_keys, num_rows, last_analyzed from user_ind_statistics where index_name = 'ASC_STORES_PK'; 

--check exec plan again
explain plan for  
select s.store_name
  from asc_sales f
  left join asc_stores s
    on (s.store_id = f.store_id and s.store_id_2 = f.store_id_2);
	
select *
  from table(dbms_xplan.display(format=>'BASIC +rows'));	
    
/*
---------------------------------------------------------
| Id  | Operation                  | Name       | Rows  |
---------------------------------------------------------
|   0 | SELECT STATEMENT           |            |  1000 |
|   1 |  HASH JOIN OUTER           |            |  1000 | --> cartesian estimate -> (10 * 100) * (1/greatest(0,1))
|   2 |   TABLE ACCESS STORAGE FULL| ASC_SALES  |   100 |
|   3 |   TABLE ACCESS STORAGE FULL| ASC_STORES |    10 |
---------------------------------------------------------
*/   