-- Tests for PRJ260220.VENVSVMM. Run each on its own.

-- 1. Row count must equal MC.SVMM: a mismatch means a join is multiplying rows.
--    ORCARRLB wasn't covered by the duplicate check.
SELECT (SELECT COUNT(*) FROM RPCLIB."MC.SVMM")    AS SVMM,
       (SELECT COUNT(*) FROM PRJ260220.VENVSVMM)  AS VIEW_ROWS
  FROM SYSIBM.SYSDUMMY1;

-- 2. Screen comparison: put this next to MCS700 option 1 for the same vendor
SELECT * FROM PRJ260220.VENVSVMM WHERE VENDOR_NBR = '52757';

-- 3. A Ship Via overflow vendor: compare with the green screen to confirm the 25-char rebuild
SELECT V.VENDOR_NBR, V.SHIP_VIA
  FROM PRJ260220.VENVSVMM V
  JOIN RPCLIB."MC.SVEM" E ON E.EMNUMB = V.VENDOR_NBR
 WHERE SUBSTR(E.EMSHVI, 16, 10) <> ''
 FETCH FIRST 5 ROWS ONLY;

-- 4. LTL codes with no carrier name (orphan codes, or a join mismatch)
SELECT LTL_VIA, COUNT(*) AS VENDORS
  FROM PRJ260220.VENVSVMM
 WHERE LTL_VIA <> '' AND LTL_CARRIER_NAME = ''
 GROUP BY LTL_VIA;
