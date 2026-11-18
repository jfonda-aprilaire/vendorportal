-- Vendor Inquiry: data checks to run before writing the view.
-- Run each statement on its own (cursor on it + run) so every result shows.

-- 1. Is the RPCLIB/MCSVFX copy in sync with the S/36 file MCS700 actually updates?
--    QS36F/MC.SVFX is program-described: F00001 (status), K00001 (vendor key), F00002 (pos 7-32),
--    all CCSID 65535, so CAST them. 11/18/26 result: 0 rows both ways, 3948 = 3948.
SELECT 'IN S36 ONLY' AS SIDE,
       CAST(F00001 AS CHAR(1) CCSID 37) || CAST(K00001 AS CHAR(5) CCSID 37)
         || CAST(F00002 AS CHAR(26) CCSID 37) AS REC
  FROM QS36F."MC.SVFX"
EXCEPT
SELECT 'IN S36 ONLY', FXCSTC || FXNUMB || FXNBR || FXEXT# || FXCRTCD || FXRPFUN || FXACTIV || FXZZ5
  FROM RPCLIB.MCSVFX;

SELECT 'IN COPY ONLY' AS SIDE, FXCSTC || FXNUMB || FXNBR || FXEXT# || FXCRTCD || FXRPFUN || FXACTIV || FXZZ5 AS REC
  FROM RPCLIB.MCSVFX
EXCEPT
SELECT 'IN COPY ONLY',
       CAST(F00001 AS CHAR(1) CCSID 37) || CAST(K00001 AS CHAR(5) CCSID 37)
         || CAST(F00002 AS CHAR(26) CCSID 37)
  FROM QS36F."MC.SVFX";

SELECT (SELECT COUNT(*) FROM QS36F."MC.SVFX") AS S36,
       (SELECT COUNT(*) FROM RPCLIB.MCSVFX)    AS COPY
  FROM SYSIBM.SYSDUMMY1;

-- 2. One row per vendor in the 1:1 side files? (Duplicates would multiply rows in the view.)
SELECT 'MCSVFX' AS FILE, FXNUMB AS VENDOR, COUNT(*) AS CNT
  FROM RPCLIB.MCSVFX GROUP BY FXNUMB HAVING COUNT(*) > 1
UNION ALL
SELECT 'MC.SVEM', EMNUMB, COUNT(*)
  FROM RPCLIB."MC.SVEM" GROUP BY EMNUMB HAVING COUNT(*) > 1;

-- 3. Deleted vs Active: how do the two "inactive" flags overlap? (For the badge question to Dan)
SELECT M.STC, COALESCE(F.FXACTIV, '(no SVFX)') AS FXACTIV, COUNT(*) AS VENDORS
  FROM RPCLIB."MC.SVMM" M
  LEFT JOIN RPCLIB.MCSVFX F ON F.FXNUMB = M.VMNUMB
 GROUP BY M.STC, COALESCE(F.FXACTIV, '(no SVFX)')
 ORDER BY 1, 2;

-- 4. Automatic Payment: MCS700 never writes this byte. Is there anything in it?
SELECT VMAUTP, COUNT(*) AS VENDORS
  FROM RPCLIB."MC.SVMM" GROUP BY VMAUTP;

-- 5. Ecode values in use (ask JAK what they mean)
SELECT EMCOD, COUNT(*) AS EMAILS
  FROM RPCLIB.MCSVEMLAA GROUP BY EMCOD ORDER BY 2 DESC;

-- 6. Does the Ship Via overflow (chars 16-25 in SVEM) ever hold anything?
SELECT COUNT(*) AS VENDORS_WITH_OVERFLOW
  FROM RPCLIB."MC.SVEM"
 WHERE SUBSTR(EMSHVI, 16, 10) <> '';

-- 7. MC.SVEMA vs MC.SVEMAX: which is the live multi-email file?
SELECT 'MC.SVEMA' AS FILE, COUNT(*) AS ROWS FROM RPCLIB."MC.SVEMA"
UNION ALL
SELECT 'MC.SVEMAX', COUNT(*) FROM RPCLIB."MC.SVEMAX"
UNION ALL
SELECT 'MCSVEMLAA', COUNT(*) FROM RPCLIB.MCSVEMLAA;
