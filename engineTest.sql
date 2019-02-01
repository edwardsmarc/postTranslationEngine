﻿------------------------------------------------------------------------------
-- PostgreSQL Table Tranlation Engine - Test file
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
SET lc_messages TO 'en_US.UTF-8';

-- Create a test source table
DROP TABLE IF EXISTS test_sourcetable1;
CREATE TABLE test_sourcetable1 AS
SELECT 'a'::text id, 1 crown_closure
UNION ALL
SELECT 'b'::text, 3 
UNION ALL
SELECT 'c'::text, 101;

-- Create a test translation table
DROP TABLE IF EXISTS test_translationTable;
CREATE TABLE test_translationTable AS
SELECT 'CROWN_CLOSURE_UPPER'::text targetAttribute,
       'int'::text targetAttributeType,
       'notNull(crown_closure| -8888);between(crown_closure, 0, 100| -9999)'::text validationRules,
       'copy(crown_closure)'::text translationRules,
       'Test'::text description,
       TRUE descUpToDateWithRules
UNION ALL
SELECT 'CROWN_CLOSURE_LOWER'::text targetAttribute,
       'int'::text targetAttributeType,
       'notNull(crown_closure| -8888);between(crown_closure, 0, 100| -9999)'::text validationRules,
       'copy(crown_closure)'::text translationRules,
       'Test'::text description,
       TRUE descUpToDateWithRules;

--SELECT * FROM test_translationTable;

-----------------------------------------------------------
-- Comment out the following line and the last one of the file to display 
-- only failing tests
--SELECT * FROM (
-----------------------------------------------------------
-- The first table in the next WITH statement list all the function tested
-- with the number of test for each. It must be adjusted for every new test.
-- It is required to list tests which would not appear because they failed
-- by returning nothing.
WITH test_nb AS (
    SELECT 'TT_FullTableName'::text function_tested, 1 maj_num,  5 nb_test UNION ALL
    SELECT 'TT_ParseArgs'::text,                     2,         11         UNION ALL
    SELECT 'TT_ParseRules'::text,                    3,          9         UNION ALL
    SELECT 'TT_ValidateTTable'::text,                4,          1         UNION ALL
    SELECT 'TT_Prepare'::text,                       5,          0         UNION ALL
    SELECT '_TT_Translate'::text,                    6,          0
),
test_series AS (
-- Build a table of function names with a sequence of number for each function to be tested
SELECT function_tested, maj_num, generate_series(1, nb_test)::text min_num 
FROM test_nb
)
SELECT coalesce(maj_num || '.' || min_num, b.number) number,
       coalesce(a.function_tested, 'ERROR: Insufficient number of test for ' || 
                b.function_tested || ' in the initial table...') function_tested,
       description, 
       NOT passed IS NULL AND (regexp_split_to_array(number, '\.'))[2] = min_num AND passed passed
FROM test_series a FULL OUTER JOIN (

---------------------------------------------------------
-- Test 1 - TT_FullTableName
---------------------------------------------------------
---------------------------------------------------------
SELECT '1.1'::text number,
       'TT_FullTableName'::text function_tested,
       'Basic test'::text description,
       TT_FullTableName('public', 'test') = 'public.test' passed

---------------------------------------------------------
UNION ALL
SELECT '1.2'::text number,
       'TT_FullTableName'::text function_tested,
       'Null schema'::text description,
       TT_FullTableName(NULL, 'test') = 'public.test' passed
---------------------------------------------------------
UNION ALL
SELECT '1.3'::text number,
       'TT_FullTableName'::text function_tested,
       'Both NULL parameters'::text description,
        TT_FullTableName(NULL, NULL) IS NULL passed
---------------------------------------------------------
UNION ALL
SELECT '1.4'::text number,
       'TT_FullTableName'::text function_tested,
       'Table name starting with a digit'::text description,
        TT_FullTableName(NULL, '1table') = 'public."1table"' passed
---------------------------------------------------------
UNION ALL
SELECT '1.5'::text number,
       'TT_FullTableName'::text function_tested,
       'Both names starting with a digit'::text description,
        TT_FullTableName('1schema', '1table') = '"1schema"."1table"' passed
---------------------------------------------------------
UNION ALL
SELECT '2.1'::text number,
       'TT_ParseArgs'::text function_tested,
       'Basic test, space and numeric'::text description,
        TT_ParseArgs('aa,  bb,-111.11') = ARRAY['aa', 'bb', '-111.11'] passed
---------------------------------------------------------
-- Test 2 - TT_ParseArgs
---------------------------------------------------------
UNION ALL
SELECT '2.2'::text number,
       'TT_ParseArgs'::text function_tested,
       'Test NULL'::text description,
        TT_ParseArgs() IS NULL passed
---------------------------------------------------------
UNION ALL
SELECT '2.3'::text number,
       'TT_ParseArgs'::text function_tested,
       'Test empty'::text description,
        TT_ParseArgs('') IS NULL  passed
---------------------------------------------------------
UNION ALL
SELECT '2.4'::text number,
       'TT_ParseArgs'::text function_tested,
       'Test value containing a comma'::text description,
        TT_ParseArgs('"a,a", bb,-111.11') = ARRAY['a,a', 'bb', '-111.11'] passed
---------------------------------------------------------
UNION ALL
SELECT '2.5'::text number,
       'TT_ParseArgs'::text function_tested,
       'Test value containing a single quote'::text description,
        TT_ParseArgs('"a''a", bb,-111.11') = ARRAY['a''a', 'bb', '-111.11'] passed
---------------------------------------------------------
UNION ALL
SELECT '2.6'::text number,
       'TT_ParseArgs'::text function_tested,
       'Test one empty value'::text description,
        TT_ParseArgs('"", bb,-111.11') = ARRAY['', 'bb', '-111.11'] passed
---------------------------------------------------------
UNION ALL
SELECT '2.7'::text number,
       'TT_ParseArgs'::text function_tested,
       'Test one NULL value'::text description,
        TT_ParseArgs(', bb,-111.11') = ARRAY['bb', '-111.11'] passed
---------------------------------------------------------
UNION ALL
SELECT '2.8'::text number,
       'TT_ParseArgs'::text function_tested,
       'Test only quoted values'::text description,
        TT_ParseArgs('"aa", "bb", "-111.11"') = ARRAY['aa', 'bb', '-111.11'] passed
---------------------------------------------------------
UNION ALL
SELECT '2.9'::text number,
       'TT_ParseArgs'::text function_tested,
       'Test only single quoted values'::text description,
        TT_ParseArgs('''aa'', ''bb'', ''-111.11''') = ARRAY['aa', 'bb', '-111.11'] passed
---------------------------------------------------------
UNION ALL
SELECT '2.10'::text number,
       'TT_ParseArgs'::text function_tested,
       'Test trailing spaces'::text description,
        TT_ParseArgs('aa''bb') = ARRAY['aa''bb'] passed
---------------------------------------------------------
UNION ALL
SELECT '2.11'::text number,
       'TT_ParseArgs'::text function_tested,
       'Test single quote inside single quotes'::text description,
        TT_ParseArgs('  aa, bb  ') = ARRAY['aa', 'bb'] passed
---------------------------------------------------------
-- Test 3 - TT_ParseRules
---------------------------------------------------------
UNION ALL
SELECT '3.1'::text number,
       'TT_ParseRules'::text function_tested,
       'Basic test, space and numeric'::text description,
        TT_ParseRules('test1(aa, bb,-999.55); test2(cc, dd,222.22)') = ARRAY[('test1', '{aa,bb,-999.55}', NULL, FALSE)::TT_RuleDef, ('test2', '{cc,dd,222.22}', NULL, FALSE)::TT_RuleDef]::TT_RuleDef[] passed
---------------------------------------------------------
UNION ALL
SELECT '3.2'::text number,
       'TT_ParseRules'::text function_tested,
       'Test NULL'::text description,
        TT_ParseRules() IS NULL passed
---------------------------------------------------------
UNION ALL
SELECT '3.3'::text number,
       'TT_ParseRules'::text function_tested,
       'Test empty'::text description,
        TT_ParseRules('') IS NULL passed
---------------------------------------------------------
UNION ALL
SELECT '3.4'::text number,
       'TT_ParseRules'::text function_tested,
       'Test empty function'::text description,
        TT_ParseRules('test1()') = ARRAY[('test1', NULL, NULL, FALSE)::TT_RuleDef]::TT_RuleDef[] passed
---------------------------------------------------------
UNION ALL
SELECT '3.5'::text number,
       'TT_ParseRules'::text function_tested,
       'Test many empty functions'::text description,
        TT_ParseRules('test1(); test2();  test3()') = ARRAY[('test1', NULL, NULL, FALSE)::TT_RuleDef, ('test2', NULL, NULL, FALSE)::TT_RuleDef, ('test3', NULL, NULL, FALSE)::TT_RuleDef]::TT_RuleDef[] passed
---------------------------------------------------------
UNION ALL
SELECT '3.6'::text number,
       'TT_ParseRules'::text function_tested,
       'Test quoted arguments'::text description,
        TT_ParseRules('test1("aa", ''bb'')') =  ARRAY[('test1', '{aa,bb}', NULL, FALSE)::TT_RuleDef]::TT_RuleDef[] passed
---------------------------------------------------------
UNION ALL
SELECT '3.7'::text number,
       'TT_ParseRules'::text function_tested,
       'Test quoted arguments containing comma and quotes'::text description,
        TT_ParseRules('test1("a,a", ''b''b'', ''c"c'')') = ARRAY[('test1', '{"a,a","b''b","c\"c"}', NULL, FALSE)::TT_RuleDef]::TT_RuleDef[] passed
---------------------------------------------------------
UNION ALL
SELECT '3.8'::text number,
       'TT_ParseRules'::text function_tested,
       'Test that quoted is equivalent to unquoted (when not containing comma or quotes)'::text description,
        TT_ParseRules('test1("aa", ''bb'')') =  TT_ParseRules('test1(aa, bb)') passed
---------------------------------------------------------
UNION ALL
SELECT '3.9'::text number,
       'TT_ParseRules'::text function_tested,
       'Test what''s in the test translation table'::text description,
        array_agg(TT_ParseRules(validationRules)) = ARRAY[ARRAY[('notNull', '{crown_closure}', -8888, FALSE)::TT_RuleDef, ('between', '{crown_closure, 0, 100}', -9999, FALSE)::TT_RuleDef]::TT_RuleDef[], ARRAY[('notNull', '{crown_closure}', -8888, FALSE)::TT_RuleDef, ('between', '{crown_closure, 0, 100}', -9999, FALSE)::TT_RuleDef]::TT_RuleDef[]] passed
FROM public.test_translationtable
--------------------------------------------------------
UNION ALL
SELECT '4.1'::text number,
       'TT_ValidateTTable'::text function_tested,
       'Basic test'::text description,
        array_agg(rec)::text = 
'{"(CROWN_CLOSURE_UPPER,int,\"{\"\"(notNull,{crown_closure},-8888,f)\"\",\"\"(between,\\\\\"\"{crown_closure,0,100}\\\\\"\",-9999,f)\"\"}\",\"(copy,{crown_closure},,f)\",Test,t)","(CROWN_CLOSURE_LOWER,int,\"{\"\"(notNull,{crown_closure},-8888,f)\"\",\"\"(between,\\\\\"\"{crown_closure,0,100}\\\\\"\",-9999,f)\"\"}\",\"(copy,{crown_closure},,f)\",Test,t)"}'
FROM (SELECT TT_ValidateTTable('public', 'test_translationtable') rec) foo
---------------------------------------------------------
) b 
ON (a.function_tested = b.function_tested AND (regexp_split_to_array(number, '\.'))[2] = min_num) 
ORDER BY maj_num::int, min_num::int
-- This last line has to be commented out, with the line at the beginning,
-- to display only failing tests...
--) foo WHERE NOT passed
;