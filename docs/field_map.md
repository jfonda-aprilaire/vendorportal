# Vendor Inquiry: field map and decisions

Source of truth for how the MCS700 green screen maps to `VENVSVMM`.
Positions are from the MCS700 I-specs, cross-checked with DSPFFD 11/18/26.

## Vendor master: RPCLIB."MC.SVMM" (format MC1SVMM, key VMNUMB)

| Screen label       | DDS field | RPG field | Pos     | View column        | Notes |
|--------------------|-----------|-----------|---------|--------------------|-------|
| (status)           | STC       | VMSTC     | 1       | STATUS_CODE, INACTIVE | 'I' = deleted via option D. Drives the badge |
| Vendor Nbr         | VMNUMB    | VMVEND    | 2-6     | VENDOR_NBR         | Zero-filled 5 digits |
| Name               | VMNAME    | VMVNAM    | 7-36    | NAME               | |
| Address 1          | VMADD1    | VMVAD1    | 37-66   | ADDRESS_1          | |
| Address 2          | VMADD2    | VMVAD2    | 67-96   | ADDRESS_2          | |
| City               | VMCITY    | VMCITY    | 97-116  | CITY               | |
| State              | VMSTAT    | VMST      | 117-118 | STATE              | |
| Zip Code           | VMZIP5 + VMZIP4 | VMZIP + VMZIP1 | 119-127 | ZIP_CODE   | 12345-6789 when ZIP4 is not blank |
| Attention          | VMATTN    | VMATTN    | 128-147 | ATTENTION          | |
| Phone Nbr          | VMPHON    | VMPHON    | 148-159 | PHONE_NBR          | |
| Terms              | VMTERV    | VMTERM    | 160-174 | TERMS              | Free form. VMTERC (244-245) is unused |
| Ship Via           | VMSHPV    | VMSHPV    | 175-189 | SHIP_VIA           | First 15 of 25. See Ship Via |
| FOB Point          | VMFOBP    | VMFOB     | 190-204 | FOB_POINT          | |
| LTL Via            | VMLTLV    | VMLTLV    | 211-213 | LTL_VIA, LTL_CARRIER_NAME | Join RPCLIB."O.CARIER".SHVIA (PF under ORCARRLB). '000'/blank = none |
| Std Terms Document | FLR03A    | VSTDCD    | 241-243 | STD_TERMS_DOC      | DDS says "Filler 003" but it holds live data. Text only (no PDF link this sprint) |
| Sort Field         | VMALPH    | VMSORT    | 248-252 | SORT_FIELD         | Also in SRCH_TEXT |
| Prepay & Allow     | VMPPAS    | VMPPA     | 253     | PREPAY_ALLOW       | |
| Prepay & Bill      | VMPPBS    | VMPPB     | 254     | PREPAY_BILL        | |
| Collect            | VMCOLS    | VMCOL     | 255     | COLLECT            | |
| Automatic Payment  | VMAUTP    | VMAUTP    | 256     | AUTOMATIC_PAYMENT  | MCS700 never writes it (O-spec commented out), but it has data: 327 Y / 659 N / 2480 blank |

Not displayed: VMLACT, VMNOPO, VMNQTS, the rating fields (215-240), VMANLS, VMTERC.

## Fax/aux: RPCLIB.MCSVFX (native copy of QS36F/"MC.SVFX")

Refreshed by MCSVFXCL after every MCS700 update (U1). Verified identical 11/18/26 (3948 rows, EXCEPT both ways = 0).
One record per vendor (no duplicates).

| Screen label | DDS field | Pos   | View column  | Notes |
|--------------|-----------|-------|--------------|-------|
| Fax Nbr      | FXNBR     | 7-18  | FAX_NBR      | One fax per vendor |
| Ext No       | FXEXT#    | 19-22 | EXT_NO       | Phone extension, not fax (1992 mod) |
| Certified    | FXCRTCD   | 23    | CERTIFIED    | 'N' when no SVFX record, same as MCS700 |
| RP Function  | FXRPFUN   | 24-26 | RP_FUNCTION  | Raw. Nobody knows the meaning |
| Active       | FXACTIV   | 27    | ACTIVE       | Shown as-is. Mostly blank, never 'N' |

## Ship Via

MCS700 does `MOVE EMSHVI TRSHPX` (25 chars from MC.SVEM), then `MOVEL VMSHPV TRSHPX` (15 from SVMM on top).
View: `RTRIM(VMSHPV || SUBSTR(EMSHVI, 16, 10))`. 28 vendors have overflow data.
MC.SVEM (format MCS1VEM) is used **only** for this. Its EMADDR is the obsolete single email (ignore, per Dan).

## Emails: RPCLIB.MCSVEMLAA (LF over RPCLIB/"MC.SVEMA", format MCS1VEMA)

Maintained by WNVEML (option M). Keyed EMNUMB + EMADDR, so it lists alphabetically. Hard deletes, no status.

| Field  | Pos   | Notes |
|--------|-------|-------|
| EMNUMB | 1-5   | Vendor |
| EMADDR | 6-55  | 50 chars |
| EMCOD  | 56-59 | **Dropped from the page.** 1 of 2743 rows has a value |

MC.SVEMAX (26 rows) is a leftover. Copies in CAVLIB/RPCTEST/TASLIB are not live.

## Decisions (11/18/26)

| Topic | Decision | By |
|-------|----------|----|
| Library / env | PRJ260220 on Dev3 | Dan / Jeffery |
| Audit log | Not needed: access control is enough (read only) | Dan |
| Inactive vendors | Show, with badge driven by STC = 'I' | Dan |
| Active Y/N field | Show as-is | Dan |
| Ecode | Drop | Dan |
| LTL Via | Code + carrier name from ORCARRLB | Dan |
| Terms / RP Function | Raw | Dan |
| Std Terms PDF link | Not this sprint | Jeffery |
| Name lookup | Stretch goal, if time allows | Dan |

## Carrier file

RPCLIB."O.CARIER" (format CA1MAST) is the PF under ORCARRLB. CREATE VIEW over ORCARRLB fails with
SQL7010, so the view joins the PF. ORCARRLB has no select/omit and a unique key on SHVIA, so the PF join
can't duplicate vendors (verified: view count = MC.SVMM count, 3466).

## Open items

- Who removes the Materials users from the MCS700 OCL list? That's the actual SOX fix.
- The OCL change log says LBIRD was added (05/19/2025), but the list has JBIRD.
- Which OCL users are Materials and which are Sourcing (JROSE and LHANFELD appear in both blocks).
- What PC0004A option 5 searches on (model for the name lookup).
