CREATE OR REPLACE FUNCTION MTDT_EXEC (VSQL IN VARCHAR DEFAULT '', VDBLINK IN VARCHAR DEFAULT 'est_dwh', VEXCEPT IN VARCHAR DEFAULT 'N') RETURNS VOID AS $$
DECLARE
	V_TMP varchar(1000);
	V_TMP_INT integer;
	V_ID_LOG integer;
BEGIN
	BEGIN
		SELECT dblink_disconnect(VDBLINK) into V_TMP;
	EXCEPTION
		WHEN OTHERS THEN NULL;
	END;
	-- When we want to control exception then will set VEXCEPT to Y, eoc, exception will propagate
	IF VEXCEPT='N' THEN 
		select dblink_connect_u(VDBLINK,'dbname=est_dwh user=est_dwh') into V_TMP;
		select * from dblink_send_query(VDBLINK,VSQL) into V_TMP_INT;
		select * from dblink_get_result(VDBLINK) as t1(a text) into V_TMP;
	ELSE
		BEGIN
			select dblink_connect_u(VDBLINK,'dbname=est_dwh user=est_dwh') into V_TMP;
			select * from dblink_send_query(VDBLINK,VSQL) into V_TMP_INT;
			select * from dblink_get_result(VDBLINK) as t1(a text) into V_TMP;
		EXCEPTION
			WHEN foreign_key_violation THEN
				V_ID_LOG:=MTDT_LOG_REGISTRATION('I',0,VSQL,'foreign_key_violation','ERROR');
			WHEN unique_violation THEN
				V_ID_LOG:=MTDT_LOG_REGISTRATION('I',0,VSQL,'unique_violation','ERROR');
			WHEN OTHERS THEN NULL;
		END;
	END IF;
END;
$$ language plpgsql;
