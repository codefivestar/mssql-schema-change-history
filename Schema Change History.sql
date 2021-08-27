----------------------------------------------------------------------------------------------------------
-- Author      : Hidequel Puga
-- Date        : 2021-08-27
-- Description : SSMS Report for Schema Change History
----------------------------------------------------------------------------------------------------------

BEGIN TRY

	DECLARE @enable INT;

	 SELECT TOP 1 @enable = CONVERT(INT, value_in_use)
	   FROM sys.configurations
	  WHERE name = 'default trace enabled';

	IF @enable = 1
		BEGIN

			DECLARE @d1                 DATETIME;
			DECLARE @diff               INT;
			DECLARE @curr_tracefilename VARCHAR(500);
			DECLARE @base_tracefilename VARCHAR(500);
			DECLARE @indx               INT;
			DECLARE @temp_trace         TABLE ( obj_name         NVARCHAR(256)
											  , obj_id           INT
											  , database_name    NVARCHAR(256)
											  , start_time       DATETIME
											  , event_class      INT
											  , event_subclass   INT
											  , object_type      INT
											  , server_name      NVARCHAR(256)
											  , login_name       NVARCHAR(256)
											  , user_name        NVARCHAR(256)
											  , application_name NVARCHAR(256)
											  , ddl_operation    NVARCHAR(40)
				                              );
			DECLARE @path_separator CHAR(1);

			    SET @path_separator = ISNULL(CONVERT(CHAR(1), serverproperty('PathSeparator')), '\');

			 SELECT @curr_tracefilename = path
			   FROM sys.traces
			  WHERE is_default = 1;

			    SET @curr_tracefilename = REVERSE(@curr_tracefilename);

			 SELECT @indx = PATINDEX('%' + @path_separator + '%', @curr_tracefilename);

			    SET @curr_tracefilename = REVERSE(@curr_tracefilename);
			    SET @base_tracefilename = LEFT(@curr_tracefilename, LEN(@curr_tracefilename) - @indx) + @path_separator + 'log.trc';

			 INSERT INTO @temp_trace
			      SELECT ObjectName
					   , ObjectID
					   , DatabaseName
					   , StartTime
					   , EventClass
					   , EventSubClass
					   , ObjectType
					   , ServerName
					   , LoginName
					   , NTUserName
					   , ApplicationName
					   , 'temp'
			        FROM ::fn_trace_gettable(@base_tracefilename, DEFAULT)
			       WHERE EventClass    IN (46, 47, 164)
				     AND EventSubclass = 0
				     AND DatabaseID    = DB_ID();

			UPDATE @temp_trace
			   SET ddl_operation = 'CREATE'
			 WHERE event_class   = 46;

			UPDATE @temp_trace
			   SET ddl_operation = 'DROP'
			 WHERE event_class   = 47;

			UPDATE @temp_trace
			   SET ddl_operation = 'ALTER'
			 WHERE event_class   = 164;

			SELECT @d1 = MIN(start_time)
			  FROM @temp_trace;

			   SET @diff = DATEDIFF(hh, @d1, GETDATE())
			   SET @diff = @diff / 24;

			SELECT @diff AS difference
				 , @d1 AS DATE
				 , object_type AS obj_type_desc
				 , (
					DENSE_RANK() OVER (
						                ORDER BY obj_name
							          , object_type
						              )
					) % 2 AS l1
				 , (
					DENSE_RANK() OVER (
										ORDER BY obj_name
							          , object_type
							          , start_time
						              )
					) % 2 AS l2
				 , *
			  FROM @temp_trace
			 WHERE object_type NOT IN (21587) -- don''t bother with auto-statistics as it generates too much noise
		  ORDER BY start_time DESC;

		END
	ELSE
		BEGIN

			SELECT TOP 0 1 AS difference
				 , 1 AS DATE
				 , 1 AS obj_type_desc
				 , 1 AS l1
				 , 1 AS l2
				 , 1 AS obj_name
				 , 1 AS obj_id
				 , 1 AS database_name
				 , 1 AS start_time
				 , 1 AS event_class
				 , 1 AS event_subclass
				 , 1 AS object_type
				 , 1 AS server_name
				 , 1 AS login_name
				 , 1 AS user_name
				 , 1 AS application_name
				 , 1 AS ddl_operation;
		END
END TRY
BEGIN CATCH

	SELECT -100 AS difference
		 , ERROR_NUMBER() AS DATE
		 , ERROR_SEVERITY() AS obj_type_desc
		 , 1 AS l1
		 , 1 AS l2
		 , ERROR_STATE() AS obj_name
		 , 1 AS obj_id
		 , ERROR_MESSAGE() AS database_name
		 , 1 AS start_time
		 , 1 AS event_class
		 , 1 AS event_subclass
		 , 1 AS object_type
		 , 1 AS server_name
		 , 1 AS login_name
		 , 1 AS user_name
		 , 1 AS application_name
		 , 1 AS ddl_operation

END CATCH
