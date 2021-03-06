------------------------------------------------------------------------------
-- PostgreSQL Table Tranlation Engine - Main installation file
-- Version 0.1 for PostgreSQL 9.x
-- https://github.com/edwardsmarc/postTranslationEngine
--
-- This is free software; you can redistribute and/or modify it under
-- the terms of the GNU General Public Licence. See the COPYING file.
--
-- Copyright (C) 2018-2020 Pierre Racine <pierre.racine@sbf.ulaval.ca>,
--                         Marc Edwards <medwards219@gmail.com>,
--                         Pierre Vernier <pierre.vernier@gmail.com>
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- Types Definitions...
-------------------------------------------------------------------------------
--DROP TYPE TT_RuleDef_old CASCADE;
CREATE TYPE TT_RuleDef_old AS (
  fctName text,
  args text[],
  errorCode text,
  stopOnInvalid boolean
);

--DROP TYPE TT_RuleDef CASCADE;
CREATE TYPE TT_RuleDef AS (
  fctName text,
  args text,
  errorCode text,
  stopOnInvalid boolean
);

-- Debug configuration variable. Set tt.debug to TRUE to display all RAISE NOTICE
SET tt.debug TO FALSE;

-------------------------------------------------------------------------------
-- Function Definitions...
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- TT_IsError(text)
-- Function to test if helper functions return errors
-------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION TT_IsError(
  functionString text
)
RETURNS text AS $$
  DECLARE
    result boolean;
  BEGIN
    EXECUTE functionString INTO result;
    RETURN 'FALSE';
  EXCEPTION WHEN OTHERS THEN
    RETURN SQLERRM;
  END;
$$ LANGUAGE plpgsql VOLATILE;
-------------------------------------------------------------------------------
-- TT_NameRegex
-------------------------------------------------------------------------------
--DROP FUNCTION IF EXISTS TT_NameRegex();
CREATE OR REPLACE FUNCTION TT_NameRegex()
RETURNS text AS $$
  SELECT '(?:[[:alpha:]_][[:alnum:]_]*|"[^" ]*")'
  --SELECT '(?:\A(?:[[:alpha:]_][[:alnum:]_]*|(?:"[^" ]*")+)\M)'
$$ LANGUAGE sql STRICT;

/*
SELECT TT_IsName('"12_toto"') -- TRUE
SELECT TT_IsName('"12 toto"')-- FALSE
SELECT TT_IsName('12_toto') -- FALSE
SELECT TT_IsName('a12_toto') -- TRUE
SELECT TT_IsName('aa') -- TRUE
SELECT 'true' ~  TT_NameRegex() -- TRUE
SELECT '"1true"' ~  TT_NameRegex() -- TRUE
SELECT ' "1true"' ~  TT_NameRegex() -- FALSE
SELECT ' true' ~  TT_NameRegex() -- FALSE
SELECT 'true ' ~  TT_NameRegex() -- TRUE
SELECT 'true' ~  '(?:[[:alpha:]_][[:alnum:]_]*|(?:"[^" ]*")+)' -- TRUE
SELECT regexp_matches(' true false', '(' || TT_NameRegex() || ')', 'g')
*/
-------------------------------------------------------------------------------
-- TT_AllSpecialCharsRegex
-------------------------------------------------------------------------------
--DROP FUNCTION IF EXISTS TT_AllSpecialCharsRegex();
CREATE OR REPLACE FUNCTION TT_AllSpecialCharsRegex()
RETURNS text AS $$
  SELECT '\s\|\(\)\[\]\{\}\^\$\.\*\?\+\\'
$$ LANGUAGE sql STRICT;

--SELECT TT_AllSpecialCharsRegex();
-------------------------------------------------------------------------------
-- TT_AnythingBetweenSingleQuotesRegex
-------------------------------------------------------------------------------
--DROP FUNCTION IF EXISTS TT_AnythingBetweenSingleQuotesRegex();
CREATE OR REPLACE FUNCTION TT_AnythingBetweenSingleQuotesRegex()
RETURNS text AS $$
  SELECT '''(?:[^'']|'''')*'''
$$ LANGUAGE sql STRICT;

/*
SELECT 'aa' ~ ('^' || TT_AnythingBetweenSingleQuotesRegex() || '$');
SELECT '''aa''' ~ ('^' || TT_AnythingBetweenSingleQuotesRegex() || '$');
SELECT '''aa''''bb''' ~ ('^' || TT_AnythingBetweenSingleQuotesRegex() || '$');
SELECT '''aa'',''bb''' ~ ('^' || TT_AnythingBetweenSingleQuotesRegex() || '$');
*/
-------------------------------------------------------------------------------
-- TT_NumberRegex
-------------------------------------------------------------------------------
--DROP FUNCTION IF EXISTS TT_NumberRegex();
CREATE OR REPLACE FUNCTION TT_NumberRegex()
RETURNS text AS $$
  SELECT '(?<![^[:space:],\{\[\(])-?\d+\.?\d*(?![^[:space:],\}\]\):])'
$$ LANGUAGE sql STRICT;

/*
WITH tests AS (
  SELECT '''037365'' ~ (''^'' || TT_NumberRegex() || ''$'')' test, true expect
  UNION ALL
  SELECT '''037365'' ~ TT_NumberRegex()' test, true
  UNION ALL
  SELECT '''p1'' ~ TT_NumberRegex()' test, false
  UNION ALL
  SELECT '''10::'' ~ TT_NumberRegex()' test, true
  UNION ALL
  SELECT '''p1,34'' ~ TT_NumberRegex()' test, true
  UNION ALL
  SELECT '''p1,34'' ~ (''^'' || TT_NumberRegex() || ''$'')' test, false
  UNION ALL
  SELECT '''p1-34'' ~ TT_NumberRegex()' test, false
  UNION ALL
  SELECT '''p1(-34)'' ~ TT_NumberRegex()' test, true
  UNION ALL
  SELECT '''p1([-34])'' ~ TT_NumberRegex()' test, true
  UNION ALL
  SELECT '''p1({-34})'' ~ TT_NumberRegex()' test, true
  UNION ALL
  SELECT '''-37465.4567'' ~ (''^'' || TT_NumberRegex() || ''$'')' test, true
  UNION ALL
  SELECT '''-37465.4567'' ~ TT_NumberRegex()' test, true
  UNION ALL
  SELECT '''- 37465.4567'' ~ (''^'' || TT_NumberRegex() || ''$'')' test, false
  UNION ALL
  SELECT '''11b'' ~ (''^'' || TT_NumberRegex() || ''$'')' test, false
  UNION ALL
  SELECT '''11b'' ~ TT_NumberRegex()' test, false
)
SELECT test, eval(test) = expect::text passed
FROM tests
*/

-------------------------------------------------------------------------------
-- TT_OneLevelFctCallRegex
-------------------------------------------------------------------------------
--DROP FUNCTION IF EXISTS TT_OneLevelFctCallRegex();
CREATE OR REPLACE FUNCTION TT_OneLevelFctCallRegex()
RETURNS text AS $$
  --SELECT TT_NameRegex() || '\((?:' || TT_NumberRegex() || '\s*,?\s*|' || TT_NameRegex() || '\s*,?\s*|' || TT_AnythingBetweenSingleQuotesRegex() || '\s*,?\s*)*\)'
  --SELECT TT_NameRegex() || '\((?:' || TT_NumberRegex() || '|' || TT_NameRegex() || '|' ||    TT_AnythingBetweenSingleQuotesRegex() || ')?(?:\s*,\s*(?:' || TT_NumberRegex() || '|' || TT_NameRegex() || '|' || TT_AnythingBetweenSingleQuotesRegex() || '))*\)'
    SELECT TT_NameRegex() || '\(\{?(?:' || TT_NumberRegex() || '|' || TT_NameRegex() || '|' || TT_AnythingBetweenSingleQuotesRegex() || ')?\}?(?:\s*,\s*\{?(?:' || TT_NumberRegex() || '|' || TT_NameRegex() || '|' || TT_AnythingBetweenSingleQuotesRegex() || ')+\}?)*\)'
$$ LANGUAGE sql STRICT;

/*
SELECT unnest(regexp_matches('aa()', ('^' || TT_OneLevelFctCallRegex() || '$'), 'g'));
SELECT unnest(regexp_matches('aa(bbb)', ('^' || TT_OneLevelFctCallRegex() || '$'), 'g')); -- true
SELECT unnest(regexp_matches('aa(11)', ('^' || TT_OneLevelFctCallRegex() || '$'), 'g')); -- true
SELECT unnest(regexp_matches('aa(11b)', ('^' || TT_OneLevelFctCallRegex() || '$'), 'g')); -- false
SELECT unnest(regexp_matches('aa(''bbb'')', ('^' || TT_OneLevelFctCallRegex() || '$'), 'g')); -- true
SELECT unnest(regexp_matches('aa(''bb'', cc)', ('^' || TT_OneLevelFctCallRegex() || '$'), 'g')); -- true
SELECT unnest(regexp_matches('aa(bb(''cc'', dd))', ('^' || TT_OneLevelFctCallRegex() || '$'), 'g')); -- false
SELECT unnest(regexp_matches('aa({''bbb''})', ('^' || TT_OneLevelFctCallRegex() || '$'), 'g')); -- true
SELECT unnest(regexp_matches('aa({''bbb''}, {11, 44})', ('^' || TT_OneLevelFctCallRegex() || '$'), 'g')); -- true
SELECT unnest(regexp_matches('matchTable(minIndexCopyText({mod_1_year, mod_2_year},{mod_1,mod_2}),''translation'',''qc_disturbance_lookup'',''source_val'')', TT_OneLevelFctCallRegex(), 'g')); -- true
SELECT unnest(regexp_matches('minIndexCopyText({mod_1_year, mod_2_year},{mod_1,mod_2})', TT_OneLevelFctCallRegex(), 'g')); -- true
SELECT unnest(regexp_matches('minIndexCopyText({mod_1,mod_2}, {mod_1,mod_2})', TT_OneLevelFctCallRegex(), 'g')); -- true
SELECT unnest(regexp_matches('minIndexCopyText(aa, {mod_1,mod_2}, bb)', TT_OneLevelFctCallRegex(), 'g')); -- true
SELECT unnest(regexp_matches('minIndexCopyText({mod_1,mod_2}, {mod_1,mod_2}, ''9999'', ''9999'')', TT_OneLevelFctCallRegex(), 'g')); -- true
*/

-------------------------------------------------------------------------------
-- TT_FctExist
-- Function to test if a function exists.
------------------------------------------------------------
-- Self contained example:
--
-- SELECT TT_FctExists('TT_FctEval', {'text', 'text[]', 'jsonb', 'anyelement'})
------------------------------------------------------------
--DROP FUNCTION IF EXISTS TT_FctExists(text, text, text[]);
CREATE OR REPLACE FUNCTION TT_FctExists(
  schemaName name,
  fctName name,
  argTypes text[] DEFAULT NULL
)
RETURNS boolean AS $$
  DECLARE
    cnt int = 0;
    debug boolean = TT_Debug();
  BEGIN
    IF debug THEN RAISE NOTICE 'TT_FctExists BEGIN';END IF;
    fctName = 'tt_' || fctName;
    IF lower(schemaName) = 'public' OR schemaName IS NULL THEN
      schemaName = '';
    END IF;
    IF schemaName != '' THEN
      fctName = schemaName || '.' || fctName;
    END IF;
    IF fctName IS NULL THEN
      RETURN NULL;
    END IF;
    IF fctName = '' OR fctName = '.' THEN
      RETURN FALSE;
    END IF;
    fctName = lower(fctName);
    IF debug THEN RAISE NOTICE 'TT_FctExists 11 fctName=%, args=%', fctName, array_to_string(TT_LowerArr(argTypes), ',');END IF;
    SELECT count(*)
    FROM pg_proc
    WHERE schemaName = '' AND argTypes IS NULL AND proname = fctName OR
          oid::regprocedure::text = fctName || '(' || array_to_string(TT_LowerArr(argTypes), ',') || ')'
    INTO cnt;

    IF cnt > 0 THEN
      IF debug THEN RAISE NOTICE 'TT_FctExists END TRUE';END IF;
      RETURN TRUE;
    END IF;
    IF debug THEN RAISE NOTICE 'TT_FctExists END FALSE';END IF;
    RETURN FALSE;
  END;
$$ LANGUAGE plpgsql STABLE;
---------------------------------------------------
CREATE OR REPLACE FUNCTION TT_FctExists(
  fctName name,
  argTypes text[] DEFAULT NULL
)
RETURNS boolean AS $$
  SELECT TT_FctExists(''::name, fctName, argTypes)
$$ LANGUAGE sql STABLE;
---------------------------------------------------
-- TT_Debug
--
--   RETURNS boolean  - True if tt_debug is set to true. False if set to false or not set.
--
-- Wrapper to catch error when tt.error is not set.
------------------------------------------------------------
--DROP FUNCTION IF EXISTS TT_Debug(int);
CREATE OR REPLACE FUNCTION TT_Debug(
  level int DEFAULT NULL
)
RETURNS boolean AS $$
  DECLARE
  BEGIN
    RETURN current_setting('tt.debug' || CASE WHEN level IS NULL THEN '' ELSE '_l' || level::text END)::boolean;
    EXCEPTION WHEN OTHERS THEN -- if tt.debug is not set
      RETURN FALSE;
  END;
$$ LANGUAGE plpgsql STABLE;
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- TT_DefaultProjectErrorCode
--
--   rule text - Name of the rule.
--   type text - Required type.
--
--   RETURNS text - Default error code for this rule.
--
-- Default project error code function to be overwritten by specific projects
------------------------------------------------------------
--DROP FUNCTION IF EXISTS TT_DefaultProjectErrorCode(text, text);
CREATE OR REPLACE FUNCTION TT_DefaultProjectErrorCode(
  rule text, 
  targetType text
)
RETURNS text AS $$
  DECLARE
    rulelc text = lower(rule);
    targetTypelc text = lower(targetType);
  BEGIN
    IF targetTypelc = 'integer' OR targetTypelc = 'int' OR targetTypelc = 'double precision' THEN 
      RETURN CASE WHEN rulelc = 'projectrule1' THEN '-9999'
                  ELSE TT_DefaultErrorCode(rulelc, targetTypelc) END;
    ELSIF targetTypelc = 'geometry' THEN
      RETURN CASE WHEN rulelc = 'projectrule1' THEN NULL
                  ELSE TT_DefaultErrorCode(rulelc, targetTypelc) END;
    ELSE
      RETURN CASE WHEN rulelc = 'projectrule1' THEN 'ERROR_CODE'
                  ELSE TT_DefaultErrorCode(rulelc, targetTypelc) END;
    END IF;
  END;
$$ LANGUAGE plpgsql;
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- TT_FullTableName
--
--   schemaName name - Name of the schema.
--   tableName name  - Name of the table.
--
--   RETURNS text    - Full name of the table.
--
-- Return a well quoted, full table name, including the schema.
-- The schema default to 'public' if not provided.
------------------------------------------------------------
--DROP FUNCTION IF EXISTS TT_FullTableName(name, name);
CREATE OR REPLACE FUNCTION TT_FullTableName(
  schemaName name,
  tableName name
)
RETURNS text AS $$
  DECLARE
    newSchemaName text = '';
  BEGIN
    IF length(schemaName) > 0 THEN
      newSchemaName = schemaName;
    ELSE
      newSchemaName = 'public';
    END IF;
    RETURN quote_ident(newSchemaName) || '.' || quote_ident(tableName);
  END;
$$ LANGUAGE plpgsql IMMUTABLE;
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- TT_FullFunctionName
--
--   schemaName name - Name of the schema.
--   fctName name    - Name of the function.
--
--   RETURNS text    - Full name of the table.
--
-- Return a full function name, including the schema.
-- The schema default to 'public' if not provided.
------------------------------------------------------------
--DROP FUNCTION IF EXISTS TT_FullFunctionName(name, name);
CREATE OR REPLACE FUNCTION TT_FullFunctionName(
  schemaName name,
  fctName name
)
RETURNS text AS $$
  DECLARE
  BEGIN
    IF fctName IS NULL THEN
      RETURN NULL;
    END IF;
    fctName = 'tt_' || lower(fctName);
    schemaName = lower(schemaName);
    IF schemaName = 'public' OR schemaName IS NULL THEN
      schemaName = '';
    END IF;
    IF schemaName != '' THEN
      fctName = schemaName || '.' || fctName;
    END IF;
    RETURN fctName;
  END;
$$ LANGUAGE plpgsql VOLATILE;
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- TT_TableExists
--
-- schemaName text
-- tableName text
--
-- Return boolean (success or failure)
--
-- Determine if a table exists.
------------------------------------------------------------
--DROP FUNCTION IF EXISTS TT_TableExists(text, text);
CREATE OR REPLACE FUNCTION TT_TableExists(
  schemaName text,
  tableName text
)
RETURNS boolean AS $$
    SELECT NOT to_regclass(TT_FullTableName(schemaName, tableName)) IS NULL;
$$ LANGUAGE sql VOLATILE;
-------------------------------------------------------------------------------]

-------------------------------------------------------------------------------
-- TT_GetGeomColName
--
-- schemaName text
-- tableName text
--
-- Return text
--
-- Determine the name of the first geometry column if it exists (otherwise return NULL)
------------------------------------------------------------
--DROP FUNCTION IF EXISTS TT_GetGeomColName(text, text);
CREATE OR REPLACE FUNCTION TT_GetGeomColName(
  schemaName text,
  tableName text
)
RETURNS text AS $$
  SELECT column_name::text FROM information_schema.columns
  WHERE table_schema = lower(schemaName) AND table_name = lower(tableName) AND udt_name= 'geometry'
  LIMIT 1
$$ LANGUAGE sql VOLATILE;

--SELECT TT_GetGeomColName('rawfri', 'AB16r')
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- TT_PrettyDuration
--
-- seconds int
--
-- Format pased number of seconds into a pretty print time interval
------------------------------------------------------------
--DROP FUNCTION IF EXISTS TT_PrettyDuration(double precision);
CREATE OR REPLACE FUNCTION TT_PrettyDuration(
  seconds double precision,
  decDigits int DEFAULT NULL
)
RETURNS text AS $$
  DECLARE
    nbDays int;
    nbHours int;
    nbMinutes int;
  BEGIN
    IF seconds < 5 THEN
      IF NOT decDigits IS NULL THEN
        RETURN round(seconds::numeric, decDigits) || 's';
      ELSE
        RETURN seconds || 's';
      END IF;
    END IF;
    nbDays = floor(seconds/(24*3600));
    seconds = seconds - nbDays*24*3600;
    nbHours = floor(seconds/3600);
    seconds = seconds - nbHours*3600;
    nbMinutes = floor(seconds::int/60);
    seconds = seconds - nbMinutes*60;
--RAISE NOTICE 'nbDays=%', nbDays;
--RAISE NOTICE 'nbHours=%', nbHours;
--RAISE NOTICE 'nbMinutes=%', nbMinutes;
--RAISE NOTICE 'seconds=%', seconds;

    -- Display unit when is different than 0 or when in between two units different than 0
    RETURN CASE WHEN nbDays > 0 THEN nbDays || 'd' ELSE '' END ||
           CASE WHEN nbHours > 0 OR (nbDays > 0 AND (nbMinutes > 0 OR seconds > 0)) THEN lpad(nbHours::text, 2, '0') || 'h' ELSE '' END ||
           CASE WHEN nbMinutes > 0 OR ((nbDays > 0 OR nbHours > 0) AND (seconds > 0)) THEN lpad(nbMinutes::text, 2, '0') || 'm' ELSE '' END ||
           CASE WHEN seconds > 0 OR (nbDays = 0 AND nbHours = 0 AND nbMinutes = 0) THEN lpad(seconds::int::text, 2, '0') || 's' ELSE '' END;
  END;
$$ LANGUAGE plpgsql IMMUTABLE;
/*
SELECT TT_PrettyDuration(0.654); -- '0.654s'
SELECT TT_PrettyDuration(0.6547437); -- '0.6547437s'
SELECT TT_PrettyDuration(0.6547437, 3); -- '0.655s'
SELECT TT_PrettyDuration(0); -- '00s'
SELECT TT_PrettyDuration(1); -- '01s'
SELECT TT_PrettyDuration(1, 3); -- '1.000s'
SELECT TT_PrettyDuration(1.4536); -- '1.4536s'
SELECT TT_PrettyDuration(3, 4); -- '3.0000s'
SELECT TT_PrettyDuration(60); -- '01m'
SELECT TT_PrettyDuration(61); -- '01m01s'
SELECT TT_PrettyDuration(61, 3); -- '01m01s'
SELECT TT_PrettyDuration(3600); -- '01h'
SELECT TT_PrettyDuration(3603); -- '01h00m03s'
SELECT TT_PrettyDuration(3661); -- '01h01m01s'
SELECT TT_PrettyDuration(24*3600); -- '1d'
SELECT TT_PrettyDuration(24*3602); -- '1d00h00m48s'
SELECT TT_PrettyDuration(111.297334221); -- '01m51s'
SELECT TT_PrettyDuration(59.9); -- '60s'
*/
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- TT_LogInit
--
-- schemaName text
-- translationTableName text
-- sourceTableName
-- increment boolean
-- dupLogEntriesHandling text
--
-- Return the suffix of the created log table. 'FALSE' if creation failed.
-- Create a new or overwrite former log table and initialize a new one.
------------------------------------------------------------
--DROP FUNCTION IF EXISTS TT_LogInit(text, text, text, boolean, text);
CREATE OR REPLACE FUNCTION TT_LogInit(
  schemaName text,
  translationTableName text,
  sourceTableName text,
  increment boolean DEFAULT TRUE,
  dupLogEntriesHandling text DEFAULT '100'
)
RETURNS text AS $$
  DECLARE
    query text;
    logInc int = 1;
    logTableName text;
    action text = 'Creating';
  BEGIN
    IF NOT (TT_NotEmpty(translationTableName) AND TT_NotEmpty(sourceTableName)) THEN
      RAISE EXCEPTION 'TT_LogInit() ERROR: Invalid translation table name...';
    END IF;
    logTableName = translationTableName || '_4_' || sourceTableName || '_log_' || TT_Pad(logInc::text, 3::text, '0');
    IF increment THEN
      -- find an available table name
      WHILE TT_TableExists(schemaName, logTableName) LOOP
        logInc = logInc + 1;
        logTableName = translationTableName || '_4_' || sourceTableName || '_log_' || TT_Pad(logInc::text, 3::text, '0');
      END LOOP;
    ELSIF TT_TableExists(schemaName, logTableName) THEN
      action = 'Overwriting';
      query = 'DROP TABLE IF EXISTS ' || TT_FullTableName(schemaName, logTableName) || ';';
      BEGIN
        EXECUTE query;
      EXCEPTION WHEN OTHERS THEN
        RETURN 'FALSE';
      END;
    END IF;
    
    query = 'CREATE TABLE ' || TT_FullTableName(schemaName, logTableName) || ' (' ||
            'logID SERIAL, logTime timestamp with time zone, logEntryType text, 
             firstRowId text, message text, currentRowNb int, count int);';

    -- display the name of the logging table being produced
    RAISE NOTICE 'TT_LogInit(): % log table ''%''...', action, TT_FullTableName(schemaName, logTableName);
    -- display the type of handling for invalid values.
    IF dupLogEntriesHandling = 'ALL_OWN_ROW' THEN
      RAISE NOTICE 'TT_LogInit(): All invalid and translation error messages in their own rows...';
    ELSE
      IF dupLogEntriesHandling = 'ALL_GROUPED' THEN
        RAISE NOTICE 'TT_LogInit(): All invalid and translation error messages of the same type grouped in the same row.';
      ELSE
        RAISE NOTICE 'TT_LogInit(): Maximum of % invalid or translation error messages of the same type grouped in the same row...', dupLogEntriesHandling;
      END IF;
    END IF;
    BEGIN
      EXECUTE query;
    EXCEPTION WHEN OTHERS THEN
      RETURN 'FALSE';
    END;

    -- create an md5 index on the message column
    query = 'CREATE ' || 
             CASE WHEN dupLogEntriesHandling != 'ALL_OWN_ROW' THEN 'UNIQUE ' ELSE '' END || 
            'INDEX ON ' || TT_FullTableName(schemaName, logTableName) || 
            ' (md5(message));';
    EXECUTE query;
    RETURN logTableName;
  END;
$$ LANGUAGE plpgsql VOLATILE;
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- TT_ShowLastLog
--
-- schemaName text
-- translationTableName text
--
-- Return the last log table for the provided translation table.
------------------------------------------------------------
--DROP FUNCTION IF EXISTS TT_ShowLastLog(text, text, text, int);
CREATE OR REPLACE FUNCTION TT_ShowLastLog(
  schemaName text,
  translationTableName text,
  sourceTableName text,
  logNb int DEFAULT NULL
)
RETURNS TABLE (logID int, 
               logTime timestamp with time zone, 
               logEntryType text, 
               firstRowId text, 
               message text, 
               currentRowNb int, 
               count int) AS $$
  DECLARE
    query text;
    logInc int = 1;
    logTableName text;
    suffix text;
  BEGIN
    IF NOT logNb IS NULL THEN
      logInc = logNb;
    END IF;
    suffix = '_log_' || TT_Pad(logInc::text, 3::text, '0');
    logTableName = translationTableName || '_4_' || sourceTableName || suffix;
    IF TT_FullTableName(schemaName, logTableName) = 'public.' || suffix THEN
      RAISE NOTICE 'TT_ShowLastLog() ERROR: Invalid translation table name or number (%.%)...', schemaName, logTableName;
      RETURN;
    END IF;
    IF logNb IS NULL THEN
      -- find the last log table name
      WHILE TT_TableExists(schemaName, logTableName) LOOP
        logInc = logInc + 1;
        logTableName = translationTableName || '_4_' || sourceTableName || '_log_' || TT_Pad(logInc::text, 3::text, '0');
      END LOOP;
      -- if logInc = 1 means no log table exists
      IF logInc = 1 THEN
        RAISE NOTICE 'TT_ShowLastLog() ERROR: No translation log to show for translation table ''%.%'' and source table %...', schemaName, translationTableName, sourceTableName;
        RETURN;
      END IF;
      logInc = logInc - 1;
    ELSE
      IF NOT TT_TableExists(schemaName, logTableName) THEN
        RAISE NOTICE 'TT_ShowLastLog() ERROR: Translation log table ''%.%'' does not exist...', schemaName, logTableName;
        RETURN;
      END IF;
    END IF;
    logTableName = translationTableName || '_4_' || sourceTableName || '_log_' || TT_Pad(logInc::text, 3::text, '0');
    RAISE NOTICE 'TT_ShowLastLog(): Displaying log table ''%''', logTableName;
    query = 'SELECT logID, logTime, logEntryType, firstRowId, message, currentRowNb, count FROM ' || 
            TT_FullTableName(schemaName, logTableName) || ' ORDER BY logid;';
    RETURN QUERY EXECUTE query;
  END;
$$ LANGUAGE plpgsql VOLATILE;
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- TT_DeleteAllLogs
--
-- schemaName text
-- translationTableName text
--
-- Delete all log table associated with the target table.
-- If translationTableName is NULL, delete all log tables in schema.
------------------------------------------------------------
--DROP FUNCTION IF EXISTS TT_DeleteAllLogs(text, text);
CREATE OR REPLACE FUNCTION TT_DeleteAllLogs(
  schemaName text,
  translationTableName text DEFAULT NULL
)
RETURNS SETOF text AS $$
  DECLARE
    res RECORD;
  BEGIN
    IF translationTableName IS NULL THEN
      FOR res IN SELECT 'DROP TABLE IF EXISTS ' || TT_FullTableName(schemaName, table_name) || ';' query
                 FROM information_schema.tables 
                 WHERE lower(table_schema) = schemaName AND right(table_name, 8) ~ '_log_[0-9][0-9][0-9]'
                 ORDER BY table_name LOOP
        EXECUTE res.query;
        RETURN NEXT res.query;
      END LOOP;
    ELSE
      FOR res IN SELECT 'DROP TABLE IF EXISTS ' || TT_FullTableName(schemaName, table_name) || ';' query
                 FROM information_schema.tables 
                 WHERE char_length(table_name) > char_length(translationTableName) AND left(table_name, char_length(translationTableName)) = translationTableName
                 ORDER BY table_name LOOP
        EXECUTE res.query;
        RETURN NEXT res.query;
      END LOOP;
    END IF;
    RETURN;
  END;
$$ LANGUAGE plpgsql VOLATILE;
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- TT_Log
--
-- schemaName text   - Schema name of the logging table
-- logTableName text - Logging table name
-- logEntryType text - Type of logging entry (PROGRESS, INVALIDATION)
-- firstRowId text   - rowID of the first source triggering the logging entry.
-- message text      - Message to log
-- currentRowNb int  - Number of the row being processed
-- count int         - Number of rows associated with this log entry
--
-- Return boolean  -- Succees or failure.
-- Log an entry in the log table.
-- The log table has the following structure:
--   logid integer NOT NULL DEFAULT nextval('source_log_001_logid_seq'::regclass),
--   logtime timestamp,
--   logentrytype text,
--   firstrowid text,
--   message text,
--   currentrownb int,
--   count integer
------------------------------------------------------------
--DROP FUNCTION IF EXISTS TT_Log(text, text, text, text, text, text, int, int);
CREATE OR REPLACE FUNCTION TT_Log(
  schemaName text,
  logTableName text,
  dupLogEntriesHandling text,
  logEntryType text,
  firstRowId text,
  msg text,
  currentRowNb int,
  count int DEFAULT NULL
)
RETURNS boolean AS $$
  DECLARE
    query text;
  BEGIN
    IF upper(logEntryType) = 'PROGRESS' THEN
      query = 'INSERT INTO ' || TT_FullTableName(schemaName, logTableName) || ' VALUES (' ||
         'DEFAULT, now(), ''PROGRESS'', $1, $2, $3, $4);';
      EXECUTE query USING firstRowId, msg, currentRowNb, count;
      RETURN TRUE;
    ELSIF upper(logEntryType) = 'INVALID_VALUE' OR upper(logEntryType) = 'TRANSLATION_ERROR' THEN
      query = 'INSERT INTO ' || TT_FullTableName(schemaName, logTableName) || ' AS tbl VALUES (' ||
              'DEFAULT, now(), ''' || upper(logEntryType) || ''', $1, $2, $3, $4) ';
      IF dupLogEntriesHandling != 'ALL_OWN_ROW' THEN
        query = query || 'ON CONFLICT (md5(message)) DO UPDATE SET count = tbl.count + 1';
        IF dupLogEntriesHandling != 'ALL_GROUPED' THEN
          query = query || 'WHERE tbl.count < ' || dupLogEntriesHandling;
        END IF;
      END IF;
      query = query || ';';
      EXECUTE query USING firstRowId, msg, currentRowNb, 1;
      RETURN TRUE;
    ELSE
      RAISE EXCEPTION 'TT_Log() ERROR: Invalid logEntryType (%)...', logEntryType;
      RETURN FALSE;
    END IF;
  END;
$$ LANGUAGE plpgsql VOLATILE;
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- TT_IsCastableTo
--
--   val text
--   targetType text
--
--   RETURNS boolean
--
-- Can value be cast to target type
------------------------------------------------------------
--DROP FUNCTION IF EXISTS TT_IsCastableTo(text, text);
CREATE OR REPLACE FUNCTION TT_IsCastableTo(
  val text,
  targetType text
)
RETURNS boolean AS $$
  DECLARE
    query text;
  BEGIN
    -- NULL values are castable to everything
    IF NOT val IS NULL THEN
      query = 'SELECT ' || '''' || val || '''' || '::' || targetType || ';';
      EXECUTE query;
    END IF;
    RETURN TRUE;
  EXCEPTION WHEN OTHERS THEN
    RETURN FALSE;
  END;
$$ LANGUAGE plpgsql IMMUTABLE;
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- TT_IsSingleQuoted
-- DROP FUNCTION IF EXISTS TT_IsSingleQuoted(text);
CREATE OR REPLACE FUNCTION TT_IsSingleQuoted(
  str text
)
RETURNS boolean AS $$
  SELECT left(str, 1) = '''' AND right(str, 1) = '''';
$$ LANGUAGE sql IMMUTABLE;
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- TT_UnSingleQuote
-- DROP FUNCTION IF EXISTS TT_UnSingleQuote(text);
CREATE OR REPLACE FUNCTION TT_UnSingleQuote(
  str text
)
RETURNS text AS $$
  SELECT CASE WHEN left(str, 1) = '''' AND right(str, 1) = '''' THEN btrim(str, '''') ELSE str END;
$$ LANGUAGE sql IMMUTABLE;
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- TT_EscapeSingleQuotes
-- DROP FUNCTION IF EXISTS TT_EscapeSingleQuotes(text);
CREATE OR REPLACE FUNCTION TT_EscapeSingleQuotes(
  str text
)
RETURNS text AS $$
    SELECT replace(str, '''', '''''');
$$ LANGUAGE sql IMMUTABLE;
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- TT_EscapeDoubleQuotes
-- DROP FUNCTION IF EXISTS TT_EscapeDoubleQuotesAndBackslash(text);
CREATE OR REPLACE FUNCTION TT_EscapeDoubleQuotesAndBackslash(
  str text
)
RETURNS text AS $$
  SELECT replace(replace(str, '\', '\\'), '"', '\"'); -- '''
$$ LANGUAGE sql IMMUTABLE;
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- TT_IsSurroundedByChars
-- DROP FUNCTION IF EXISTS TT_IsSurroundedByChars(text, text[]);
CREATE OR REPLACE FUNCTION TT_IsSurroundedByChars(
  str text,
  chars text[]
)
RETURNS boolean AS $$
  DECLARE
  BEGIN
    IF cardinality(chars) != 2 THEN
      RAISE EXCEPTION 'TT_IsSurroundedByChars() ERROR: Number of chars must be 2 not %...', cardinality(chars);
    END IF;

    IF char_length(chars[1]) != 1 OR char_length(chars[2]) != 1 THEN
      RAISE EXCEPTION 'TT_IsSurroundedByChars() ERROR: Both chars (%) and (%) must be one and only one character long...', chars[1], chars[2];
    END IF;
    RETURN left(str, 1) = chars[1] AND right(str, 1) = chars[2];
  END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- DROP FUNCTION IF EXISTS TT_IsSurroundedByChars(text, text);
CREATE OR REPLACE FUNCTION TT_IsSurroundedByChars(
  inStr text,
  chars text
)
RETURNS boolean AS $$
  SELECT TT_IsSurroundedByChars(inStr, ARRAY[chars, chars]);
$$ LANGUAGE sql IMMUTABLE;

/*
SELECT TT_IsSurroundedByChars('''aa', '''')
SELECT TT_IsSurroundedByChars('''aa''', '''')
SELECT TT_IsSurroundedByChars('aa)', ARRAY['(', ')'])
SELECT TT_IsSurroundedByChars('(aa)', ARRAY['(', ')'])
*/
-------------------------------------------------------------------------------
-- TT_ReplaceAroundChars()
---------------------------------------------------------------
-- DROP FUNCTION IF EXISTS TT_ReplaceAroundChars(text, text[], text[], text[], boolean);
CREATE OR REPLACE FUNCTION TT_ReplaceAroundChars(
  inStr text,
  chars text[],
  searchStrings text[],
  replacementStrings text[],
  outside boolean DEFAULT FALSE
)
RETURNS text AS $$
  DECLARE
    i int;
    newStr text;
    returnStr text;
    str text[];
    strArr text[];
    searchRegex text;
    surrounded boolean;
    escapedChars text[];
  BEGIN
--RAISE NOTICE 'TT_ReplaceAroundChars() 11 inStr=%', inStr;
    IF cardinality(chars) != 2 THEN
      RAISE EXCEPTION 'TT_ReplaceAroundChars() ERROR: Number of chars must be 2 not %...', cardinality(chars);
    END IF;
    IF char_length(chars[1]) != 1 OR char_length(chars[2]) != 1 THEN
      RAISE EXCEPTION 'TT_ReplaceAroundChars() ERROR: Both chars (%) and (%) must be one and only one character long...', chars[1], chars[2];
    END IF;
    IF searchStrings IS NULL OR searchStrings[1] IS NULL THEN
      RETURN inStr;
    END IF;
    IF replacementStrings IS NULL OR replacementStrings[1] IS NULL THEN
      RAISE EXCEPTION 'TT_ReplaceAroundChars() ERROR: replacementStrings is NULL...';
    END IF;
    IF cardinality(searchStrings) != cardinality(replacementStrings) THEN
      RAISE EXCEPTION 'TT_ReplaceAroundChars() ERROR: Number of searchStrings (%) different from number of replacementStrings(%)...', cardinality(searchStrings), cardinality(replacementStrings);
    END IF;

    -- Escape both chars before being used as regex
    escapedChars[1] = regexp_replace(chars[1], '([' || TT_AllSpecialCharsRegex() || '])', '\\\1');
    escapedChars[2] = regexp_replace(chars[2], '([' || TT_AllSpecialCharsRegex() || '])', '\\\1');

    -- Build the array of substring to replace into
    searchRegex = '(?:' || escapedChars[1] || '[^' || escapedChars[1] || escapedChars[2] || ']*' || escapedChars[2] || '|[^' || escapedChars[1] || escapedChars[2] || ']*)';
    returnStr = inStr;

    FOR str IN SELECT regexp_matches(returnStr, searchRegex, 'g') LOOP
--RAISE NOTICE 'TT_ReplaceAroundChars() 22 str=%', str;
      newStr = str[1];
      surrounded = TT_IsSurroundedByChars(newStr, chars);

      IF (outside AND NOT surrounded) OR (NOT outside AND surrounded) THEN
        -- Replace all provided search string with the corresponding replacement string
        FOR i IN 1..cardinality(searchStrings) LOOP
--RAISE NOTICE 'TT_ReplaceAroundChars() 33 searchStrings[%]=%', i, searchStrings[i];
          IF searchStrings[i] IS NULL THEN
            RAISE EXCEPTION 'TT_ReplaceAroundChars() ERROR: searchStrings # % is NULL...', i;
          END IF;
          IF replacementStrings[i] IS NULL THEN
            RAISE EXCEPTION 'TT_ReplaceAroundChars() ERROR: replacementStrings # % is NULL...', i;
          END IF;
          IF TT_IsSurroundedByChars(searchStrings[i], '\') THEN
            newStr = regexp_replace(newStr, btrim(searchStrings[i], '\\'), replacementStrings[i], 'g');
          ELSE
            newStr = replace(newStr, searchStrings[i], replacementStrings[i]);
          END IF;
--RAISE NOTICE 'TT_ReplaceAroundChars() 44 newStr=%', newStr;
        END LOOP;
        -- Replace the quoted string with the new string in the final string
        returnStr = replace(returnStr, str[1], newStr);
--RAISE NOTICE 'TT_ReplaceAroundChars() 55 returnStr=%', returnStr;
      END IF;
    END LOOP;
    RETURN returnStr;
  END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- DROP FUNCTION IF EXISTS TT_ReplaceAroundChars(text, text, text, text, boolean);
CREATE OR REPLACE FUNCTION TT_ReplaceAroundChars(
  inStr text,
  chars text,
  searchStrings text,
  replacementStrings text,
  outside boolean DEFAULT FALSE
)
RETURNS text AS $$
  SELECT TT_ReplaceAroundChars(inStr, ARRAY[chars, chars], ARRAY[searchStrings], ARRAY[replacementStrings], outside);
$$ LANGUAGE sql IMMUTABLE;

-- DROP FUNCTION IF EXISTS TT_ReplaceAroundChars(text, text, text[], text[], boolean);
CREATE OR REPLACE FUNCTION TT_ReplaceAroundChars(
  inStr text,
  chars text,
  searchStrings text[],
  replacementStrings text[],
  outside boolean DEFAULT FALSE
)
RETURNS text AS $$
  SELECT TT_ReplaceAroundChars(inStr, ARRAY[chars, chars], searchStrings, replacementStrings, outside);
$$ LANGUAGE sql IMMUTABLE;

-- DROP FUNCTION IF EXISTS TT_ReplaceAroundChars(text, text[], text text, boolean);
CREATE OR REPLACE FUNCTION TT_ReplaceAroundChars(
  inStr text,
  chars text[],
  searchStrings text,
  replacementStrings text,
  outside boolean DEFAULT FALSE
)
RETURNS text AS $$
  SELECT TT_ReplaceAroundChars(inStr, chars, ARRAY[searchStrings], ARRAY[replacementStrings], outside);
$$ LANGUAGE sql IMMUTABLE;
/*
SELECT TT_ReplaceAroundChars('aa', '''', '\\a\', 'x\1y', TRUE);
SELECT TT_ReplaceAroundChars('{aa}', '''', ARRAY['\{\', '\}\'], ARRAY['ARRAY[',']'], TRUE);

*/
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- TT_LowerArr
-- Lowercase text array (often to compare them while ignoring case)
------------------------------------------------------------
--DROP FUNCTION IF EXISTS TT_LowerArr(text[]);
CREATE OR REPLACE FUNCTION TT_LowerArr(
  arr text[] DEFAULT NULL
)
RETURNS text[] AS $$
  DECLARE
    newArr text[] = ARRAY[]::text[];
  BEGIN
    IF NOT arr IS NULL AND arr = ARRAY[]::text[] THEN
      RETURN ARRAY[]::text[];
    END IF;
    SELECT array_agg(lower(a)) FROM unnest(arr) a INTO newArr;
    RETURN newArr;
  END;
$$ LANGUAGE plpgsql IMMUTABLE STRICT;
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- TT_DropAllTTFct
--
--   RETURNS SETOF text     - All DROPed query executed.
--
-- DROP all functions starting with 'TT_' (case insensitive).
------------------------------------------------------------
--DROP FUNCTION IF EXISTS TT_DropAllTTFct();
CREATE OR REPLACE FUNCTION TT_DropAllTTFct(
)
RETURNS SETOF text AS $$
  DECLARE
    res RECORD;
  BEGIN
    FOR res IN SELECT 'DROP FUNCTION ' || oid::regprocedure::text || ';' query
               FROM pg_proc WHERE left(proname, 3) = 'tt_' AND pg_function_is_visible(oid) LOOP
      EXECUTE res.query;
      RETURN NEXT res.query;
    END LOOP;
  RETURN;
END
$$ LANGUAGE plpgsql VOLATILE;
-- SELECT TT_DropAllTTFct();
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- TT_DropAllTranslateFct
--
--   RETURNS SETOF text     - All DROPed query executed.
--
-- DROP all functions starting with 'TT_Translate' (case insensitive).
------------------------------------------------------------
--DROP FUNCTION IF EXISTS TT_DropAllTranslateFct();
CREATE OR REPLACE FUNCTION TT_DropAllTranslateFct(
)
RETURNS SETOF text AS $$
  DECLARE
    res RECORD;
  BEGIN
    FOR res IN SELECT 'DROP FUNCTION ' || oid::regprocedure::text || ';' query
               FROM pg_proc WHERE left(proname, 12) = 'tt_translate' AND pg_function_is_visible(oid) LOOP
      EXECUTE res.query;
      RETURN NEXT res.query;
    END LOOP;
  RETURN;
END
$$ LANGUAGE plpgsql VOLATILE;
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- TT_TextFctExist
--
--   schemaName name,
--   fctString text
--   argLength  int
--
--   RETURNS boolean
--
-- Returns TRUE if fctString exists as a function in the catalog with the
-- specified function name and number of arguments. Only works for helper
-- functions accepting text arguments only.
------------------------------------------------------------
-- Self contained example:
--
-- SELECT TT_TextFctExists('TT_NotNull', 1)
------------------------------------------------------------
--DROP FUNCTION IF EXISTS TT_TextFctExists(text, int);
CREATE OR REPLACE FUNCTION TT_TextFctExists(
  schemaName name,
  fctName name,
  argLength int
)
RETURNS boolean AS $$
  DECLARE
    cnt int = 0;
    debug boolean = TT_Debug();
    args text;
  BEGIN
    IF debug THEN RAISE NOTICE 'TT_TextFctExists BEGIN';END IF;
    fctName = TT_FullFunctionName(schemaName, fctName);
    IF fctName IS NULL THEN
      RETURN FALSE;
    END IF;
    IF debug THEN RAISE NOTICE 'TT_TextFctExists 11 fctName=%, argLength=%', fctName, argLength;END IF;

    SELECT count(*)
    FROM pg_proc
    WHERE proname = fctName AND coalesce(cardinality(proargnames), 0) = argLength
    LIMIT 1
    INTO cnt;

    IF cnt = 1 THEN
      IF debug THEN RAISE NOTICE 'TT_TextFctExists END TRUE';END IF;
      RETURN TRUE;
    END IF;
    IF debug THEN RAISE NOTICE 'TT_TextFctExists END FALSE';END IF;
    RETURN FALSE;
  END;
$$ LANGUAGE plpgsql VOLATILE;

CREATE OR REPLACE FUNCTION TT_TextFctExists(
  fctName name,
  argLength int
)
RETURNS boolean AS $$
  SELECT TT_TextFctExists(''::name, fctName, argLength)
$$ LANGUAGE sql VOLATILE;
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- TT_TextFctReturnType
--
--   schemaName name
--   fctName name
--   argLength int
--
--   RETURNS text
--
-- Returns the return type of a PostgreSQL function taking text arguments only.
------------------------------------------------------------
--DROP FUNCTION IF EXISTS TT_TextFctReturnType(name, name, int);
CREATE OR REPLACE FUNCTION TT_TextFctReturnType(
  schemaName name,
  fctName name,
  argLength int
)
RETURNS text AS $$
  DECLARE
    result text;
    debug boolean = TT_Debug();
  BEGIN
    IF debug THEN RAISE NOTICE 'TT_TextFctReturnType BEGIN';END IF;
    IF TT_TextFctExists(fctName, argLength) THEN
      fctName = TT_FullFunctionName(schemaName, fctName);
      IF fctName IS NULL THEN
        RETURN FALSE;
      END IF;
      IF debug THEN RAISE NOTICE 'TT_TextFctReturnType 11 fctName=%, argLength=%', fctName, argLength;END IF;

      SELECT pg_catalog.pg_get_function_result(oid)
      FROM pg_proc
      WHERE proname = fctName AND coalesce(cardinality(proargnames), 0) = argLength
      INTO result;

      IF debug THEN RAISE NOTICE 'TT_TextFctReturnType END result=%', result;END IF;
      RETURN result;
    ELSE
      IF debug THEN RAISE NOTICE 'TT_TextFctReturnType END NULL';END IF;
      RETURN NULL;
    END IF;
  END;
$$ LANGUAGE plpgsql VOLATILE;

--DROP FUNCTION IF EXISTS TT_TextFctReturnType(name, int);
CREATE OR REPLACE FUNCTION TT_TextFctReturnType(
  fctName name,
  argLength int
)
RETURNS text AS $$
  SELECT TT_TextFctReturnType(''::name, fctName, argLength)
$$ LANGUAGE sql VOLATILE;
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- TT_ParseStringList
--
-- Parses list of strings into an array.
-- Can take a simple string, will convert it to a string array.
--
-- strip boolean - strips surrounding quotes from any strings. Used in helper functions when
-- parsing values.
--
-- e.g. TT_ParseStringList('col2, "string2", "", ""')
------------------------------------------------------------
-- DROP FUNCTION IF EXISTS TT_ParseStringList(text,boolean);
CREATE OR REPLACE FUNCTION TT_ParseStringList(
    argStr text DEFAULT NULL,
    strip boolean DEFAULT FALSE
)
RETURNS text[] AS $$
  DECLARE
    args text[];
    arg text;
    result text[] = '{}';
    i int;
  BEGIN
    IF argStr IS NULL THEN
      RETURN NULL;
    ENd IF;

    argStr = btrim(argStr);
    IF left(argStr, 1) = '{'  AND right(argStr, 1) = '}' THEN
      result = argStr::text[];
    ELSE
      result = ARRAY[argStr];
    END IF;
    IF strip THEN
      FOR i IN 1..cardinality(result) LOOP
        result[i] = btrim(btrim(result[i],'"'),'''');
      END LOOP;
    ELSE
      -- Remove double quotes anyway
      FOR i IN 1..cardinality(result) LOOP
        result[i] = btrim(result[i],'"');
      END LOOP;
    END IF;
    RETURN result;
  END;
$$ LANGUAGE plpgsql IMMUTABLE;
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- TT_RepackStringList
--
-- Convert a text array into a text array string (that can be reparsed by
-- TT_ParseStringList).
--
-- When the array is composed of only one string, return as text (not as text
-- array string )
-------------------------------------------------------------------------------
-- DROP FUNCTION IF EXISTS TT_RepackStringList(text[], boolean);
CREATE OR REPLACE FUNCTION TT_RepackStringList(
  args text[] DEFAULT NULL,
  toSQL boolean DEFAULT FALSE
)
RETURNS text AS $$
  DECLARE
    arg text;
    result text = '';
    debug boolean = TT_Debug();
    openingBrace text = '{';
    closingBrace text = '}';
  BEGIN
    IF debug THEN RAISE NOTICE 'TT_RepackStringList 00 cardinality=%', cardinality(args);END IF;
    IF (cardinality(args) = 1 AND args[1] IS NULL) THEN
      RETURN NULL;
    END IF;
    IF toSQL THEN
     openingBrace = 'ARRAY[';
     closingBrace = ']';
    END IF;
    -- open the array string only when a true array or when only item is NULL
    IF cardinality(args) > 1 THEN
      result = openingBrace;
    END IF;

    FOREACH arg in ARRAY args LOOP
      IF debug THEN RAISE NOTICE 'TT_RepackStringList 11 arg=%', arg;END IF;
      IF arg IS NULL THEN
        result = result || 'NULL' || ',';
      ELSE
        IF debug THEN RAISE NOTICE 'TT_RepackStringList 22 result=%', result;END IF;
        IF cardinality(args) > 1 AND (NOT toSQL OR (NOT TT_IsName(arg) AND NOT TT_IsSingleQuoted(arg) AND NOT TT_IsNumeric(arg))) THEN
          IF debug THEN RAISE NOTICE 'TT_RepackStringList 33';END IF;
          result = result || '"' || TT_EscapeDoubleQuotesAndBackslash(arg) || '",';
        ELSE
          IF debug THEN RAISE NOTICE 'TT_RepackStringList 44';END IF;
          result = result || arg || ',';
        END IF;
      END IF;
    END LOOP;
    -- remove the last comma and space, and close the array
    result = left(result, char_length(result) - 1);

    -- close the array string only when a true array or when only item is NULL
    IF cardinality(args) > 1 THEN
      result = result || closingBrace;
    END IF;
    IF debug THEN RAISE NOTICE 'TT_RepackStringList 55 result=%', result;END IF;
    RETURN result;
  END;
$$ LANGUAGE plpgsql IMMUTABLE STRICT;
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- TT_RuleToSQL
--
--  - fctName text  - Name of the function to evaluate. Will always be prefixed
--                    with "TT_".
--  - arg text[]    - Array of argument values to pass to the function.
--                    Generally includes one or two column names to get replaced
--                    with values from the vals argument.
--
--    RETURNS text
--
-- Reconstruct a query string from passed function name and arguments.
------------------------------------------------------------
--DROP FUNCTION IF EXISTS TT_RuleToSQL(text, text[]);
CREATE OR REPLACE FUNCTION TT_RuleToSQL(
  fctName text,
  args text[]
)
RETURNS text AS $$
  DECLARE
    queryStr text = '';
    arg text;
    argCnt int;
    debug boolean = FALSE;
  BEGIN
    IF debug THEN RAISE NOTICE 'TT_RuleToSQL BEGIN fctName=%, args=%', fctName, args::text;END IF;
    queryStr = 'TT_' || fctName || '(';
    argCnt = 0;
    IF debug THEN RAISE NOTICE 'TT_RuleToSQL 11 queryStr=%', queryStr;END IF;

    FOREACH arg IN ARRAY coalesce(args, ARRAY[]::text[]) LOOP
      -- Add a comma if it's not the first argument
      IF argCnt != 0 THEN
        queryStr = queryStr || ', ';
      END IF;
      IF debug THEN RAISE NOTICE 'TT_RuleToSQL 22 queryStr=%', queryStr;END IF;
      queryStr = queryStr || TT_RepackStringList(TT_ParseStringList(arg), TRUE) || CASE WHEN TT_IsStringList(arg, TRUE) THEN '::text[]' ELSE '' END || '::text';
      IF debug THEN RAISE NOTICE 'TT_RuleToSQL 33 queryStr=%', queryStr;END IF;
      argCnt = argCnt + 1;
    END LOOP;
    queryStr = queryStr || ')';

    IF debug THEN RAISE NOTICE 'TT_RuleToSQL END queryStr=%', queryStr;END IF;
    RETURN queryStr;
  END;
$$ LANGUAGE plpgsql IMMUTABLE;

-------------------------------------------------------------------------------
-- TT_PrepareFctCalls
--
--  - fctCall text  - Function call string into which function names must be 
--                    prefixed with "TT_".
--
--    RETURNS text
--
-- Reconstruct a query string from passed function name and arguments.
------------------------------------------------------------
--DROP FUNCTION IF EXISTS TT_PrepareFctCalls(text);
CREATE OR REPLACE FUNCTION TT_PrepareFctCalls(
  fctCall text
)
RETURNS text AS $$
  BEGIN
    -- Remove useless single quotes around numbers
    fctCall = TT_ReplaceAroundChars(fctCall, '''', '\''(' || TT_NumberRegex() || ')''\', '\1');

    -- Prefix function names with 'TT_', suffix variables and function with '::text' and prefix variable name with 'maintable.'
    fctCall = TT_ReplaceAroundChars(fctCall, '''', 
                                    ARRAY['\(' || TT_NameRegex() || ')\s*\(\',
                                          '\(' || TT_NameRegex() || '|' || TT_NumberRegex() || ')\s*(?=[\,\)\]\}])\', 
                                          '\(' || TT_NameRegex() || '|' || TT_NumberRegex() || ')\s*$\',
                                          '\([Tt][Rr][Uu][Ee]|[Ff][Aa][Ll][Ss][Ee])::text\',
                                          '\(' || TT_NameRegex() || ')::text\',
                                          '\(' || TT_NumberRegex() || ')::text\',
                                          '\{\', '\}\'
                                         ], 
                                    ARRAY['TT_\1(', 
                                          '\1::text', 
                                          '\1::text',
                                          '''\1''::text',
                                          'maintable.\1::text',
                                          '(\1)::text',
                                          'ARRAY[', ']::text[]::text'
                                         ], TRUE);

    RETURN fctCall;
  END;
$$ LANGUAGE plpgsql IMMUTABLE;

/*
SELECT TT_PrepareFctCalls('a_a(bb (''a,bc'', xyz, cc()))')
SELECT TT_PrepareFctCalls('))')
SELECT TT_PrepareFctCalls('ab')
SELECT TT_PrepareFctCalls('a() , b()')
SELECT TT_PrepareFctCalls('fct(''a,a'', var)')
SELECT TT_PrepareFctCalls('fct(aa, var)')
SELECT TT_PrepareFctCalls('''fct(aa, var)''')
SELECT TT_PrepareFctCalls('2')
SELECT TT_PrepareFctCalls('''2''')
SELECT TT_PrepareFctCalls('fct(1, 2)')
SELECT TT_PrepareFctCalls('fct(1, 2.2, -3.3)')
SELECT TT_PrepareFctCalls('fct(sp1, 1, 2.2, ''aa'', -3.3, ''-10.4567'')')
SELECT 1::text, 2.2::text, 'aa', (-3.3)::text, (-10.4567)::text
SELECT (1)::text, (2.2)::text, 'aa', (-3.3)::text, (-10.4567)::text
SELECT TT_PrepareFctCalls('{1, 2}')
SELECT TT_PrepareFctCalls('true')
SELECT TT_PrepareFctCalls('TT_padConcat({inventory_id, src_filename, geocode_1_10, geocode_11_20, ''''''''}, {4,15,10,10,7}, {''x'',''x'',''x'',0}, ''-'', ''TRUE'', ''TRUE'')');

SELECT TT_PrepareFctCalls('TT_padConcat({inventory_id::text})');
SELECT TT_PrepareFctCalls('TT_padConcat(inventory_id)');

SELECT TT_ReplaceAroundChars('a(1)', '''', '\(' || TT_NumberRegex() || ')\', 'x\1x', TRUE)
SELECT TT_ReplaceAroundChars('a(1)', '''', '\(' || TT_NameRegex() || '|' || TT_NumberRegex() || ')\', 'x\1x', TRUE)
SELECT TT_ReplaceAroundChars('a(1,2)', '''', '\(' || TT_NameRegex() || '|' || TT_NumberRegex() || ')\s*(?=[\,\)\]\}])\', '\1::text', TRUE)
SELECT TT_ReplaceAroundChars('fct(1, 2.2, -3.3)', '''', '\(' || TT_NameRegex() || '|' || TT_NumberRegex() || ')\s*(?=[\,\)\]\}])\', '\1::text', TRUE)
*/

-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- TT_TextFctQuery
--
--  - fctName text  - Name of the function to evaluate. Will always be prefixed
--                    with "TT_".
--  - arg text[]    - Array of argument values to pass to the function.
--                    Generally includes one or two column names to get replaced
--                    with values from the vals argument.
--  - vals jsonb    - Replacement values passed as a jsonb object (since
--
--    RETURNS text
--
-- Replace column names with source values and return a complete query string.
------------------------------------------------------------
--DROP FUNCTION IF EXISTS TT_TextFctQuery(text, text[], jsonb, boolean, boolean);
CREATE OR REPLACE FUNCTION TT_TextFctQuery(
  fctName text,
  args text[],
  vals jsonb,
  escape boolean DEFAULT TRUE,
  varName boolean DEFAULT FALSE
)
RETURNS text AS $$
  DECLARE
    queryStr text = '';
    arg text;
    argCnt int;
    argNested text;
    argValNested text;
    repackArray text[];
    isStrList boolean;
    repackStr text;
    debug boolean = FALSE;
  BEGIN
    IF debug THEN RAISE NOTICE 'TT_TextFctQuery BEGIN fctName=%, args=%, vals=%', fctName, args::text, vals::text;END IF;
    queryStr = fctName || '(';
    argCnt = 0;
    IF debug THEN RAISE NOTICE 'TT_TextFctQuery 11 queryStr=%', queryStr;END IF;

    FOREACH arg IN ARRAY coalesce(args, ARRAY[]::text[]) LOOP
      repackArray = ARRAY[]::text[];
      IF debug THEN RAISE NOTICE 'TT_TextFctQuery 22 cardinality(repackArray)=%', cardinality(repackArray);END IF;
      -- add a comma if it's not the first argument
      IF argCnt != 0 THEN
        queryStr = queryStr || ', ';
      END IF;
      isStrList = TT_IsStringList(arg, TRUE);
      FOREACH argNested IN ARRAY TT_ParseStringList(arg) LOOP
        IF debug THEN RAISE NOTICE 'TT_TextFctQuery 33';END IF;
        IF TT_IsName(argNested) THEN
          IF vals ? argNested THEN
            argValNested = vals->>argNested;
            IF varName THEN
              argValNested = argNested || CASE WHEN argValNested IS NULL THEN '=NULL'
                                               ELSE '=''' || TT_EscapeSingleQuotes(argValNested) || '''' END;
            END IF;
            repackArray = array_append(repackArray, argValNested);
            IF debug THEN RAISE NOTICE 'TT_TextFctQuery 44 argValNested=%', argValNested;END IF;
          ELSE
            -- if column name not in source table, raise exception
            RAISE EXCEPTION 'ERROR IN TRANSLATION TABLE: Source attribute ''%'', called in function ''%()'', does not exist in the source table...', argNested, fctName;
          END IF;
        ELSE
          IF debug THEN RAISE NOTICE 'TT_TextFctQuery 55 argNested=%', argNested;END IF;
          -- we can now remove the surrounding single quotes from the string
          -- since we have processed column names
          IF varName AND NOT isStrList THEN
            repackArray = array_append(repackArray, argNested);
          ELSE
            repackArray = array_append(repackArray, TT_UnSingleQuote(argNested));
          END IF;
        END IF;
      END LOOP;
      IF debug THEN RAISE NOTICE 'TT_TextFctQuery 66 queryStr=%', queryStr;END IF;
      repackStr = TT_RepackStringList(repackArray);
      IF escape AND NOT repackStr IS NULL THEN
        queryStr = queryStr || '''' || TT_EscapeSingleQuotes(repackStr) || '''::text';
      ELSE
        queryStr = queryStr || coalesce(repackStr, 'NULL');
      END IF;
      IF debug THEN RAISE NOTICE 'TT_TextFctQuery 88 queryStr=%', queryStr;END IF;
      argCnt = argCnt + 1;
    END LOOP;
    queryStr = queryStr || ')';

    IF debug THEN RAISE NOTICE 'TT_TextFctQuery END queryStr=%', queryStr;END IF;
    RETURN queryStr;
  END;
$$ LANGUAGE plpgsql IMMUTABLE;
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- TT_TextFctEval
--
--  - fctName text          - Name of the function to evaluate. Will always be prefixed
--                            with "TT_".
--  - arg text[]            - Array of argument values to pass to the function.
--                            Generally includes one or two column names to get replaced
--                            with values from the vals argument.
--  - vals jsonb            - Replacement values passed as a jsonb object (since
--                            PostgresQL does not allow passing RECORDs to functions).
--  - returnType anyelement - Determines the type of the returned value
--                            (declared generically as anyelement).
--  - checkExistence        - Should the function check the existence of the helper
--                            function using TT_TextFctExists. TT_ValidateTTable also
--                            checks existence so setting this to FALSE can avoid
--                            repeating the check.
--
--    RETURNS anyelement
--
-- Evaluate a function given its name, some arguments and replacement values.
-- All arguments matching the name of a value found in the jsonb vals structure
-- are replaced with this value. returnType determines the return type of this
-- pseudo-type function.
--
-- Column values and strings are returned as text strings
-- String lists are returned as a comma separated list of single quoted strings
-- wrapped in {}. e.g. {'val1', 'val2'}
--
-- This version passes all vals as type text when running helper functions.
------------------------------------------------------------
-- DROP FUNCTION IF EXISTS TT_TextFctEval(text, text[], jsonb, anyelement, boolean);
CREATE OR REPLACE FUNCTION TT_TextFctEval(
  fctName text,
  args text[],
  vals jsonb,
  returnType anyelement,
  checkExistence boolean DEFAULT TRUE
)
RETURNS anyelement AS $$
  DECLARE
    queryStr text;
    result ALIAS FOR $0;
    debug boolean = FALSE;
  BEGIN
    -- This function returns a polymorphic type (the one provided in the returnType input argument)
    IF debug THEN RAISE NOTICE 'TT_TextFctEval BEGIN fctName=%, args=%, vals=%, returnType=%', fctName, args, vals, returnType;END IF;

    -- fctName should never be NULL
    IF fctName IS NULL OR (checkExistence AND (NOT TT_TextFctExists(fctName, coalesce(cardinality(args), 0)))) THEN
      IF debug THEN RAISE NOTICE 'TT_TextFctEval 11 fctName=%, args=%', fctName, cardinality(args);END IF;
      RAISE EXCEPTION 'ERROR IN TRANSLATION TABLE: Helper function %(%) does not exist.', fctName, btrim(repeat('text,', cardinality(args)),',');
    END IF;

    IF debug THEN RAISE NOTICE 'TT_TextFctEval 22 fctName=%, args=%', fctName, cardinality(args);END IF;
    queryStr = 'SELECT TT_' || TT_TextFctQuery(fctName, args, vals) || '::' || pg_typeof(result);

    IF debug THEN RAISE NOTICE 'TT_TextFctEval 33 queryStr=%', queryStr;END IF;
    EXECUTE queryStr INTO STRICT result;
    IF debug THEN RAISE NOTICE 'TT_TextFctEval END result=%', result;END IF;
    RETURN result;
  END;
$$ LANGUAGE plpgsql VOLATILE;
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- TT_ParseArgs
--
-- Parses arguments from translation table into three classes:
-- LISTS - wrapped in {}, to be processed by TT_ParseStringList()
      -- TT_ParseStringList returns a text array of parsed strings and column names
      -- which are re-wrapped in {} and passed to the output array.
-- STRINGS - wrapped in '' or "" or empty strings. Passed directly to the output array.
-- COLUMN NAMES - words containing - or _ but no spaces. Validated and passed to the
-- output array. Error raised if invalid.
--
-- e.g. TT_ParseArgs('column_A, ''string 1'', {col2, "string2", "", ""}')
------------------------------------------------------------
-- DROP FUNCTION IF EXISTS TT_ParseArgs(text);
CREATE OR REPLACE FUNCTION TT_ParseArgs(
    argStr text DEFAULT NULL
)
RETURNS text[] AS $$
  -- Matches:
    -- [^\s,][-_\.\w\s]* - any word including '-' or '_' or a space, removes any preceding spaces or commas
    -- ''[^''\\]*(?:\\''[^''\\]*)*''
      -- '' - single quotes surrounding...
      -- [^''\\]* - anything thats not \ or ' followed by...
      -- (?:\\''[^''\\]*)* - zero or more sequences of...
        -- \\'' - a backslash escaped '
        -- [^''\\]* - anything thats not \ or '
      -- ?:\\'' - makes a non-capturing match. The match for \' is not reported.
    -- "[^"]+" - double quotes surrounding anything except double quotes. No need to escape single quotes here.
    -- {[^}]+} - anything inside curly brackets. [^}] makes it not greedy so it will match multiple lists
    -- ""|'''' - empty strings
  SELECT array_agg(str)
  FROM (SELECT (regexp_matches(argStr, '([^\s,][-_\.\w\s]*|''[^''\\]*(?:\\''[^''\\]*)*''|"[^"]+"|{[^}]+}|""|'''')', 'g'))[1] str) foo
$$ LANGUAGE sql IMMUTABLE STRICT;
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- TT_ParseRules
--
--  ruleStr text - Rule string to parse into its different components.
--
--  RETURNS TT_RuleDef_old[]
--
-- Parse a rule string into function name, arguments, error code and
-- stopOnInvalid flag.
------------------------------------------------------------
-- DROP FUNCTION IF EXISTS TT_ParseRules_old(text);
CREATE OR REPLACE FUNCTION TT_ParseRules_old(
  ruleStr text DEFAULT NULL,
  targetType text DEFAULT NULL,
  isTranslation boolean DEFAULT FALSE
)
RETURNS TT_RuleDef_old[] AS $$
  DECLARE
    rules text[];
    ruleDef TT_RuleDef_old;
    ruleDefs TT_RuleDef_old[];
  BEGIN
    -- Split the ruleStr into each separate rule: function name, list of arguments, error code and stopOnInvalid flag
    FOR rules IN SELECT regexp_matches(ruleStr, '(\w+)' ||       -- fonction name
                                                '\s*' ||         -- any space
                                                '\(' ||          -- first parenthesis
                                                '([^;|]*)' ||    -- a list of arguments
                                                '\|?\s*' ||      -- a vertical bar followed by any spaces
                                                '([^;,|]+)?' ||  -- the error code
                                                ',?\s*' ||       -- a comma followed by any spaces
                                                '([Ss][Tt][Oo][Pp])?\)'-- STOP or not
                                                , 'g') LOOP
      ruleDef.fctName = rules[1];
      ruleDef.args = TT_ParseArgs(rules[2]);
      ruleDef.errorCode = TT_DefaultProjectErrorCode(CASE WHEN isTranslation THEN 'translation_error' ELSE ruleDef.fctName END, targetType);
      IF upper(rules[3]) = 'STOP' THEN
        ruleDef.stopOnInvalid = TRUE;
      ELSE
        ruleDef.errorCode = coalesce(rules[3], ruleDef.errorCode);
        ruleDef.stopOnInvalid = (NOT upper(rules[4]) IS NULL AND upper(rules[4]) = 'STOP');
      END IF;
      ruleDefs = array_append(ruleDefs, ruleDef);
    END LOOP;
    RETURN ruleDefs;
  END;
$$ LANGUAGE plpgsql IMMUTABLE;

CREATE OR REPLACE FUNCTION TT_ParseRules(
  ruleStr text DEFAULT NULL,
  targetType text DEFAULT NULL,
  isTranslation boolean DEFAULT FALSE
)
RETURNS TT_RuleDef[] AS $$
  DECLARE
    rules text[];
    ruleDef TT_RuleDef;
    ruleDefs TT_RuleDef[];
  BEGIN
    -- Split the ruleStr into each separate rule: function name, list of arguments, error code and stopOnInvalid flag
    FOR rules IN SELECT regexp_matches(ruleStr, '(\w+)' ||       -- fonction name
                                                '\s*' ||         -- any space
                                                '\(' ||          -- first parenthesis
                                                '([^;|]*)' ||    -- a list of arguments
                                                '\|?\s*' ||      -- a vertical bar followed by any spaces
                                                '([^;,|]+)?' ||  -- the error code
                                                ',?\s*' ||       -- a comma followed by any spaces
                                                '([Ss][Tt][Oo][Pp])?\)'-- STOP or not
                                                , 'g') LOOP
      ruleDef.fctName = rules[1];
      ruleDef.args = rules[2];
      ruleDef.errorCode = TT_DefaultProjectErrorCode(CASE WHEN isTranslation THEN 'translation_error' ELSE ruleDef.fctName END, targetType);
      IF upper(rules[3]) = 'STOP' THEN
        ruleDef.stopOnInvalid = TRUE;
      ELSE
        ruleDef.errorCode = coalesce(rules[3], ruleDef.errorCode);
        ruleDef.stopOnInvalid = (NOT upper(rules[4]) IS NULL AND upper(rules[4]) = 'STOP');
      END IF;
      ruleDefs = array_append(ruleDefs, ruleDef);
    END LOOP;
    RETURN ruleDefs;
  END;
$$ LANGUAGE plpgsql IMMUTABLE;
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- TT_ParseJoinFctCall
--
--  fctCall
--
--  RETURNS text[]
--
-- Returns all the parameters of a TT_MatchTable() call.
-- First is the variable to match
-- Second is the schameName of the table
-- Third is the tableName
-- Fourth is the name of the columnName to match
-- Fifth is ignoreCase default to FALSE
-- Sixth is acceptNull as acceptable value (return TRUE)
------------------------------------------------------------
-- DROP FUNCTION IF EXISTS TT_ParseJoinFctCall(text);
CREATE OR REPLACE FUNCTION TT_ParseJoinFctCall(
  fctCall text
)
RETURNS text[] AS $$
-- RETURN TABLE(variable text,
--           schema_name text,
--           table_name text,
--           column_name text,
--           ignore_case boolean
--           accept_null boolean) AS 
  DECLARE
    regex text;
    result text[];
    containsMatchTable boolean = FALSE;
    containsLookup boolean = FALSE;
  BEGIN
--RAISE NOTICE 'fctCall=%', fctCall;
    containsMatchTable = (fctCall ~* 'matchtable\s*\(');
    containsLookup = (fctCall ~* 'lookup(?:text|int|double)\s*\(');

    regex = '(.*)' ||
            --CASE WHEN lookup THEN 'lookup(?:text|int|double)\s*\(' 
            --    ELSE 'matchtable\s*\(' 
            --END || -- fct name
            '(lookup|matchtable)(?:text|int|double)?\s*\(' ||
            '(' || TT_NameRegex() || '|' || TT_AnythingBetweenSingleQuotesRegex() || '|' || TT_OneLevelFctCallRegex() || ')' || -- any attribute name, quoted string or fct call
            --'(' || TT_NameRegex() || ')' || -- any attribute name, quoted string or fct call
            '(?:\s*\,\s*\''(' || TT_NameRegex() || ')\'')' || -- schema name and table name
            '(?:\s*\,\s*\''(' || TT_NameRegex() || ')\'')' || -- schema name and table name
            '(?:\s*\,\s*\''(' || TT_NameRegex() || ')\'')' || -- column name to match
            CASE WHEN containsLookup THEN '(?:\s*\,\s*\''(' || TT_NameRegex() || ')\'')' ELSE '' END ||
            '(?:\s*\,\s*\''?(FALSE|TRUE)\''?)?' || -- ignoreCase
            '(?:\s*\,\s*\''?(TRUE)\''?)?' || -- acceptNull
            '\)(.*)';
--RAISE NOTICE 'regex=%', regex;
    result = regexp_match(fctCall, regex, 'i');

--   variable = result[1];
--   schema_name = result[2];
--   table_name = result[3];
--   column_name = result[4];
--   ignore_case = coalesce(upper(result[5]), 'FALSE')::boolean;
--   accept_null = coalesce(upper(result[6]), 'FALSE')::boolean;
--   IF variable IS NULL OR schema_name IS NULL OR table_name IS NULL OR column_name IS NULL THEN

    IF result[2] IS NULL OR result[3] IS NULL OR result[4] IS NULL OR result[5] IS NULL OR result[6] IS NULL OR (result[2] = 'lookup' AND result[7] IS NULL) THEN
      result[1] = fctCall;
      --RAISE NOTICE 'TT_ParseJoinFctCall() ERROR: Could not parse matchTable() or lookup() rule (%)...', fctCall;
    END IF;
    result[1] = TT_PrepareFctCalls(result[1]); -- preceding string
    result[2] = lower(result[2]);              -- matchtable or lookup
    result[3] = TT_PrepareFctCalls(result[3]); -- value to be matched
    -- 
    IF result[2] = 'lookup' THEN
      result[8] = coalesce(upper(result[8]), 'FALSE')::boolean; -- ignoreCase
      result[9] = coalesce(upper(result[9]), 'FALSE')::boolean; -- acceptNULL
    ELSE
      result[10] = result[9]; -- remaining string
      result[9] = coalesce(upper(result[8]), 'FALSE')::boolean; -- ignoreCase
      result[8] = coalesce(upper(result[7]), 'FALSE')::boolean; -- acceptNULL
      result[7] = NULL; -- retreiveCol
    END IF;
    result[10] = TT_PrepareFctCalls(result[10]); -- remaining string
/*
RAISE NOTICE 'result[1]=%', result[1]; -- string preceding matchTable or lookup
RAISE NOTICE 'result[2]=%', result[2]; -- matchTable or lookup
RAISE NOTICE 'result[3]=%', result[3]; -- 1st argument (value to be matched)
RAISE NOTICE 'result[4]=%', result[4]; -- 2nd argument (schemaName)
RAISE NOTICE 'result[5]=%', result[5]; -- 3rd argument (tableName)
RAISE NOTICE 'result[6]=%', result[6]; -- 4th argument (lookupCol)
RAISE NOTICE 'result[7]=%', result[7]; -- 3rd argument (retreiveCol) (only for lookup calls, NULL otherwise)
RAISE NOTICE 'result[8]=%', result[8]; -- ignoreCase
RAISE NOTICE 'result[9]=%', result[9]; -- accept NULL (only for matchTable calls, NULL otherwise)
RAISE NOTICE 'result[10]=%', result[10]; -- remaining string
*/
    RETURN result;
  END;
$$ LANGUAGE plpgsql IMMUTABLE STRICT;
/*
SELECT unnest(TT_ParseJoinFctCall('matchTable(qc_prg5_species_translation(species_1, ''1''),  ''translation'', ''species_code_mapping'', ''qc_species_codes'', ''TrUE'', ''true'')'));
SELECT unnest(TT_ParseJoinFctCall('matchTable(qc_prg5_species_translation(species_1, ''1''), ''translation'', ''species_code_mapping'', ''qc_species_codes'', TrUE, true)'));
SELECT unnest(TT_ParseJoinFctCall('matchTable(qc_prg5_species_translation(species_1, ''1''), ''translation'', ''species_code_mapping'', ''qc_species_codes'', ''FALSE'', ''TrUE'')'));
SELECT unnest(TT_ParseJoinFctCall('matchTable(qc_prg5_species_translation(species_1, ''1''), ''translation'', ''species_code_mapping'', ''qc_species_codes'', ''TrUE'')'));
SELECT unnest(TT_ParseJoinFctCall('matchTable(qc_prg5_species_translation(species_1, ''1''), ''translation'', ''species_code_mapping'', ''qc_species_codes'')'));
SELECT unnest(TT_ParseJoinFctCall('matchTable(species_1, ''translation'', ''species_code_mapping'', ''ab_species_codes'', TRUE)'))
SELECT unnest(TT_ParseJoinFctCall('matchTable(species_1, ''translation'', ''species_code_mapping'', ''qc_species_codes'')'));
SELECT unnest(TT_ParseJoinFctCall('matchTable(''SP'', ''translation'', ''species_code_mapping'', ''qc_species_codes'')'));
SELECT unnest(TT_ParseJoinFctCall('matchTable(''S''''P'', ''translation'', ''species_code_mapping'', ''qc_species_codes'')'));
SELECT unnest(TT_ParseJoinFctCall('matchTable(species_1, ''translation'', ''species_code_mapping'')'));
SELECT unnest(TT_ParseJoinFctCall('matchTable(species_1, ''translation'', ''species_code_mapping'', ''column_name'')'));
SELECT unnest(TT_ParseJoinFctCall('lookuptext(qc_prg5_species_translation(species_1, ''1''), ''translation'', ''species_code_mapping'', ''qc_species_codes'', ''casfri_species_codes'', ''TrUE'')'));
SELECT unnest(TT_ParseJoinFctCall('lookupText(qc_prg5_species_translation(species_1, 1), ''translation'', ''species_code_mapping'', ''qc_species_codes'', ''casfri_species_codes'')'));
SELECT unnest(TT_ParseJoinFctCall('lookupText(qc_prg5_species_translation(species_1, 1), ''translation'', ''species_code_mapping'', ''qc_species_codes'', ''casfri_species_codes'')'));
SELECT unnest(TT_ParseJoinFctCall('lookupText(subtype, ''translation'', ''mb_fri01_productivity_lookup'', ''source_val'', ''productivity_type'')'));

SELECT unnest(TT_ParseJoinFctCall('fct(matchTable(species_1, ''schema'', ''table'', ''lookupCol'', false, true), arg2, arg3, ''val1'', ''val2'')'));
SELECT unnest(TT_ParseJoinFctCall('fct(matchTable(''SP'', ''schema'', ''table'', ''lookupCol'', false, true), arg2, arg3, ''val1'', ''val2'')'));
SELECT unnest(TT_ParseJoinFctCall('fct(matchTable(''SP'', ''schema'', ''table'', ''lookupCol''), arg2, arg3, ''val1'', ''val2'')'));
SELECT unnest(TT_ParseJoinFctCall('fct(lookUpText(''SP'', ''schema'', ''table'', ''lookupCol'', ''retreiveCol'', true), arg2, arg3, ''val1'', ''val2'')'));

SELECT unnest(TT_ParseJoinFctCall('matchTable(qc_prg5_species_translation(species_1, ''1''), ''translation'', ''species_code_mapping'', ''qc_species_codes'')'));
SELECT unnest(TT_ParseJoinFctCall('matchTable(minIndexCopyText({mod_1_year, mod_2_year},{mod_1,mod_2}),''translation'',''qc_disturbance_lookup'',''source_val'')'));
SELECT unnest(TT_ParseJoinFctCall('matchTable(minIndexCopyText(mod_1_year, mod_2_year,mod_1,mod_2),''translation'',''qc_disturbance_lookup'',''source_val'')'));
SELECT unnest(TT_ParseJoinFctCall('lookupText(minIndexCopyText({mod_1_year, mod_2_year},{mod_1,mod_2}, 9999, 9999),''translation'',''qc_disturbance_lookup'',''source_val'',''dist_type'')'));

SELECT unnest(TT_ParseJoinFctCall('alphaNumericMatchTable(species, ''translation'', ''on_species_valid_alpha_numeric_codes'')'));
*/

-------------------------------------------------------------------------------
-- TT_AppendParsedJoinToArr
--
--  pJoinArr text[][]
--  pJoin text[]
--
--  RETURNS text[]
--
------------------------------------------------------------
-- DROP FUNCTION IF EXISTS TT_AppendParsedJoinToArr(text[][], text[], boolean);
CREATE OR REPLACE FUNCTION TT_AppendParsedJoinToArr(
  pJoinArr text[][],
  pJoin text[],
  whereClause boolean DEFAULT FALSE
)
RETURNS text[][] AS $$
  DECLARE
    currentPJoin text[];
    similarFound boolean = FALSE;
    i int = 1;
  BEGIN
    -- Remove the first element (any string preceding the matchTable of lookup call)
    -- and second element (matchtable or lookup)
    pJoin = pJoin[3:array_length(pJoin, 1)];
--RAISE NOTICE 'TT_AppendParsedJoinToArr() 00 pJoinArr=%', pJoinArr;
    IF pJoinArr IS NULL THEN -- First insertion
      pJoin[8] = '1';
      pJoin[9] = 'last';
      pJoin[10] = '';
      IF whereClause THEN
        pJoin[10] = 'where';
      END IF;
--RAISE NOTICE 'TT_AppendParsedJoinToArr() 11 RETURN=%', ARRAY[pJoin];
      RETURN ARRAY[pJoin];
    ELSE -- Search for an identical join in the join array where retreiveCol is NULL
      FOREACH currentPJoin SLICE 1 IN ARRAY pJoinArr LOOP
--RAISE NOTICE 'TT_AppendParsedJoinToArr() 22 pJoinArr=%', pJoinArr;
        -- Reset 'last'
        pJoinArr[i][9] = '';
        -- Compare only the parameter that affect the LEFT JOIN
        IF currentPJoin[1] = pJoin[1] AND -- value
           currentPJoin[2] = pJoin[2] AND -- schema
           currentPJoin[3] = pJoin[3] AND -- table
           currentPJoin[4] = pJoin[4] AND -- lookupcol
           currentPJoin[6] = pJoin[6] -- ignoreCase
        THEN
          -- Assign the last retrieveCol and the last acceptNull
          pJoinArr[i][5] = coalesce(pJoin[5], pJoinArr[i][5]); -- retrieveCol
          pJoinArr[i][7] = coalesce(pJoin[7], pJoinArr[i][7]); -- acceptNull
          pJoinArr[i][9] = 'last';
          pJoinArr[i][10] = coalesce(pJoin[10], pJoinArr[i][10]); -- 'where'
          IF whereClause THEN
            pJoinArr[i][10] = 'where';
          END IF;
          similarFound = TRUE;
        END IF;
        i = i + 1;
      END LOOP;
    END IF;
    IF similarFound THEN
--RAISE NOTICE 'TT_AppendParsedJoinToArr() 33 pJoinArr=%', pJoinArr;
      RETURN pJoinArr;
    END IF;
    
    -- Nothing found, append the join array at the end
    pJoin[8] = (array_length(pJoinArr, 1) + 1)::text;
    pJoin[9] = 'last';
    pJoin[10] = '';
    IF whereClause THEN
      pJoin[10] = 'where';
    END IF;
--RAISE NOTICE 'TT_AppendParsedJoinToArr() 33 pJoinArr=%', pJoinArr;
    RETURN pJoinArr || pJoin;
  END;
$$ LANGUAGE plpgsql IMMUTABLE;
/*
SELECT ARRAY[ARRAY['a', 'b', 'c', 'd', NULL, 'FALSE', 'FALSE'], ARRAY['e', 'f', 'g', 'h', NULL, 'FALSE', 'FALSE']] 
SELECT TT_AppendParsedJoinToArr(NULL, ARRAY['e', 'f', 'g', 'h', NULL, 'FALSE', 'FALSE'])
SELECT TT_AppendParsedJoinToArr(ARRAY[ARRAY['a', 'b', 'c', 'd', NULL, 'FALSE', 'FALSE', '1', 'last']], ARRAY['e', 'f', 'g', 'h', NULL, 'FALSE', 'FALSE'])
SELECT TT_AppendParsedJoinToArr(ARRAY[ARRAY['a', 'b', 'c', 'd', NULL, 'FALSE', 'FALSE', '1', 'last']], ARRAY['a', 'b', 'c', 'd', 'e', 'FALSE', 'FALSE'])
SELECT TT_AppendParsedJoinToArr(ARRAY[ARRAY['a', 'b', 'c', 'd', NULL, 'FALSE', NULL, '1', 'last']], ARRAY['a', 'b', 'c', 'd', 'e', 'TRUE', 'TRUE'])
SELECT TT_AppendParsedJoinToArr(ARRAY[ARRAY['a', 'b', 'c', 'd', NULL, 'FALSE', NULL, '1', ''], ARRAY['a', 'b', 'c', 'd', NULL, 'FALSE', NULL, '2', 'last']], ARRAY['a', 'b', 'c', 'd', 'e', 'TRUE', 'TRUE'])
*/
-------------------------------------------------------------------------------
-- TT_LastJoinAdded
--
--  pJoinArr text[][]
--
--  RETURNS text[]
------------------------------------------------------------
-- DROP FUNCTION IF EXISTS TT_LastJoinAdded(text[][]);
CREATE OR REPLACE FUNCTION TT_LastJoinAdded(
  pJoinArr text[][]
)
RETURNS text[] AS $$
  DECLARE
    currentPJoin text[];
  BEGIN
    FOREACH currentPJoin SLICE 1 IN ARRAY pJoinArr LOOP
      IF cardinality(currentPJoin) = 10 AND NOT currentPJoin[9] IS NULL AND currentPJoin[9] = 'last' THEN
        return currentPJoin;
      END IF;
    END LOOP;
    -- Return the last one if none is set to 'last'
    RETURN currentPJoin;
  END;
$$ LANGUAGE plpgsql IMMUTABLE STRICT;
/*
SELECT TT_LastJoinAdded(ARRAY[ARRAY['a', 'a', 'a', 'a', NULL, 'FALSE', NULL, '1', ''], ARRAY['b', 'b', 'b', 'b', NULL, 'FALSE', NULL, '2', 'last']])
SELECT TT_LastJoinAdded(ARRAY[ARRAY['a', 'a', 'a', 'a', NULL, 'FALSE', NULL, '1', 'last'], ARRAY['b', 'b', 'b', 'b', NULL, 'FALSE', NULL, '2', '']])

*/
-------------------------------------------------------------------------------
-- TT_ValidateTTable
--
--   translationTableSchema name - Name of the schema containing the translation
--                                 table.
--   translationTable name       - Name of the translation table.
--   validate                    - boolean flag indicating whether translation 
--                               - table attributes should be validated.
--
--   RETURNS boolean             - TRUE if the translation table is valid.
--
-- Parse and validate the translation table. It must fullfil a number of conditions:
--
--   - each of those attribute names should be shorter than 64 charaters and
--     contain no spaces,
--
--   - helper function names should match existing functions and their parameters
--     should be in the right format,
--
--   - there should be no null or empty values in the translation table,
--
--   - the return type of translation rules and the type of the error code should
--     both match the attribute type,
--
--   - target_attribute name should be valid with no special characters
--
--  Return an error and stop the process if any invalid value is found in the
--  translation table.
------------------------------------------------------------
--DROP FUNCTION IF EXISTS TT_ValidateTTable_old(name, name, boolean);
CREATE OR REPLACE FUNCTION TT_ValidateTTable_old(
  translationTableSchema name,
  translationTable name,
  validate boolean DEFAULT TRUE
)
RETURNS TABLE (target_attribute text, 
               target_attribute_type text, 
               validation_rules TT_RuleDef_old[], 
               translation_rule TT_RuleDef_old) AS $$
  DECLARE
    row RECORD;
    query text;
    debug boolean = TT_Debug();
    rule TT_RuleDef_old;
    error_msg_start text = 'ERROR IN TRANSLATION TABLE AT RULE_ID #';
    warning_msg_start text = 'WARNING FOR TRANSLATION TABLE AT RULE_ID #';
  BEGIN
    IF debug THEN RAISE NOTICE 'TT_ValidateTTable BEGIN';END IF;
    IF debug THEN RAISE NOTICE 'TT_ValidateTTable 11';END IF;
    IF translationTable IS NULL OR translationTable = '' THEN
      RETURN;
    END IF;
    IF debug THEN RAISE NOTICE 'TT_ValidateTTable 22';END IF;

    -- loop through each row in the translation table
    query = 'SELECT rule_id::text, 
                    target_attribute::text, 
                    target_attribute_type::text, 
                    validation_rules::text, 
                    translation_rules::text, 
                    description::text, 
                    desc_uptodate_with_rules::text
             FROM ' || TT_FullTableName(translationTableSchema, translationTable) || 
           ' ORDER BY to_number(rule_id::text, ''999999'');';
    IF debug THEN RAISE NOTICE 'TT_ValidateTTable 33 query=%', query;END IF;
    FOR row IN EXECUTE query LOOP
      -- validate attributes and assign values
      target_attribute = row.target_attribute;
      target_attribute_type = row.target_attribute_type;
      validation_rules = (TT_ParseRules_old(row.validation_rules, row.target_attribute_type))::TT_RuleDef_old[];
      translation_rule = ((TT_ParseRules_old(row.translation_rules, row.target_attribute_type, TRUE))[1])::TT_RuleDef_old;
      --description = coalesce(row.description, '');
      --desc_uptodate_with_rules should not be null or empty
      --desc_uptodate_with_rules = (row.desc_uptodate_with_rules)::boolean;

      IF validate THEN
        -- rule_id should be integer, not null, not empty string
        IF debug THEN RAISE NOTICE 'TT_ValidateTTable 44, row=%', row::text;END IF;
        IF NOT TT_NotEmpty(row.rule_id) THEN
          RAISE EXCEPTION 'ERROR IN TRANSLATION TABLE: At least one rule_id is NULL or empty...';
        END IF;
        IF NOT TT_IsInt(row.rule_id) THEN
          RAISE EXCEPTION 'ERROR IN TRANSLATION TABLE: rule_id (%) is not an integer...', row.rule_id;
        END IF;

        -- target_attribute should not be null or empty string, should be word with underscore allowed but no special characters
        IF NOT TT_NotEmpty(row.target_attribute) THEN
          RAISE EXCEPTION '% %: Target attribute is NULL or empty...', error_msg_start, row.rule_id;
        END IF;
        IF NOT TT_IsName(row.target_attribute) THEN -- ~ '^(\d|\w)+$' THEN
          RAISE EXCEPTION '% %: Target attribute name (%) is invalid...', error_msg_start, row.rule_id, row.target_attribute;
        END IF;

        -- target_attribute_type should not be null or empty
        IF debug THEN RAISE NOTICE 'TT_ValidateTTable 55';END IF;
        IF NOT TT_NotEmpty(row.target_attribute_type) THEN
          RAISE EXCEPTION '% % (%): Target attribute type is NULL or empty...', error_msg_start, row.rule_id, row.target_attribute;
        END IF;

        -- validation_rules should not be null or empty
        IF debug THEN RAISE NOTICE 'TT_ValidateTTable 66';END IF;
        IF NOT TT_NotEmpty(row.validation_rules) THEN
          RAISE EXCEPTION '% % (%): Validation rules is NULL or empty...', error_msg_start, row.rule_id, row.target_attribute;
        END IF;

        -- translation_rules should not be null or empty
        IF debug THEN RAISE NOTICE 'TT_ValidateTTable 77';END IF;
        IF NOT TT_NotEmpty(row.translation_rules) THEN
          RAISE EXCEPTION '% % (%): Translation rule is NULL or empty...', error_msg_start, row.rule_id, row.target_attribute;
        END IF;

        -- description should not be null or empty
        IF debug THEN RAISE NOTICE 'TT_ValidateTTable 88';END IF;
        IF NOT TT_NotEmpty(row.description) THEN
          RAISE EXCEPTION '% % (%): Description is NULL or empty...', error_msg_start, row.rule_id, row.target_attribute;
        END IF;
        IF debug THEN RAISE NOTICE 'TT_ValidateTTable 99';END IF;
        IF NOT TT_NotEmpty(row.desc_uptodate_with_rules) THEN
          RAISE EXCEPTION '% % (%): desc_uptodate_with_rules is NULL or empty...', error_msg_start, row.rule_id, row.target_attribute;
        END IF;
        
        -- target_attribute_type should be equal to NA when target_attribute = ROW_TRANSLATION_RULE
        IF row.target_attribute = 'ROW_TRANSLATION_RULE' AND upper(row.target_attribute_type) != 'NA' THEN
          RAISE NOTICE '% % (%): target_attribute_type (%) should be equal to ''NA'' for special target_attribute ROW_TRANSLATION_RULE...', warning_msg_start, row.rule_id, row.target_attribute, row.target_attribute_type;
        END IF;

        IF row.target_attribute = 'ROW_TRANSLATION_RULE' AND upper(row.translation_rules) != 'NA'  THEN
          RAISE NOTICE '% % (%): translation_rules (%) should be equal to ''NA'' for special target_attribute ''ROW_TRANSLATION_RULE''...', warning_msg_start, row.rule_id, row.target_attribute, row.translation_rules;
        END IF;

        IF debug THEN RAISE NOTICE 'TT_ValidateTTable AA';END IF;
        -- Check validation functions exist, error code is not null, and error code can be cast to target attribute type
        FOREACH rule IN ARRAY validation_rules LOOP
          -- Check function exists
          IF debug THEN RAISE NOTICE 'TT_ValidateTTable BB function name: %, arguments: %', rule.fctName, rule.args;END IF;
          IF NOT TT_TextFctExists(rule.fctName, coalesce(cardinality(rule.args), 0)) THEN
            RAISE EXCEPTION '% % (%): Validation helper function ''%(%)'' does not exist...', error_msg_start, row.rule_id, row.target_attribute, rule.fctName, btrim(repeat('text,', coalesce(cardinality(rule.args), 0)), ',');
          END IF;

          -- Check error code is not null
          IF debug THEN RAISE NOTICE 'TT_ValidateTTable CC rule.errorCode: %', rule.errorCode;END IF;
          IF rule.errorCode = '' OR rule.errorCode = 'NO_DEFAULT_ERROR_CODE' THEN
            RAISE EXCEPTION '% % (%): No error code defined for validation rule ''%()''. Define or update your own project TT_DefaultProjectErrorCode() function...', error_msg_start, row.rule_id, row.target_attribute, rule.fctName;
          END IF;

          -- Check error code can be cast to attribute type, catch error with EXCEPTION
          IF debug THEN RAISE NOTICE 'TT_ValidateTTable DD target attribute type: %, error value: %', row.target_attribute_type, rule.errorCode;END IF;
          IF rule.errorCode IS NULL THEN
            RAISE NOTICE '% % (%): Error code for target attribute type (%) and validation rule ''%()'' is NULL.', warning_msg_start, row.rule_id, row.target_attribute, row.target_attribute_type, rule.fctName;
          END IF;
          IF row.target_attribute != 'ROW_TRANSLATION_RULE' AND NOT TT_IsCastableTo(rule.errorCode, row.target_attribute_type) THEN
            RAISE EXCEPTION '% % (%): Error code (%) cannot be cast to the target attribute type (%) for validation rule ''%()''.', error_msg_start, row.rule_id, row.target_attribute, rule.errorCode, row.target_attribute_type, rule.fctName;
          END IF;
        END LOOP;

        -- Validate translation_rule only when for target_attribute other then ROW_TRANSLATION_RULE
        IF row.target_attribute != 'ROW_TRANSLATION_RULE' THEN
          -- check translation function exists
          IF debug THEN RAISE NOTICE 'TT_ValidateTTable FF function name: %, arguments: %', translation_rule.fctName, translation_rule.args;END IF;
          IF NOT TT_TextFctExists(translation_rule.fctName, coalesce(cardinality(translation_rule.args), 0)) THEN
            RAISE EXCEPTION '% % (%): Translation helper function ''%(%)'' does not exist...', error_msg_start, row.rule_id, row.target_attribute, translation_rule.fctName, btrim(repeat('text,', coalesce(cardinality(translation_rule.args), 0)), ',');
          END IF;

          -- Check translation rule return type matches target attribute type
          IF NOT TT_TextFctReturnType(translation_rule.fctName, coalesce(cardinality(translation_rule.args), 0)) = row.target_attribute_type THEN
            RAISE EXCEPTION '% % (%): Translation rule return type (%) does not match translation helper function return type (%)...', error_msg_start, row.rule_id, row.target_attribute, target_attribute_type, TT_TextFctReturnType(translation_rule.fctName, coalesce(cardinality(translation_rule.args), 0));
          END IF;
          IF translation_rule.errorCode IS NULL THEN
            RAISE NOTICE '% % (%): Error code for target attribute type (%) and translation rule ''%()'' is NULL.', warning_msg_start, row.rule_id, row.target_attribute, target_attribute_type, translation_rule.fctName;
          END IF;
          -- If not null, check translation error code can be cast to attribute type
          IF NOT TT_IsCastableTo(translation_rule.errorCode, row.target_attribute_type) THEN
            IF debug THEN RAISE NOTICE 'TT_ValidateTTable GG target attribute type: %, error value: %', row.target_attribute_type, translation_rule.errorCode;END IF;
            RAISE EXCEPTION '% % (%): Error code (%) cannot be cast to the target attribute type (%) for translation rule ''%()''...', error_msg_start, row.rule_id, row.target_attribute, translation_rule.errorCode, row.target_attribute_type, translation_rule.fctName;
          END IF;
        END IF;
      END IF;
      RETURN NEXT;
    END LOOP;
    IF debug THEN RAISE NOTICE 'TT_ValidateTTable END';END IF;
    RETURN;
  END;
$$ LANGUAGE plpgsql STABLE;
------------------------------------------------------------
CREATE OR REPLACE FUNCTION TT_ValidateTTable_old(
  translationTable name,
  validate boolean DEFAULT TRUE
)
RETURNS TABLE (target_attribute text, target_attribute_type text, validation_rules TT_RuleDef_old[], translation_rule TT_RuleDef_old) AS $$
  SELECT TT_ValidateTTable_old('public', translationTable, validate);
$$ LANGUAGE sql STABLE;
-------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION TT_ValidateTTable(
  translationTableSchema name,
  translationTable name,
  validate boolean DEFAULT TRUE
)
RETURNS TABLE (target_attribute text, 
               target_attribute_type text, 
               validation_rules TT_RuleDef[], 
               translation_rule TT_RuleDef) AS $$
  DECLARE
    row RECORD;
    query text;
    debug boolean = TT_Debug();
    rule TT_RuleDef;
    error_msg_start text = 'ERROR IN TRANSLATION TABLE AT RULE_ID #';
    warning_msg_start text = 'WARNING FOR TRANSLATION TABLE AT RULE_ID #';
  BEGIN
    IF debug THEN RAISE NOTICE 'TT_ValidateTTable BEGIN';END IF;
    IF debug THEN RAISE NOTICE 'TT_ValidateTTable 11';END IF;
    IF translationTable IS NULL OR translationTable = '' THEN
      RETURN;
    END IF;
    IF debug THEN RAISE NOTICE 'TT_ValidateTTable 22';END IF;

    -- loop through each row in the translation table
    query = 'SELECT rule_id::text, 
                    target_attribute::text, 
                    target_attribute_type::text, 
                    validation_rules::text, 
                    translation_rules::text, 
                    description::text, 
                    desc_uptodate_with_rules::text
             FROM ' || TT_FullTableName(translationTableSchema, translationTable) || 
           ' ORDER BY to_number(rule_id::text, ''999999'');';
    IF debug THEN RAISE NOTICE 'TT_ValidateTTable 33 query=%', query;END IF;
    FOR row IN EXECUTE query LOOP
      -- validate attributes and assign values
      target_attribute = row.target_attribute;
      target_attribute_type = row.target_attribute_type;
      validation_rules = (TT_ParseRules(row.validation_rules, row.target_attribute_type))::TT_RuleDef[];
      translation_rule = ((TT_ParseRules(row.translation_rules, row.target_attribute_type, TRUE))[1])::TT_RuleDef;
      --description = coalesce(row.description, '');
      --desc_uptodate_with_rules should not be null or empty
      --desc_uptodate_with_rules = (row.desc_uptodate_with_rules)::boolean;

      IF validate THEN
        -- rule_id should be integer, not null, not empty string
        IF debug THEN RAISE NOTICE 'TT_ValidateTTable 44, row=%', row::text;END IF;
        IF NOT TT_NotEmpty(row.rule_id) THEN
          RAISE EXCEPTION 'ERROR IN TRANSLATION TABLE: At least one rule_id is NULL or empty...';
        END IF;
        IF NOT TT_IsInt(row.rule_id) THEN
          RAISE EXCEPTION 'ERROR IN TRANSLATION TABLE: rule_id (%) is not an integer...', row.rule_id;
        END IF;

        -- target_attribute should not be null or empty string, should be word with underscore allowed but no special characters
        IF NOT TT_NotEmpty(row.target_attribute) THEN
          RAISE EXCEPTION '% %: Target attribute is NULL or empty...', error_msg_start, row.rule_id;
        END IF;
        IF NOT TT_IsName(row.target_attribute) THEN -- ~ '^(\d|\w)+$' THEN
          RAISE EXCEPTION '% %: Target attribute name (%) is invalid...', error_msg_start, row.rule_id, row.target_attribute;
        END IF;

        -- target_attribute_type should not be null or empty
        IF debug THEN RAISE NOTICE 'TT_ValidateTTable 55';END IF;
        IF NOT TT_NotEmpty(row.target_attribute_type) THEN
          RAISE EXCEPTION '% % (%): Target attribute type is NULL or empty...', error_msg_start, row.rule_id, row.target_attribute;
        END IF;

        -- validation_rules should not be null or empty
        IF debug THEN RAISE NOTICE 'TT_ValidateTTable 66';END IF;
        IF NOT TT_NotEmpty(row.validation_rules) THEN
          RAISE EXCEPTION '% % (%): Validation rules is NULL or empty...', error_msg_start, row.rule_id, row.target_attribute;
        END IF;

        -- translation_rules should not be null or empty
        IF debug THEN RAISE NOTICE 'TT_ValidateTTable 77';END IF;
        IF NOT TT_NotEmpty(row.translation_rules) THEN
          RAISE EXCEPTION '% % (%): Translation rule is NULL or empty...', error_msg_start, row.rule_id, row.target_attribute;
        END IF;

        -- description should not be null or empty
        IF debug THEN RAISE NOTICE 'TT_ValidateTTable 88';END IF;
        IF NOT TT_NotEmpty(row.description) THEN
          RAISE EXCEPTION '% % (%): Description is NULL or empty...', error_msg_start, row.rule_id, row.target_attribute;
        END IF;
        IF debug THEN RAISE NOTICE 'TT_ValidateTTable 99';END IF;
        IF NOT TT_NotEmpty(row.desc_uptodate_with_rules) THEN
          RAISE EXCEPTION '% % (%): desc_uptodate_with_rules is NULL or empty...', error_msg_start, row.rule_id, row.target_attribute;
        END IF;
        
        -- target_attribute_type should be equal to NA when target_attribute = ROW_TRANSLATION_RULE
        IF row.target_attribute = 'ROW_TRANSLATION_RULE' AND upper(row.target_attribute_type) != 'NA' THEN
          RAISE NOTICE '% % (%): target_attribute_type (%) should be equal to ''NA'' for special target_attribute ROW_TRANSLATION_RULE...', warning_msg_start, row.rule_id, row.target_attribute, row.target_attribute_type;
        END IF;

        IF row.target_attribute = 'ROW_TRANSLATION_RULE' AND upper(row.translation_rules) != 'NA'  THEN
          RAISE NOTICE '% % (%): translation_rules (%) should be equal to ''NA'' for special target_attribute ''ROW_TRANSLATION_RULE''...', warning_msg_start, row.rule_id, row.target_attribute, row.translation_rules;
        END IF;

        IF debug THEN RAISE NOTICE 'TT_ValidateTTable AA';END IF;
        -- Check validation functions exist, error code is not null, and error code can be cast to target attribute type
        FOREACH rule IN ARRAY validation_rules LOOP
          -- Check function exists
          IF debug THEN RAISE NOTICE 'TT_ValidateTTable BB function name: %, arguments: %', rule.fctName, rule.args;END IF;
          --IF NOT TT_TextFctExists(rule.fctName, coalesce(cardinality(rule.args), 0)) THEN
          --  RAISE EXCEPTION '% % (%): Validation helper function ''%(%)'' does not exist...', error_msg_start, row.rule_id, row.target_attribute, rule.fctName, btrim(repeat('text,', coalesce(cardinality(rule.args), 0)), ',');
          --END IF;

          -- Check error code is not null
          IF debug THEN RAISE NOTICE 'TT_ValidateTTable CC rule.errorCode: %', rule.errorCode;END IF;
          IF rule.errorCode = '' OR rule.errorCode = 'NO_DEFAULT_ERROR_CODE' THEN
            RAISE EXCEPTION '% % (%): No error code defined for validation rule ''%()''. Define or update your own project TT_DefaultProjectErrorCode() function...', error_msg_start, row.rule_id, row.target_attribute, rule.fctName;
          END IF;

          -- Check error code can be cast to attribute type, catch error with EXCEPTION
          IF debug THEN RAISE NOTICE 'TT_ValidateTTable CC target attribute type: %, error value: %', row.target_attribute_type, rule.errorCode;END IF;
          IF rule.errorCode IS NULL THEN
            RAISE NOTICE '% % (%): Error code for target attribute type (%) and validation rule ''%()'' is NULL.', warning_msg_start, row.rule_id, row.target_attribute, row.target_attribute_type, rule.fctName;
          END IF;
          IF row.target_attribute != 'ROW_TRANSLATION_RULE' AND NOT TT_IsCastableTo(rule.errorCode, row.target_attribute_type) THEN
            RAISE EXCEPTION '% % (%): Error code (%) cannot be cast to the target attribute type (%) for validation rule ''%()''.', error_msg_start, row.rule_id, row.target_attribute, rule.errorCode, row.target_attribute_type, rule.fctName;
          END IF;
        END LOOP;

        -- Validate translation_rule only when for target_attribute other then ROW_TRANSLATION_RULE
        IF row.target_attribute != 'ROW_TRANSLATION_RULE' THEN
          -- check translation function exists
          IF debug THEN RAISE NOTICE 'TT_ValidateTTable EE function name: %, arguments: %', translation_rule.fctName, translation_rule.args;END IF;
          --IF NOT TT_TextFctExists(translation_rule.fctName, coalesce(cardinality(translation_rule.args), 0)) THEN
          --  RAISE EXCEPTION '% % (%): Translation helper function ''%(%)'' does not exist...', error_msg_start, row.rule_id, row.target_attribute, translation_rule.fctName, btrim(repeat('text,', coalesce(cardinality(translation_rule.args), 0)), ',');
          --END IF;

          -- Check translation rule return type matches target attribute type
          --IF NOT TT_TextFctReturnType(translation_rule.fctName, coalesce(cardinality(translation_rule.args), 0)) = row.target_attribute_type THEN
          --  RAISE EXCEPTION '% % (%): Translation rule return type (%) does not match translation helper function return type (%)...', error_msg_start, row.rule_id, row.target_attribute, target_attribute_type, TT_TextFctReturnType(translation_rule.fctName, coalesce(cardinality(translation_rule.args), 0));
          --END IF;
          IF translation_rule.errorCode IS NULL THEN
            RAISE NOTICE '% % (%): Error code for target attribute type (%) and translation rule ''%()'' is NULL.', warning_msg_start, row.rule_id, row.target_attribute, target_attribute_type, translation_rule.fctName;
          END IF;
          -- If not null, check translation error code can be cast to attribute type
          IF NOT TT_IsCastableTo(translation_rule.errorCode, row.target_attribute_type) THEN
            IF debug THEN RAISE NOTICE 'TT_ValidateTTable FF target attribute type: %, error value: %', row.target_attribute_type, translation_rule.errorCode;END IF;
            RAISE EXCEPTION '% % (%): Error code (%) cannot be cast to the target attribute type (%) for translation rule ''%()''...', error_msg_start, row.rule_id, row.target_attribute, translation_rule.errorCode, row.target_attribute_type, translation_rule.fctName;
          END IF;
        END IF;
      END IF;
      RETURN NEXT;
    END LOOP;
    IF debug THEN RAISE NOTICE 'TT_ValidateTTable END';END IF;
    RETURN;
  END;
$$ LANGUAGE plpgsql STABLE;
------------------------------------------------------------
CREATE OR REPLACE FUNCTION TT_ValidateTTable(
  translationTable name,
  validate boolean DEFAULT TRUE
)
RETURNS TABLE (target_attribute text, target_attribute_type text, validation_rules TT_RuleDef[], translation_rule TT_RuleDef) AS $$
  SELECT TT_ValidateTTable('public', translationTable, validate);
$$ LANGUAGE sql STABLE;
------------------------------------------------------------------------------
-- TT_ReportError
------------------------------------------------------------------------------
--DROP FUNCTION IF EXISTS TT_ReportError(text, name, name, name, text, text, text[], jsonb, text, text, int, text, boolean, boolean);
CREATE OR REPLACE FUNCTION TT_ReportError(
  errorType text,
  translationTableSchema name,
  logTableName name,
  dupLogEntriesHandling text,
  fctName text, 
  args text[], 
  jsonbRow jsonb, 
  targetAttribute text,
  errorCode text,
  currentRowNb int,
  lastFirstRowID text,
  stopOnInvalidLocal boolean,
  stopOnInvalidGlobal boolean
)
RETURNS SETOF RECORD AS $$
  DECLARE
    logMsg text := '';
    localGlobal text;
  BEGIN
     IF errorType IN ('INVALID_PARAMETER', 'INVALID_TRANSLATION_PARAMETER') THEN
       logMsg = logMsg || 'Invalid parameter value passed to rule ''' || TT_TextFctQuery(fctName, args, jsonbRow, FALSE, TRUE) ||
                ''' for attribute ''' || targetAttribute || '''. Revise your translation table...';
       IF errorType = 'INVALID_PARAMETER' THEN
         logMsg = 'STOP ON INVALID PARAMETER: ' ||  logMsg;
       ELSE
         logMsg = 'STOP ON INVALID TRANSLATION PARAMETER: ' ||  logMsg;
       END IF;
       RAISE EXCEPTION '%', logMsg;
     ELSIF errorType IN ('INVALID_VALUE', 'TRANSLATION_ERROR') THEN
       logMsg = 'Rule ''' || TT_TextFctQuery(fctName, args, jsonbRow, FALSE, TRUE) ||
                ''' failed for attribute ''' || targetAttribute || 
                ''' and reported error code ''' || errorCode || '''...';
       IF stopOnInvalidLocal OR stopOnInvalidGlobal THEN
         IF stopOnInvalidLocal THEN
           localGlobal = 'LOCAL';
         ELSE
           localGlobal = 'GLOBAL';
         END IF;
         IF errorType  = 'INVALID_VALUE' THEN
           RAISE EXCEPTION '% STOP ON INVALID SOURCE VALUE at row #%: %', localGlobal, currentRowNb, logMsg;
         ELSE
           RAISE EXCEPTION '% STOP ON TRANSLATION ERROR at row #%: %', localGlobal, currentRowNb, logMsg;
         END IF;
       ELSIF NOT logTableName IS NULL THEN
         PERFORM TT_Log(translationTableSchema, logTableName, dupLogEntriesHandling, 
                        errorType, lastFirstRowID, logMsg, currentRowNb);
       ELSE
         RAISE NOTICE '% at row #%: %', errorType, currentRowNb, logMsg;
       END IF;
     ELSE
       RAISE EXCEPTION 'TT_ReportError() ERROR: Invalid error type...';
     END IF;
  END;
$$ LANGUAGE plpgsql VOLATILE;
------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- TT_Prepare
--
--   translationTableSchema name    - Name of the schema containing the 
--                                    translation table.
--   translationTable name          - Name of the translation table.
--   fctName name                   - Name of the function to create. Default to
--                                    'TT_Translate'.
--   refTranslationTableSchema name - Name of the schema containing the reference 
--                                    translation table.
--   refTranslationTable name       - Name of the reference translation table.
--
--   RETURNS text                - Name of the function created.
--
-- Create the base translation function to execute when tranlating. This
-- function exists in order to palliate the fact that PostgreSQL does not allow
-- creating functions able to return SETOF rows of arbitrary variable types.
-- The function created by this function "freeze" and declare the return type
-- of the actual translation funtion enabling the package to return rows of
-- arbitrary typed rows.
------------------------------------------------------------
--DROP FUNCTION IF EXISTS TT_Prepare_old(name, name, text, name, name);
CREATE OR REPLACE FUNCTION TT_Prepare_old(
  translationTableSchema name,
  translationTable name,
  fctNameSuf text,
  refTranslationTableSchema name,
  refTranslationTable name
)
RETURNS text AS $f$
  DECLARE
    fctQuery text;
    translationQuery text;
		rowTranslationRuleClause text;
		returnQuery text;
    errorCode text;
    translationRow RECORD;
    rule TT_RuleDef_old;
    paramlist text[];
    refParamlist text[];
    i integer;
    fctName text;
  BEGIN
    IF NOT TT_NotEmpty(translationTable) THEN
      RETURN NULL;
    END IF;

    -- Validate the translation table
    PERFORM TT_ValidateTTable_old(translationTableSchema, translationTable);

    -- Build the list of attribute names and types for the target table
    fctQuery = 'SELECT array_agg(target_attribute || '' '' || target_attribute_type ORDER BY rule_id::int) ' ||
            'FROM ' || TT_FullTableName(translationTableSchema, translationTable) || 
           ' WHERE target_attribute != ''ROW_TRANSLATION_RULE'';';
    EXECUTE fctQuery INTO STRICT paramlist;

    IF TT_NotEmpty(refTranslationTableSchema) AND TT_NotEmpty(refTranslationTable) THEN
      -- Build the list of attribute names and types for the reference table
      fctQuery = 'SELECT array_agg(target_attribute || '' '' || target_attribute_type ORDER BY rule_id::int) ' ||
              'FROM ' || TT_FullTableName(refTranslationTableSchema, refTranslationTable) || 
             ' WHERE target_attribute != ''ROW_TRANSLATION_RULE'';';
      EXECUTE fctQuery INTO STRICT refParamlist;

      IF cardinality(paramlist) < cardinality(refParamlist) THEN
        RAISE EXCEPTION 'TT_Prepare() ERROR: Translation table ''%.%'' has less attributes than reference table ''%.%''...', translationTableSchema, translationTable, refTranslationTableSchema, refTranslationTable;
      ELSIF cardinality(paramlist) > cardinality(refParamlist) THEN
        RAISE EXCEPTION 'TT_Prepare() ERROR: Translation table ''%.%'' has more attributes than reference table ''%.%''...', translationTableSchema, translationTable, refTranslationTableSchema, refTranslationTable;
      ELSIF TT_LowerArr(paramlist) != TT_LowerArr(refParamlist) THEN
        FOR i IN 1..cardinality(paramlist) LOOP
          IF paramlist[i] != refParamlist[i] THEN
            RAISE EXCEPTION 'TT_Prepare() ERROR: Translation table ''%.%'' attribute ''%'' is different from reference table ''%.%'' attribute ''%''...', translationTableSchema, translationTable, paramlist[i], refTranslationTableSchema, refTranslationTable, refParamlist[i];
          END IF;
        END LOOP;
      END IF;
    END IF;

    -- Drop any existing TT_Translate function with the same suffix
    fctName = 'TT_Translate' || coalesce(fctNameSuf, '');
    fctQuery = 'DROP FUNCTION IF EXISTS ' || fctName || '(name, name, name, boolean, boolean, text, int, boolean, boolean, boolean);';
    EXECUTE fctQuery;
    
    -- Build the translation query
    translationQuery = 'SELECT ' || CHR(10);
		rowTranslationRuleClause = 'WHERE ';
		FOR translationRow IN SELECT * FROM TT_ValidateTTable_old(translationTableSchema, translationTable, FALSE)
    LOOP
      IF translationRow.target_attribute != 'ROW_TRANSLATION_RULE' THEN
        translationQuery = translationQuery || '  CASE ' || CHR(10);
      END IF;
		  -- Build the validation part and the ROW_TRANSLATION_RULE part at the same time
      FOREACH rule IN ARRAY translationRow.validation_rules 
			LOOP
			  IF translationRow.target_attribute = 'ROW_TRANSLATION_RULE' THEN
          rowTranslationRuleClause = rowTranslationRuleClause || TT_RuleToSQL(rule.fctName, rule.args) || ' OR ' || CHR(10);
				ELSE
          -- Determine validation error code
          errorCode = coalesce(rule.errorCode, coalesce(TT_DefaultProjectErrorCode(rule.fctName, translationRow.target_attribute_type), 'NULL'));
          -- Single quote error code for text types
          IF translationRow.target_attribute_type IN ('text', 'char', 'character', 'varchar', 'character varying') OR 
             (translationRow.target_attribute_type = 'geometry' AND errorCode != 'NULL') THEN
            errorCode = '''' || errorCode || '''';
          END IF;
          translationQuery = translationQuery || '    WHEN NOT ' || TT_RuleToSQL(rule.fctName, rule.args) || ' THEN ' || errorCode || CHR(10);
	      END IF;
		  END LOOP; -- FOREACH rule

		  -- Build the translation part
      IF translationRow.target_attribute != 'ROW_TRANSLATION_RULE' THEN
        -- Determine translation error code
        errorCode = CASE WHEN translationRow.target_attribute_type IN ('boolean', 'geometry') 
                           THEN coalesce((translationRow.translation_rule).errorCode, 'NULL')
                         WHEN translationRow.target_attribute_type IN ('text', 'char', 'character', 'varchar', 'character varying') 
                            THEN coalesce('''' || (translationRow.translation_rule).errorCode || '''', '''TRANSLATION_ERROR''')
                         ELSE  coalesce((translationRow.translation_rule).errorCode, '-3333')
										END;

        translationQuery = translationQuery || '    ELSE coalesce(' || 
			                     TT_RuleToSQL((translationRow.translation_rule).fctName, (translationRow.translation_rule).args) || 
												   ', ' || errorCode || '::' || translationRow.target_attribute_type || ') ' || CHR(10) || 
												   '  END::' || lower(translationRow.target_attribute_type) || ' ' || lower(translationRow.target_attribute) || ',' || CHR(10);
      END IF;
    END LOOP; -- FOR TRANSLATION ROW
		-- Remove the last comma from translationQuery and complete
		translationQuery = left(translationQuery, char_length(translationQuery) - 2);

		-- Remove the last 'OR' from rowTranslationRuleClause
		IF rowTranslationRuleClause = 'WHERE ' THEN
		   rowTranslationRuleClause = '';
		ELSE
      rowTranslationRuleClause = left(rowTranslationRuleClause, char_length(rowTranslationRuleClause) - 5);
    END IF;

RAISE NOTICE '%', translationQuery || CHR(10) || 'FROM sourceTableSchema.sourceTable' || CHR(10) || rowTranslationRuleClause || ';';

    fctQuery = 'CREATE OR REPLACE FUNCTION ' || fctName || '(
                  sourceTableSchema name,
                  sourceTable name)
                RETURNS TABLE (' || array_to_string(paramlist, ', ') || ') AS $$
                  BEGIN
                   RETURN QUERY SELECT * FROM _TT_Translate('''  || fctName || ''',' ||
                                                                 quote_literal(translationQuery) || ', ' ||
                                                                 quote_literal(rowTranslationRuleClause) || ', 
                                                                 sourceTableSchema,
                                                                 sourceTable, ' ||
                                                         '''' || translationTableSchema || ''', ' ||
                                                         '''' || translationTable || ''') AS t(' || array_to_string(paramlist, ', ') || ');
               RETURN;
             END;
             $$ LANGUAGE plpgsql VOLATILE;';
    EXECUTE fctQuery;

    RETURN 'SELECT * FROM TT_Translate' || coalesce(fctNameSuf, '') || '(''schemaName'', ''tableName'');';
  END;
$f$ LANGUAGE plpgsql VOLATILE;

------------------------------------------------------------
--DROP FUNCTION IF EXISTS TT_Prepare_old(name, name, text, name);
CREATE OR REPLACE FUNCTION TT_Prepare_old(
  translationTableSchema name,
  translationTable name,
  fctNameSuf text,
  refTranslationTable name
)
RETURNS text AS $$
  SELECT TT_Prepare_old(translationTableSchema, translationTable, fctNameSuf, translationTableSchema, refTranslationTable);
$$ LANGUAGE sql VOLATILE;
------------------------------------------------------------
--DROP FUNCTION IF EXISTS TT_Prepare_old(name, name, text);
CREATE OR REPLACE FUNCTION TT_Prepare_old(
  translationTableSchema name,
  translationTable name,
  fctNameSuf text
)
RETURNS text AS $$
  SELECT TT_Prepare_old(translationTableSchema, translationTable, fctNameSuf, NULL::name, NULL::name);
$$ LANGUAGE sql VOLATILE;
------------------------------------------------------------
--DROP FUNCTION IF EXISTS TT_Prepare_old(name, name);
CREATE OR REPLACE FUNCTION TT_Prepare_old(
  translationTableSchema name,
  translationTable name
)
RETURNS text AS $$
  SELECT TT_Prepare_old(translationTableSchema, translationTable, NULL, NULL::name, NULL::name);
$$ LANGUAGE sql VOLATILE;
------------------------------------------------------------
CREATE OR REPLACE FUNCTION TT_Prepare_old(
  translationTable name
)
RETURNS text AS $$
  SELECT TT_Prepare_old('public', translationTable, NULL::text, NULL::name, NULL::name);
$$ LANGUAGE sql VOLATILE;
------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- DROP FUNCTION IF EXISTS TT_BuildJoinExpr(text, text[][], text, text, boolean, text);
CREATE OR REPLACE FUNCTION TT_BuildJoinExpr(
  precedingStr text,
  leftJoinArr text[][],
  followingStr text,
  errorCode text,
  matchTable boolean DEFAULT TRUE,
  part text DEFAULT 'validation'
)
RETURNS text AS $$
  DECLARE
    joinExpr text;
    lastJoinArr text[];
  BEGIN
    -- leftJoinArr[1] -- value
    -- leftJoinArr[2] -- schema
    -- leftJoinArr[3] -- table
    -- leftJoinArr[4] -- lookupCol
    -- leftJoinArr[5] -- retreiveCol
    -- leftJoinArr[6] -- ignoreCase
    -- leftJoinArr[7] -- acceptNull
    -- leftJoinArr[8] -- index
    -- leftJoinArr[9] -- last or not
    lastJoinArr = TT_LastJoinAdded(leftJoinArr);
--RAISE NOTICE 'lastJoinArr=%', lastJoinArr;
--RAISE NOTICE 'matchTable=%', matchTable;
--RAISE NOTICE 'part=%', part;
    IF lastJoinArr IS NULL THEN
      RETURN '';
    END IF;
    precedingStr = coalesce(precedingStr, '');
    followingStr = coalesce(followingStr, '');
    -- Handle matchTable and lookup function calls in validation rules
    IF part = 'validation' OR part = 'whereclause' THEN
      joinExpr = -- Add the WHEN part when in a validation
                 CASE WHEN part = 'validation' THEN '    WHEN (' 
                      ELSE '' 
                 END ||
                 -- if acceptNull (7) test only if NOT NULL
                 CASE WHEN lastJoinArr[7]::boolean THEN 'NOT (' || lastJoinArr[1] || ') IS NULL AND ' 
                      ELSE '' 
                 END || 
                 CASE WHEN (precedingStr != '' AND part != 'whereclause') OR 
                           (precedingStr = '' AND part = 'whereclause') THEN 'NOT '
                      ELSE ''
                 END ||
                 -- Prepend boolean external function
                 CASE WHEN precedingStr != '' THEN precedingStr 
                      ELSE ''
                 END ||
                 'join_' || lastJoinArr[8] || '.' || 
                 -- Append the lookupCol or retreiveCol attribute
                 CASE WHEN matchTable THEN lastJoinArr[4] 
                      ELSE lastJoinArr[5]
                 END || 
                 -- Append boolean external function arguments
                 CASE WHEN followingStr != '' THEN followingStr 
                      ELSE ' IS NULL' 
                 END || 
                 -- Append errorCode
                 CASE WHEN part = 'validation' THEN ') THEN ' || errorCode  || CHR(10)
                      ELSE ''
                 END;
    -- Handle lookup function calls in translation rules
    ELSE
      joinExpr = precedingStr || 
                 'join_'  || lastJoinArr[8] || '.' || 
                 -- Append the lookupCol or retreiveCol attribute
                 CASE WHEN matchTable THEN lastJoinArr[4] 
                      ELSE lastJoinArr[5]
                 END || 
                 followingStr;
    END IF;
    RETURN joinExpr;
  END;
$$ LANGUAGE plpgsql VOLATILE;
/*
matchTable
SELECT TT_BuildJoinExpr(NULL, ARRAY[ARRAY['value', 'schemaName', 'tableName', 'lookupCol', NULL::text, FALSE::text, FALSE::text, '1', 'last']], NULL, 'NOT_IN_SET');
SELECT TT_BuildJoinExpr('', ARRAY[ARRAY['value', 'schemaName', 'tableName', 'lookupCol', NULL::text, FALSE::text, FALSE::text, '1', 'last']], '', 'NOT_IN_SET');
SELECT TT_BuildJoinExpr('fct(', ARRAY[ARRAY['value', 'schemaName', 'tableName', 'lookupCol', NULL::text, FALSE::text, FALSE::text, '1', 'last']], ', arg2, arg3)', 'NOT_IN_SET');
SELECT TT_BuildJoinExpr('fct(', ARRAY[ARRAY['value', 'schemaName', 'tableName', 'lookupCol', NULL::text, FALSE::text, TRUE::text, '1', 'last']], ', arg2, arg3)', 'NOT_IN_SET');

lookup in validation rule
SELECT TT_BuildJoinExpr(NULL,   ARRAY[ARRAY['value', 'schemaName', 'tableName', 'lookupCol', 'retreiveCol', FALSE::text, FALSE::text, '1', 'last']], NULL, 'NOT_IN_SET', FALSE, 'validation');
SELECT TT_BuildJoinExpr('fct(', ARRAY[ARRAY['value', 'schemaName', 'tableName', 'lookupCol', 'retreiveCol', FALSE::text, TRUE::text, '1', 'last']], ', arg2, arg3)', 'NOT_IN_SET', FALSE, 'validation');

lookup in translation rule
SELECT TT_BuildJoinExpr(NULL,   ARRAY[ARRAY['value', 'schemaName', 'tableName', 'lookupCol', 'retreiveCol', FALSE::text, FALSE::text, '1', 'last']], NULL, 'NOT_IN_SET', FALSE, 'translation');
SELECT TT_BuildJoinExpr('fct(', ARRAY[ARRAY['value', 'schemaName', 'tableName', 'lookupCol', 'retreiveCol', FALSE::text, TRUE::text, '1', 'last']], ', arg2, arg3)', 'NOT_IN_SET', FALSE, 'translation');

lookup in whereclause
SELECT TT_BuildJoinExpr(NULL,   ARRAY[ARRAY['value', 'schemaName', 'tableName', 'lookupCol', 'retreiveCol', FALSE::text, FALSE::text, '1', 'last']], NULL, 'NOT_IN_SET', FALSE, 'whereclause');
SELECT TT_BuildJoinExpr(NULL,   ARRAY[ARRAY['value', 'schemaName', 'tableName', 'lookupCol', 'retreiveCol', FALSE::text, TRUE::text, '1', 'last']], NULL, 'NOT_IN_SET', FALSE, 'whereclause');
SELECT TT_BuildJoinExpr('fct(', ARRAY[ARRAY['value', 'schemaName', 'tableName', 'lookupCol', 'retreiveCol', FALSE::text, TRUE::text, '1', 'last']], ', arg2, arg3)', 'NOT_IN_SET', FALSE, 'whereclause');

matchTable in whereclause
SELECT TT_BuildJoinExpr(NULL,   ARRAY[ARRAY['value', 'schemaName', 'tableName', 'lookupCol', 'retreiveCol', FALSE::text, FALSE::text, '1', 'last']], NULL, 'NOT_IN_SET', TRUE, 'whereclause');
SELECT TT_BuildJoinExpr('',   ARRAY[ARRAY['value', 'schemaName', 'tableName', 'lookupCol', 'retreiveCol', FALSE::text, FALSE::text, '1', 'last']], NULL, 'NOT_IN_SET', TRUE, 'whereclause');
SELECT TT_BuildJoinExpr('fct(', ARRAY[ARRAY['value', 'schemaName', 'tableName', 'lookupCol', 'retreiveCol', FALSE::text, TRUE::text, '1', 'last']], ', arg2, arg3)', 'NOT_IN_SET', TRUE, 'whereclause');

*/
------------------------------------------------------------------------------
--DROP FUNCTION IF EXISTS TT_Prepare(name, name, text, name, name);
CREATE OR REPLACE FUNCTION TT_Prepare(
  translationTableSchema name,
  translationTable name,
  fctNameSuf text,
  refTranslationTableSchema name,
  refTranslationTable name
)
RETURNS text AS $f$
  DECLARE
    fctQuery text;
    translationQuery text;
		rowTranslationRuleClause text;
    newClause text;
    leftJoinArr text[][];
    whereLeftJoinArr text[][];
    currentJoinArr text[];
    leftJoinClause text = '';
    whereLeftJoinClause text = '';
		returnQuery text;
    errorCode text;
    translationRow RECORD;
    rule TT_RuleDef;
    paramlist text[];
    refParamlist text[];
    i integer;
    fctName text;
    fullRule text;
  BEGIN
    IF NOT TT_NotEmpty(translationTable) THEN
      RETURN NULL;
    END IF;

    -- Validate the translation table
    PERFORM TT_ValidateTTable(translationTableSchema, translationTable);

    -- Build the list of attribute names and types for the target table
    fctQuery = 'SELECT array_agg(target_attribute || '' '' || target_attribute_type ORDER BY rule_id::int) ' ||
            'FROM ' || TT_FullTableName(translationTableSchema, translationTable) || 
           ' WHERE target_attribute != ''ROW_TRANSLATION_RULE'';';
    EXECUTE fctQuery INTO STRICT paramlist;

    -- Compare the list of target attribute with the reference table if it is provided
    IF TT_NotEmpty(refTranslationTableSchema) AND TT_NotEmpty(refTranslationTable) THEN
      -- Build the list of attribute names and types for the reference table
      fctQuery = 'SELECT array_agg(target_attribute || '' '' || target_attribute_type ORDER BY rule_id::int) ' ||
              'FROM ' || TT_FullTableName(refTranslationTableSchema, refTranslationTable) || 
             ' WHERE target_attribute != ''ROW_TRANSLATION_RULE'';';
      EXECUTE fctQuery INTO STRICT refParamlist;

      -- Compare the lists
      IF cardinality(paramlist) < cardinality(refParamlist) THEN
        RAISE EXCEPTION 'TT_Prepare() ERROR: Translation table ''%.%'' has less attributes than reference table ''%.%''...', translationTableSchema, translationTable, refTranslationTableSchema, refTranslationTable;
      ELSIF cardinality(paramlist) > cardinality(refParamlist) THEN
        RAISE EXCEPTION 'TT_Prepare() ERROR: Translation table ''%.%'' has more attributes than reference table ''%.%''...', translationTableSchema, translationTable, refTranslationTableSchema, refTranslationTable;
      ELSIF TT_LowerArr(paramlist) != TT_LowerArr(refParamlist) THEN
        FOR i IN 1..cardinality(paramlist) LOOP
          IF paramlist[i] != refParamlist[i] THEN
            RAISE EXCEPTION 'TT_Prepare() ERROR: Translation table ''%.%'' attribute ''%'' is different from reference table ''%.%'' attribute ''%''...', translationTableSchema, translationTable, paramlist[i], refTranslationTableSchema, refTranslationTable, refParamlist[i];
          END IF;
        END LOOP;
      END IF;
    END IF;

    -- Drop any existing TT_Translate function with the same suffix
    fctName = 'TT_Translate' || coalesce(fctNameSuf, '');
    fctQuery = 'DROP FUNCTION IF EXISTS ' || fctName || '(name, name);';
    EXECUTE fctQuery;
    
    -- Build the translation query
    translationQuery = 'SELECT ' || CHR(10);
		rowTranslationRuleClause = 'WHERE ';
		FOR translationRow IN SELECT * FROM TT_ValidateTTable(translationTableSchema, translationTable, FALSE)
    LOOP
      IF translationRow.target_attribute != 'ROW_TRANSLATION_RULE' THEN
        translationQuery = translationQuery || '  CASE ' || CHR(10);
      END IF;
		  -- Build the validation part and the ROW_TRANSLATION_RULE part at the same time
      FOREACH rule IN ARRAY translationRow.validation_rules 
			LOOP
        fullRule = rule.fctName || '(' || rule.args || ')';

        -- Parse the rule to find matchtable or lookup and their parameters
        currentJoinArr = TT_ParseJoinFctCall(fullRule);

			  IF translationRow.target_attribute = 'ROW_TRANSLATION_RULE' THEN
          IF currentJoinArr[2] IS NULL THEN
            rowTranslationRuleClause = rowTranslationRuleClause || TT_PrepareFctCalls(fullRule);
          ELSE
            leftJoinArr = TT_AppendParsedJoinToArr(leftJoinArr, currentJoinArr, TRUE);
            rowTranslationRuleClause = rowTranslationRuleClause || 
                                       TT_BuildJoinExpr(currentJoinArr[1], leftJoinArr, currentJoinArr[10], NULL, (currentJoinArr[2] = 'matchtable'), 'whereclause');
          END IF;
          rowTranslationRuleClause = rowTranslationRuleClause || ' OR ' || CHR(10);
				ELSE
          -- Determine validation error code
          errorCode = coalesce(rule.errorCode, coalesce(TT_DefaultProjectErrorCode(rule.fctName, translationRow.target_attribute_type), 'NULL'));
          -- Single quote error code for text types
          IF translationRow.target_attribute_type IN ('text', 'char', 'character', 'varchar', 'character varying') OR 
             (translationRow.target_attribute_type = 'geometry' AND errorCode != 'NULL') THEN
            errorCode = '''' || errorCode || '''';
          END IF;

          -- If not matchtable nor lookup
          IF currentJoinArr[2] IS NULL THEN
            translationQuery = translationQuery || '    WHEN NOT ' || 
                               currentJoinArr[1] || ' THEN ' || errorCode || CHR(10);
          ELSE
            leftJoinArr = TT_AppendParsedJoinToArr(leftJoinArr, currentJoinArr);
            translationQuery = translationQuery || TT_BuildJoinExpr(currentJoinArr[1], leftJoinArr, currentJoinArr[10], errorCode, (currentJoinArr[2] = 'matchtable'), 'validation');
	        END IF;
	      END IF;
		  END LOOP; -- FOREACH rule

      -- Build the translation part
      IF translationRow.target_attribute != 'ROW_TRANSLATION_RULE' THEN
        -- Determine translation error code
        errorCode = CASE WHEN translationRow.target_attribute_type IN ('boolean', 'geometry') 
                           THEN coalesce((translationRow.translation_rule).errorCode, 'NULL')
                         WHEN translationRow.target_attribute_type IN ('text', 'char', 'character', 'varchar', 'character varying') 
                            THEN coalesce('''' || (translationRow.translation_rule).errorCode || '''', '''TRANSLATION_ERROR''')
                         ELSE  coalesce((translationRow.translation_rule).errorCode, '-3333')
										END;

        fullRule = (translationRow.translation_rule).fctName || '(' || (translationRow.translation_rule).args || ')';

        -- Parse the rule to find matchtable or lookup and their parameters
        currentJoinArr = TT_ParseJoinFctCall(fullRule);

        translationQuery = translationQuery || '    ELSE coalesce((';
        -- If the rule does not contain matchtable nor lookup
        IF currentJoinArr[2] IS NULL THEN
          translationQuery = translationQuery || TT_PrepareFctCalls(fullRule);
        ELSE
          leftJoinArr = TT_AppendParsedJoinToArr(leftJoinArr, currentJoinArr);
          translationQuery = translationQuery || TT_BuildJoinExpr(currentJoinArr[1], leftJoinArr, currentJoinArr[10], errorCode, (currentJoinArr[2] = 'matchtable'), 'translation');
        END IF;
        translationQuery = translationQuery || ')::' || translationRow.target_attribute_type || ', (' || errorCode || ')::' || translationRow.target_attribute_type || ') ' || CHR(10) || 
												     '  END::' || lower(translationRow.target_attribute_type) || ' ' || lower(translationRow.target_attribute) || ',' || CHR(10);
      END IF;
    END LOOP; -- FOR TRANSLATION ROW

    -- Remove the last comma from translationQuery and complete
		translationQuery = left(translationQuery, char_length(translationQuery) - 2);
    
		-- Erase rowTranslationRuleClause or simply erase the last 'OR' from it
		IF rowTranslationRuleClause = 'WHERE ' THEN
		  rowTranslationRuleClause = ';';
		ELSE
      rowTranslationRuleClause = left(rowTranslationRuleClause, char_length(rowTranslationRuleClause) - 5) || ';';
    END IF;

    -- Generate LEFT JOINs clause
    IF NOT leftJoinArr IS NULL THEN
      FOREACH currentJoinArr SLICE 1 IN ARRAY leftJoinArr LOOP
         newClause = 'LEFT JOIN ' || TT_FullTableName(currentJoinArr[2], currentJoinArr[3]) || ' join_' || currentJoinArr[8] || 
                     ' ON (TT_NotEmpty(' || currentJoinArr[1] || ') AND ' || 
                     --' ON (' || 
                     CASE WHEN currentJoinArr[6]::boolean THEN 'lower' 
                          ELSE '' 
                     END || '(' || currentJoinArr[1] || ') = ' || 
                     CASE WHEN currentJoinArr[6]::boolean THEN 'lower' 
                          ELSE '' 
                     END || '(' || 'join_' || currentJoinArr[8] || '.' || currentJoinArr[4] || '))' || CHR(10);
        leftJoinClause = leftJoinClause || newClause;
        -- Generate WHERE LEFT JOINs clause for future counting purpose
        IF currentJoinArr[10] = 'where' THEN
          whereLeftJoinClause = whereLeftJoinClause || newClause;
        END IF;
      END LOOP;
    END IF;

    RAISE NOTICE 'translationQuery=%', translationQuery || CHR(10) || 
                                       'FROM sourceTableSchema.sourceTable maintable ' || CHR(10) || 
                                       leftJoinClause || 
                                       rowTranslationRuleClause || CHR(10);

    translationQuery = TT_EscapeSingleQuotes(translationQuery) || CHR(10) || 
                       'FROM '' || TT_FullTableName(sourceTableSchema, sourceTable) || '' maintable ' || CHR(10) || 
                       TT_EscapeSingleQuotes(leftJoinClause) || 
                       TT_EscapeSingleQuotes(rowTranslationRuleClause);

    RAISE NOTICE 'rowTranslationRuleClause=%', whereLeftJoinClause  || 
                                               rowTranslationRuleClause;
    
    rowTranslationRuleClause = TT_EscapeSingleQuotes(whereLeftJoinClause) || 
                               TT_EscapeSingleQuotes(rowTranslationRuleClause);

    fctQuery = 'CREATE OR REPLACE FUNCTION ' || fctName || '(
                  sourceTableSchema name,
                  sourceTable name)
                RETURNS TABLE (' || array_to_string(paramlist, ', ') || ') AS $$
                  SELECT * FROM TT_ShowProgress('''  || fctName || ''', ' ||
                                                ''''  || translationQuery || ''', ' ||
                                                ''''  || rowTranslationRuleClause || ''', 
                                                sourceTableSchema,
                                                sourceTable) AS t(' || array_to_string(paramlist, ', ') || ');
              $$ LANGUAGE sql VOLATILE;';
    EXECUTE fctQuery;
    RETURN 'SELECT * FROM TT_Translate' || coalesce(fctNameSuf, '') || '(''schemaName'', ''tableName'');';
  END;
$f$ LANGUAGE plpgsql VOLATILE;

------------------------------------------------------------
--DROP FUNCTION IF EXISTS TT_Prepare(name, name, text, name);
CREATE OR REPLACE FUNCTION TT_Prepare(
  translationTableSchema name,
  translationTable name,
  fctNameSuf text,
  refTranslationTable name
)
RETURNS text AS $$
  SELECT TT_Prepare(translationTableSchema, translationTable, fctNameSuf, translationTableSchema, refTranslationTable);
$$ LANGUAGE sql VOLATILE;
------------------------------------------------------------
--DROP FUNCTION IF EXISTS TT_Prepare(name, name, text);
CREATE OR REPLACE FUNCTION TT_Prepare(
  translationTableSchema name,
  translationTable name,
  fctNameSuf text
)
RETURNS text AS $$
  SELECT TT_Prepare(translationTableSchema, translationTable, fctNameSuf, NULL::name, NULL::name);
$$ LANGUAGE sql VOLATILE;
------------------------------------------------------------
--DROP FUNCTION IF EXISTS TT_Prepare(name, name);
CREATE OR REPLACE FUNCTION TT_Prepare(
  translationTableSchema name,
  translationTable name
)
RETURNS text AS $$
  SELECT TT_Prepare(translationTableSchema, translationTable, NULL, NULL::name, NULL::name);
$$ LANGUAGE sql VOLATILE;
------------------------------------------------------------
CREATE OR REPLACE FUNCTION TT_Prepare(
  translationTable name
)
RETURNS text AS $$
  SELECT TT_Prepare('public', translationTable, NULL::text, NULL::name, NULL::name);
$$ LANGUAGE sql VOLATILE;
------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- TT_ShowProgress
--
--   sourceTableSchema name      - Name of the schema containing the source table.
--   sourceTable name            - Name of the source table.
--   translationTableSchema name - Name of the schema containing the translation
--                                 table.
--   translationTable name       - Name of the translation table.
--   RETURNS SETOF RECORDS
--
-- Translate a source table according to the rules defined in a tranlation table.
------------------------------------------------------------
--DROP FUNCTION IF EXISTS TT_ShowProgress(text, text, name, name, name, name);
CREATE OR REPLACE FUNCTION TT_ShowProgress(
  callingFctName name,
  translationQuery text,
  rowTranslationRuleClause text,
  sourceTableSchema name,
  sourceTable name
)
RETURNS SETOF RECORD AS $$
  DECLARE
    translatedRow RECORD;
    currentRowNb int = 1;
    debug boolean = TT_Debug();
    startTime timestamptz;
    percentDone numeric;
    remainingTime double precision;
    elapsedTime double precision;
    countTime double precision;
    analyseTime double precision;
    expectedRowNb int;
    countQuery text;
  BEGIN
    IF debug THEN RAISE NOTICE 'DEBUG ACTIVATED...';END IF;
    IF debug THEN RAISE NOTICE 'TT_ShowProgress BEGIN';END IF;

    -- Estimate the number of rows to return
    countQuery = 'SELECT count(*) FROM ' || TT_FullTableName(sourceTableSchema, sourceTable) || ' maintable' || CHR(10) || rowTranslationRuleClause;

    RAISE NOTICE 'Counting the number of rows to translate... (%)', countQuery;
    startTime = clock_timestamp();
    EXECUTE countQuery INTO expectedRowNb;
    RAISE NOTICE '% ROWS TO TRANSLATE. Preprocessing query...', expectedRowNb;
    countTime = EXTRACT(EPOCH FROM clock_timestamp() - startTime);
    startTime = clock_timestamp();

    -- Main loop
		FOR translatedRow IN EXECUTE translationQuery
    LOOP
      IF currentRowNb = 1 THEN
        analyseTime = EXTRACT(EPOCH FROM clock_timestamp() - startTime);
        startTime = clock_timestamp();
      END IF;
      IF currentRowNb % 100 = 0 THEN
        percentDone = currentRowNb::numeric/expectedRowNb * 100;
        elapsedTime = EXTRACT(EPOCH FROM clock_timestamp() - startTime);
        remainingTime = ((100 - percentDone) * elapsedTime)/percentDone;
        RAISE NOTICE '%(%): %/% rows translated (% %%) - % elapsed, % remaining...', callingFctName, sourceTable, currentRowNb, expectedRowNb, round(percentDone, 3), 
             TT_PrettyDuration(elapsedTime, 3), TT_PrettyDuration(remainingTime, 3);
      END IF;
      currentRowNb = currentRowNb + 1;
			RETURN NEXT translatedRow;
    END LOOP;
    elapsedTime = EXTRACT(EPOCH FROM clock_timestamp() - startTime);

    RAISE NOTICE 'TOTAL TIME COUNTING ROWS: %', TT_PrettyDuration(countTime, 4);
    RAISE NOTICE 'TOTAL TIME ANALYING QUERY: %', TT_PrettyDuration(coalesce(analyseTime, EXTRACT(EPOCH FROM clock_timestamp() - startTime)), 4);
    RAISE NOTICE 'TOTAL TIME PROCESSING QUERY: %', TT_PrettyDuration(EXTRACT(EPOCH FROM clock_timestamp() - coalesce(startTime, now())), 4);
    IF currentRowNb > 1 THEN
      RAISE NOTICE 'MEAN TIME PER ROW: %', TT_PrettyDuration(EXTRACT(EPOCH FROM clock_timestamp() - coalesce(startTime, clock_timestamp()))/currentRowNb, 6);
    END IF;
    RETURN;
  END;
$$ LANGUAGE plpgsql VOLATILE;
------------------------------------------------------------------------------
-- _TT_Translate
--
--   sourceTableSchema name      - Name of the schema containing the source table.
--   sourceTable name            - Name of the source table.
--   translationTableSchema name - Name of the schema containing the translation
--                                 table.
--   translationTable name       - Name of the translation table.
--   RETURNS SETOF RECORDS
--
-- Translate a source table according to the rules defined in a tranlation table.
------------------------------------------------------------
--DROP FUNCTION IF EXISTS _TT_Translate(name, text, text, name, name, name, name);
CREATE OR REPLACE FUNCTION _TT_Translate(
  callingFctName name,
  translationQuery text,
  rowTranslationRuleClause text,
  sourceTableSchema name,
  sourceTable name,
  translationTableSchema name,
  translationTable name
)
RETURNS SETOF RECORD AS $$
  DECLARE
    translatedRow RECORD;
    currentRowNb int = 1;
    debug boolean = TT_Debug();
    startTime timestamptz;
    percentDone numeric;
    remainingSeconds int;
    expectedRowNb int;
  BEGIN
    IF debug THEN RAISE NOTICE 'DEBUG ACTIVATED...';END IF;
    IF debug THEN RAISE NOTICE '_TT_Translate BEGIN';END IF;
--RAISE NOTICE '_TT_Translate BEGIN';

    -- Estimate the number of rows to return
    RAISE NOTICE 'Computing the number of rows to translate... (%)', 'SELECT count(*) FROM ' || TT_FullTableName(sourceTableSchema, sourceTable) || CHR(10) || rowTranslationRuleClause;

    EXECUTE 'SELECT count(*) FROM ' || TT_FullTableName(sourceTableSchema, sourceTable) || CHR(10) || rowTranslationRuleClause
    INTO expectedRowNb;
    RAISE NOTICE '% ROWS TO TRANSLATE...', expectedRowNb;

    startTime = clock_timestamp();
    -- Main loop
		FOR translatedRow IN EXECUTE translationQuery || CHR(10) || 'FROM ' || TT_FullTableName(sourceTableSchema, sourceTable) || CHR(10) || rowTranslationRuleClause
		LOOP
       IF currentRowNb % 100 = 0 THEN
         percentDone = currentRowNb::numeric/expectedRowNb*100;
         remainingSeconds = (100 - percentDone)*(EXTRACT(EPOCH FROM clock_timestamp() - startTime))/percentDone;
         RAISE NOTICE '%(%): %/% rows translated (% %%) - % remaining...', callingFctName, sourceTable, currentRowNb, expectedRowNb, round(percentDone, 3), 
              TT_PrettyDuration(remainingSeconds);
       END IF;
       currentRowNb = currentRowNb + 1;
			 RETURN NEXT translatedRow;
  		END LOOP;
    RETURN;
  END;
$$ LANGUAGE plpgsql VOLATILE;