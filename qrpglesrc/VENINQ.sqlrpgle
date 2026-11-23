**free
// =====================================================================
//  VENINQ  -  Vendor Inquiry (single vendor, read only)
//  Project : Vendor Inquiry (260220-00) -- SOX read-only vendor access
//  Source  : vendorportal/qrpglesrc/VENINQ.sqlrpgle
//  Reads   : PRJ260220.VENVSVMM   (vendor header, MCS700 layout)
//            RPCLIB."MC.SVEMA"    (multiple emails, maintained by WNVEML)
//  Deploys : vendorInquiry  on RestSrv01 (Dev3)
//
//  One vendor number in -> status + vendor header + email list out.
//  Name lookup, if built, is a separate list service (VENSRCH); this
//  one stays a single-record fetch.
//
//  DEV QUALIFIERS: view is PRJ260220.VENVSVMM while on Dev3. Change to
//  the promoted library (RPCLIB) at promotion -- one place, the SELECT.
//
//  Compile:
//    CRTSQLRPGI OBJ(PRJ260220/VENINQ)
//               SRCSTMF('/home/JFONDA/dev/vendorportal/qrpglesrc/VENINQ.sqlrpgle')
//               CVTCCSID(*JOB) OBJTYPE(*PGM) COMMIT(*NONE) DBGVIEW(*SOURCE)
// =====================================================================

ctl-opt dftactgrp(*no) actgrp(*new)
        option(*srcstmt: *nodebugio: *noshowcpy)
        decedit('0.') datfmt(*iso)
        pgminfo(*pcml: *module: *dclcase);

// ---------------------------------------------------------------------
//  Constants
//
//  MAX_EMAILS: WNVEML enforces MCSVED.EDADD# (default 5, max in use 5
//  as of 11/18/26). 20 leaves headroom if the limit is raised; IWS only
//  serialises emails_LENGTH entries.
// ---------------------------------------------------------------------
dcl-c MAX_EMAILS  20;
dcl-c SERVICE_NM  'Vendor Inquiry';

// ---------------------------------------------------------------------
//  Vendor header. Subfield ORDER MUST MATCH the SELECT column order --
//  SELECT INTO a DS maps by position, not by name.
//
//  Names are the JSON keys the browser sees. vendorInquiry.html reads
//  these exactly; renaming one here breaks the page silently.
// ---------------------------------------------------------------------
dcl-ds vendor_t qualified template;
  vendorNbr         char(5);
  statusCode        char(1);
  inactive          char(1);        // 'Y' when STC = 'I' (deleted) -- badge
  // ----- left column of MCS700 -----
  name              char(30);
  address1          char(30);
  address2          char(30);
  city              char(20);
  state             char(2);
  zipCode           char(10);       // 12345 or 12345-6789
  attention         char(20);
  phoneNbr          char(12);
  extNo             char(4);
  faxNbr            char(12);
  terms             char(15);
  shipVia           char(25);
  ltlVia            char(3);
  ltlCarrierName    char(25);
  fobPoint          char(15);
  certified         char(1);
  // ----- right column of MCS700 -----
  sortField         char(5);
  prepayAllow       char(1);
  prepayBill        char(1);
  collect           char(1);
  automaticPayment  char(1);
  stdTermsDoc       char(3);
  rpFunction        char(3);
  active            char(1);
end-ds;

dcl-ds email_t qualified template;
  address           char(50);
end-ds;

dcl-ds status_t qualified template;
  code           int(10);
  dcl-ds message;
    ID           char(7);
    text         char(100);
  end-ds;
end-ds;

// ---------------------------------------------------------------------
//  Procedure interface
//
//  requestUser is *TRANSPORT_METADATA / REMOTE_USER in IWS, NOT a
//  query parameter. vendorNbr is *QUERY_PARAM.
//
//  ORDERING IS LOAD-BEARING: emails_LENGTH must sit IMMEDIATELY BEFORE
//  the emails array, or IWS serialises all MAX_EMAILS slots.
// ---------------------------------------------------------------------
dcl-pi VENINQ;
  // --- input ---
  requestUser    char(10)  const;
  vendorNbr      char(10)  const;   // digits only; zero-filled to 5 here

  // --- output ---
  status         likeds(status_t);
  vendor         likeds(vendor_t);
  emails_LENGTH  int(10);
  emails         likeds(email_t) dim(MAX_EMAILS);
end-pi;

// ---------------------------------------------------------------------
//  Work fields
// ---------------------------------------------------------------------
dcl-s wInput     varchar(10);
dcl-s wVend      char(5);
dcl-s wAuthCount int(10);

exec sql SET OPTION
    commit    = *none,
    closqlcsr = *endmod,
    naming    = *sql,
    datfmt    = *iso;

// =====================================================================
//  Main
// =====================================================================
clear status;
clear vendor;
clear emails;
emails_LENGTH = 0;

// ---------------------------------------------------------------------
//  Authority -- row in WEBSVCACC for this service IS the grant.
//  Inquiry only: no '<name> Update' entry exists or is checked.
// ---------------------------------------------------------------------
wAuthCount = 0;

exec sql
  SELECT COUNT(*)
    INTO :wAuthCount
    FROM RPCLIB.WEBSVCACC
   WHERE USERID     = UPPER(:requestUser)
     AND WEBSERVICE = :SERVICE_NM;

if SQLCODE < 0 or wAuthCount = 0;
  status.code         = 401;
  status.message.ID   = 'VEN0401';
  status.message.text = 'Not authorised for ' + %trim(SERVICE_NM) + '.';
  return;
endif;

// ---------------------------------------------------------------------
//  Validate and normalise the vendor number.
//
//  MCS700 uses CHECK(RZ): right-adjust, zero-fill. '80' -> '00080'.
//  Digits only, 1-5 long; anything else is a bad request, not a
//  not-found -- the page should say "invalid", not "no such vendor".
// ---------------------------------------------------------------------
wInput = %trim(vendorNbr);

if %len(wInput) = 0
   or %len(wInput) > 5
   or %check('0123456789' : wInput) > 0;
  status.code         = 400;
  status.message.ID   = 'VEN0400';
  status.message.text = 'Vendor number must be 1-5 digits.';
  return;
endif;

wVend = %editc(%dec(wInput : 5 : 0) : 'X');

// ---------------------------------------------------------------------
//  Vendor header. VENVSVMM COALESCEs every joined column, so no NULL
//  can reach a non-null host variable here.
// ---------------------------------------------------------------------
exec sql
  SELECT VENDOR_NBR, STATUS_CODE, INACTIVE,
         NAME, ADDRESS_1, ADDRESS_2, CITY, STATE, ZIP_CODE,
         ATTENTION, PHONE_NBR, EXT_NO, FAX_NBR, TERMS, SHIP_VIA,
         LTL_VIA, LTL_CARRIER_NAME, FOB_POINT, CERTIFIED,
         SORT_FIELD, PREPAY_ALLOW, PREPAY_BILL, COLLECT,
         AUTOMATIC_PAYMENT, STD_TERMS_DOC, RP_FUNCTION, ACTIVE
    INTO :vendor
    FROM PRJ260220.VENVSVMM
   WHERE VENDOR_NBR = :wVend;

if SQLCODE = 100;
  status.code         = 404;
  status.message.ID   = 'VEN0404';
  status.message.text = 'Vendor ' + wVend + ' not found.';
  return;
endif;

if SQLCODE < 0;
  status.code         = 500;
  status.message.ID   = 'VEN0500';
  status.message.text = 'Error reading vendor master.';
  return;
endif;

// ---------------------------------------------------------------------
//  Emails. Alphabetical, same order as the WNVEML (option M) window,
//  which reads LF MCSVEMLAA keyed vendor + address.
// ---------------------------------------------------------------------
exec sql
  DECLARE emailCsr CURSOR FOR
  SELECT EMADDR
    FROM RPCLIB."MC.SVEMA"
   WHERE EMNUMB = :wVend
     AND EMADDR <> ''
   ORDER BY EMADDR;

exec sql OPEN emailCsr;

if SQLCODE < 0;
  status.code         = 500;
  status.message.ID   = 'VEN0500';
  status.message.text = 'Could not open email cursor.';
  return;
endif;

exec sql
  FETCH NEXT FROM emailCsr FOR :MAX_EMAILS ROWS INTO :emails;

if SQLCODE < 0;
  status.code         = 500;
  status.message.ID   = 'VEN0500';
  status.message.text = 'Error reading vendor emails.';
  exec sql CLOSE emailCsr;
  return;
endif;

emails_LENGTH = SQLER3;

exec sql CLOSE emailCsr;

status.code         = 200;
status.message.ID   = 'VEN0000';
status.message.text = 'OK';

return;
