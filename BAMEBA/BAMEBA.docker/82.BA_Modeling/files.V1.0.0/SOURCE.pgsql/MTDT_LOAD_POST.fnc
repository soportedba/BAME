CREATE OR REPLACE FUNCTION MTDT_LOAD_POST(vid_dimension_idd integer, V_TYPE varchar)
RETURNS INTEGER AS $$
DECLARE
v_count integer:=0; 
C_FK CURSOR
IS
select 'alter table f_activities drop constraint '||constraint_name||' ' REMOVE_FK from information_schema.constraint_table_usage where constraint_name like 'fk_%' and substr(table_name,1,4) in ('dim_');
C_PK CURSOR
IS
select 
	'alter table '||table_name||' drop constraint '||constraint_name||' ' remove_pk,
	'drop index dim_'||constraint_name||' ' remove_index
from 
	information_schema.constraint_table_usage 
where 
	constraint_name like '%_pk' and substr(table_name,1,4) in ('dim_');
C_DIM_IDD CURSOR (vid_dimension_idd integer)
  IS
  	SELECT 	UPPER(TAB_DIM1) AS TAB_DIM1, UPPER(TAB_DIM1_COL_IDD) AS TAB_DIM1_COL_IDD, UPPER(TAB_DIM1_COL_JOIN) AS TAB_DIM1_COL_JOIN, 
			UPPER(TAB_DIM2) AS TAB_DIM2, UPPER(TAB_DIM2_COL_IDD) AS TAB_DIM2_COL_IDD, UPPER(TAB_DIM2_COL_JOIN) AS TAB_DIM2_COL_JOIN, 
			UPPER(BYPASS) AS BYPASS
  	FROM
  		MTDT_DIMENSION_IDD where id_dimension_idd =vid_dimension_idd
  	ORDER BY ID_DIMENSION_IDD;
C_TABLA CURSOR
  IS
  	-- FOR ALL COLUMNS UNLESS IDD_ .. THAT MUST BE MANAGED BY THE PRE-POST OF THE CUBES
	select 	'update '||table_name||' set '||(case 
		when data_type in ('character','character varying','varchar') then column_name||'='||chr(39)||'N/A'||chr(39)
		when data_type in ('bigint','integer') then column_name||'=0'
		when data_type in ('boolean') then column_name||'='||'cast('||chr(39)||'f'||chr(39)||' as '||data_type||')' 
		when upper(data_type) in ('USER-DEFINED','TEXT') and column_name like 'geom%' then column_name||'='||chr(39)||'POINT(0 0)'||chr(39)
		when data_type in ('timestamp without time zone','timestamp with time zone','date') then column_name||'='||chr(39)||'2200-12-31'||chr(39)
		else null
		end)||' where '||column_name||' is null' as columna_zeros, table_name
	from 
		information_Schema.columns 
	where 
		UPPER(table_name) in (SELECT UPPER('DIM_'||name) FROM MTDT_DIMENSION WHERE type<>'D') and table_schema ='public' and upper(column_name) not like 'IDD_%'; 
C_DIM_IDD_INDEXES CURSOR 
  IS
  	SELECT DISTINCT UPPER(TAB_DIM1) AS TABLA
  	FROM
  		MTDT_DIMENSION_IDD;
BEGIN
SET CONSTRAINTS ALL DEFERRED;
	if V_TYPE='DIMENSION' THEN
		FOR REG_CUR IN C_DIM_IDD(vid_dimension_idd)
		LOOP
			-- SPECIAL CASE IN WHICH WE HAVE ONLY TO TAKE A FOLDED DATA IN ANOTHER TABLE Q DO JOIN WITH OUR
			IF REG_CUR.BYPASS='Y' THEN
				SELECT COUNT(*) INTO v_count FROM information_schema.columns WHERE UPPER(table_name)=REG_CUR.TAB_DIM1 AND UPPER(column_name)=REG_CUR.TAB_DIM1_COL_IDD; 
				IF v_count =0 THEN
					EXECUTE 'ALTER TABLE '||REG_CUR.TAB_DIM1||' ADD COLUMN '||REG_CUR.TAB_DIM1_COL_IDD||' INTEGER';
				END IF;
				EXECUTE 'DROP TABLE IF EXISTS '||REG_CUR.TAB_DIM1||'_TMP';
				EXECUTE 'CREATE TABLE '||REG_CUR.TAB_DIM1||'_TMP AS SELECT A.*, B.'||REG_CUR.TAB_DIM2_COL_IDD||' AS '||REG_CUR.TAB_DIM2_COL_IDD||'_1 
				FROM 	
					'||REG_CUR.TAB_DIM1||' A LEFT OUTER JOIN '||REG_CUR.TAB_DIM2||' B ON A.'||REG_CUR.TAB_DIM1_COL_JOIN||'=B.'||REG_CUR.TAB_DIM2_COL_JOIN||'';
				EXECUTE 'UPDATE '||REG_CUR.TAB_DIM1||'_TMP SET '||REG_CUR.TAB_DIM1_COL_IDD||'=COALESCE('||REG_CUR.TAB_DIM2_COL_IDD||'_1,0)';
				EXECUTE 'ALTER TABLE '||REG_CUR.TAB_DIM1||'_TMP DROP COLUMN '||REG_CUR.TAB_DIM2_COL_IDD||'_1';
				EXECUTE 'DROP TABLE '||REG_CUR.TAB_DIM1||' cascade';
				EXECUTE 'ALTER TABLE '||REG_CUR.TAB_DIM1||'_TMP RENAME TO '||REG_CUR.TAB_DIM1;
			-- SPECIAL CASE We register the bypass to P to indicate that it is a special type parent-child
			elsif REG_CUR.BYPASS='N' THEN
				SELECT COUNT(*) INTO v_count FROM information_schema.columns WHERE UPPER(table_name)=REG_CUR.TAB_DIM1 AND UPPER(column_name)=REG_CUR.TAB_DIM1_COL_IDD; 
				IF v_count =0 THEN
					EXECUTE 'ALTER TABLE '||REG_CUR.TAB_DIM1||' ADD COLUMN '||REG_CUR.TAB_DIM1_COL_IDD||' INTEGER';
				END IF;
				EXECUTE 'DROP TABLE IF EXISTS '||REG_CUR.TAB_DIM1||'_TMP';
				EXECUTE 'CREATE TABLE '||REG_CUR.TAB_DIM1||'_TMP AS SELECT A.*, B.'||REG_CUR.TAB_DIM2_COL_IDD||' AS '||REG_CUR.TAB_DIM2_COL_IDD||'_1 
				FROM 	
					'||REG_CUR.TAB_DIM1||' A LEFT OUTER JOIN '||REG_CUR.TAB_DIM2||' B ON A.'||REG_CUR.TAB_DIM1_COL_JOIN||'=B.'||REG_CUR.TAB_DIM2_COL_JOIN||' AND A.AUD_fEC BETWEEN B.AUD_FEC AND B.AUD_fEC_FIN -INTERVAL '||chr(39)||'1 MICROSECOND'||chr(39)||'';
				EXECUTE 'UPDATE '||REG_CUR.TAB_DIM1||'_TMP SET '||REG_CUR.TAB_DIM1_COL_IDD||'=COALESCE('||REG_CUR.TAB_DIM2_COL_IDD||'_1,0)';
				EXECUTE 'ALTER TABLE '||REG_CUR.TAB_DIM1||'_TMP DROP COLUMN '||REG_CUR.TAB_DIM2_COL_IDD||'_1';
				EXECUTE 'DROP TABLE '||REG_CUR.TAB_DIM1||' cascade';
				EXECUTE 'ALTER TABLE '||REG_CUR.TAB_DIM1||'_TMP RENAME TO '||REG_CUR.TAB_DIM1;
			END IF;
		END LOOP;
	elseif V_TYPE='NULLS' THEN
		FOR R IN C_TABLA
		LOOP
			-- WE PERFORM DIRECTLY THE SENTENCES
			EXECUTE 'LOCK TABLE '||R.table_name;
			EXECUTE R.columna_zeros;
		END LOOP;
	elseif V_TYPE='FKS_PKS' THEN
		FOR R IN C_FK
		LOOP
			-- WE PERFORM DIRECTLY THE SENTENCES OF DROPPING FKS
			EXECUTE R.REMOVE_FK;
		END LOOP;
		FOR R IN C_PK
		LOOP
			--WE PERFORM DIRECTLY THE SENTENCES OF DROPPING FKS
			EXECUTE R.remove_pk;
			BEGIN 
				EXECUTE R.remove_index;
			EXCEPTION 
				WHEN OTHERS THEN NULL;
			END;
		END LOOP;
	elseif V_TYPE='INDEXES' THEN
		FOR R IN C_DIM_IDD_INDEXES
		LOOP
			-- WE EXECUTE FOR THE RECREATION OF MODIFIED DIMENSIONS INDEXES
			perform * from MTDT_INDEXES(R.TABLA);
		END LOOP;
	END IF;
	RETURN v_count;
END;
$$ language plpgsql;