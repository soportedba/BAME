CREATE OR REPLACE FUNCTION MTDT_LOG_REGISTRATION(v_TYPE varchar, v_id_log_update integer, v_sql varchar, v_PROCESS varchar, v_PARAMETERS varchar)
RETURNS INTEGER AS $$
DECLARE
V_SQL_log VARCHAR(32000);
V_ID_LOG INTEGER;
BEGIN
	if v_TYPE='I' THEN
		SELECT CONCAT('INSERT INTO MTDT_LOG (SQL, FEC_INI, PROCESS, PARAMETERS) VALUES (',
		CHR(39),REPLACE(V_SQL,CHR(39),'#'),CHR(39), 
		',clock_timestamp(),', 
		CHR(39),V_PROCESS,CHR(39),
		',',
		CHR(39),V_PARAMETERS,CHR(39),
		')') INTO V_SQL_LOG;
		EXECUTE V_SQL_LOG;
		SELECT CURRVAL('MTDT_LOG_id_log_seq') into V_ID_LOG;
	elsif v_TYPE='U' and v_id_log_update > 0 THEN
		v_id_log:=v_id_log_update;
		select concat('UPDATE MTDT_LOG SET FEC_FIN=clock_timestamp() WHERE ID_LOG=',V_ID_LOG) into v_sql_log;
		execute V_SQL_LOG;
	END IF;
	RETURN V_ID_LOG;
END;
$$ language plpgsql;