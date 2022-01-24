rem last tested on 19.12

rem #############################
rem # prepare tables            #
rem #############################
alter session set statistics_level = all;
drop table demo2;
drop table demo1;
create table demo1 
( id,
  service,
  pad,
  constraint demo1_pk primary key(id)
)
as
select rownum id, dbms_random.string('U', 5) service, lpad('*', 200, '*') pad from dual
connect by level <= 10000;

create table demo2
( id number,
  pad varchar2(200),
  constraint demo2_pk primary key(id),
  constraint demo2_demo_fk foreign key (id) references demo1(id) deferrable initially deferred
);

insert /*+ append */into demo2
select rownum id, lpad('*', 200, '*') pad from dual
connect by level <= 10;

commit;

rem #############################
rem # testcase                  #
rem #############################
--shows JE
select /*111*/count(*)
  from demo1 d1
  inner join demo2 d2
 on d2.id = d1.id;
 
select *
  from table(dbms_xplan.display_cursor(format=>'allstats last')); 

--shows JE 
select /*222*/count(*)
  from demo1 d1
  inner join demo2 d2
 on d2.id = d1.id;
 
select *
  from table(dbms_xplan.display_cursor(format=>'allstats last')); 

--shows JE 
select /*333*/count(*)
  from demo1 d1
  inner join demo2 d2
 on d2.id = d1.id;
 
select *
  from table(dbms_xplan.display_cursor(format=>'allstats last')); 

--still showing JE  
explain plan for
select count(*)
  from demo1 d1
  inner join demo2 d2
 on d2.id = d1.id;

select *
  from table(dbms_xplan.display(format=>'ALL -projection -alias')); 

--!!! JE no longer performed !!!  
select /*444*/count(*)
  from demo1 d1
  inner join demo2 d2
 on d2.id = d1.id;
 
select *
  from table(dbms_xplan.display_cursor(format=>'allstats last')); 

--!!! explain plan now also doesn't show JE anymore !!!    
explain plan for
select count(*)
  from demo1 d1
  inner join demo2 d2
 on d2.id = d1.id;
 
select *
  from table(dbms_xplan.display(format=>'ALL -projection -alias')); 
