-- ---------------------------------------------------------------------------
-- VENVSVMM  Vendor Inquiry: one row per vendor, laid out like the MCS700 screen
-- Project 260220-00 (SOX: read-only vendor access for the Materials group)
--
-- Sources (positions verified against the MCS700 I-specs and DSPFFD):
--   RPCLIB."MC.SVMM"  vendor master
--   RPCLIB.MCSVFX     native copy of QS36F/MC.SVFX (fax, ext, certified, RP function, active).
--                     Refreshed by MCSVFXCL after every MCS700 update; verified in sync 11/18/26.
--   RPCLIB."MC.SVEM"  used ONLY for Ship Via chars 16-25 (EMSHVI). Its email field is obsolete.
--   RPCLIB.ORCARRLB   carrier name for LTL Via
-- Multiple emails are NOT here: read RPCLIB.MCSVEMLAA (over MC.SVEMA) in the service.
--
-- Dev: created in PRJ260220. Change the schema to RPCLIB at promotion.
-- No ORDER BY (not allowed in views on Db2 for i).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW PRJ260220.VENVSVMM AS
SELECT
    M.VMNUMB                                        AS VENDOR_NBR,
    M.STC                                           AS STATUS_CODE,     -- 'A' / 'I'
    CASE WHEN M.STC = 'I' THEN 'Y' ELSE 'N' END     AS INACTIVE,        -- drives the badge (per Dan 11/18)

    -- Left column of the screen
    M.VMNAME                                        AS NAME,
    M.VMADD1                                        AS ADDRESS_1,
    M.VMADD2                                        AS ADDRESS_2,
    M.VMCITY                                        AS CITY,
    M.VMSTAT                                        AS STATE,
    CASE WHEN M.VMZIP4 <> ''
         THEN TRIM(M.VMZIP5) CONCAT '-' CONCAT M.VMZIP4
         ELSE TRIM(M.VMZIP5) END                    AS ZIP_CODE,
    M.VMATTN                                        AS ATTENTION,
    M.VMPHON                                        AS PHONE_NBR,
    COALESCE(F.FXEXT#, '')                          AS EXT_NO,          -- phone ext lives in SVFX (1992 mod)
    COALESCE(F.FXNBR, '')                           AS FAX_NBR,
    M.VMTERV                                        AS TERMS,           -- free form; VMTERC (terms code) is unused
    -- MCS700: MOVE EMSHVI (25), then MOVEL VMSHPV (15) on top -> VMSHPV || EMSHVI(16:10)
    RTRIM(M.VMSHPV CONCAT COALESCE(SUBSTR(E.EMSHVI, 16, 10), ''))
                                                    AS SHIP_VIA,
    CASE WHEN M.VMLTLV IN ('', '000') THEN '' ELSE M.VMLTLV END
                                                    AS LTL_VIA,
    COALESCE(C.CARRN, '')                           AS LTL_CARRIER_NAME,
    M.VMFOBP                                        AS FOB_POINT,
    COALESCE(F.FXCRTCD, 'N')                        AS CERTIFIED,       -- MCS700 shows 'N' when no SVFX record

    -- Right column of the screen
    M.VMALPH                                        AS SORT_FIELD,
    M.VMPPAS                                        AS PREPAY_ALLOW,
    M.VMPPBS                                        AS PREPAY_BILL,
    M.VMCOLS                                        AS COLLECT,
    M.VMAUTP                                        AS AUTOMATIC_PAYMENT, -- not maintained by MCS700
    M.FLR03A                                        AS STD_TERMS_DOC,   -- "Filler 003" holds live data
    COALESCE(F.FXRPFUN, '')                         AS RP_FUNCTION,
    COALESCE(F.FXACTIV, '')                         AS ACTIVE,          -- shown as-is; mostly blank

    -- Name lookup (stretch goal): number + name + sort field, upper-cased
    UPPER(M.VMNUMB CONCAT ' ' CONCAT TRIM(M.VMNAME) CONCAT ' ' CONCAT TRIM(M.VMALPH))
                                                    AS SRCH_TEXT

  FROM RPCLIB."MC.SVMM" M
  LEFT JOIN RPCLIB.MCSVFX    F ON F.FXNUMB = M.VMNUMB
  LEFT JOIN RPCLIB."MC.SVEM" E ON E.EMNUMB = M.VMNUMB
  LEFT JOIN RPCLIB.ORCARRLB  C ON C.SHVIA  = M.VMLTLV
                              AND M.VMLTLV NOT IN ('', '000');

LABEL ON TABLE PRJ260220.VENVSVMM IS 'Vendor Inquiry - MCS700 layout (read only)';
