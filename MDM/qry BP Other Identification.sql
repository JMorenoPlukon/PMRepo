WITH lang_tbl as (
  Select :CurrentUser_LanguageCode as lang 
  /* Select 'nl' as lang */
)
, current_user_tbl as (
  Select :CurrentUser_Email as crt_user	
  /* Select 'f.wester@plukon.nl'as crt_user */
), "Translations_Tbl" as (
Select 
  "term",
  COALESCE((CASE WHEN "lang_tbl"."lang" IN ( 'nl' ) THEN "dutch"
        ELSE (CASE WHEN "lang_tbl"."lang" IN ( 'de' ) THEN "german"
          ELSE (CASE WHEN "lang_tbl"."lang" IN ( 'fr' ) THEN "french"
            ELSE (CASE WHEN "lang_tbl"."lang" IN ( 'pl' ) THEN "polish"
              ELSE (CASE WHEN "lang_tbl"."lang" IN ( 'es' ) THEN "spanish"
                ELSE (CASE WHEN "lang_tbl"."lang" IN ( 'dk' ) THEN "danish"
                  ELSE (CASE WHEN "lang_tbl"."lang" IN ( 'en' ) THEN "english"
          END) END) END) END) END) END)
    END), "term") AS "term_trans"
From "Translations"
Cross join "lang_tbl"
)
, bp_vba_tbl as (
Select bp_attrib_type, bp_attrib_subtype, bp_attrib_lvl, bp_attrib_value, bp_attrib_nr, startdate, enddate, isactive, pid
From "Tbl_BP_Attrib" 
WHERE 1=1 
  And "Tbl_BP_Attrib".bp_attrib_type in ( 'VBA' )
  And ("Tbl_BP_Attrib".startdate is Null or "Tbl_BP_Attrib".startdate < now())
  And ("Tbl_BP_Attrib".enddate is Null or "Tbl_BP_Attrib".enddate >= date(now()))
  And coalesce("Tbl_BP_Attrib"."isactive", True)
)
, "PM_User_Tbl" as (
Select Distinct
	"Tbl_Bus_Partners".sid as user_sid, "Tbl_Bus_Partners".pers_id as user_mail, bp_vba_tbl.bp_attrib_subtype, bp_vba_tbl.bp_attrib_value
From "Tbl_Bus_Partners"
  Join  bp_vba_tbl On bp_vba_tbl.pid = "Tbl_Bus_Partners".sid  
Where 1=1
  And "Tbl_Bus_Partners".bp_cat in ( 'PM User' )

  And "Tbl_Bus_Partners".pers_id in (select crt_user from current_user_tbl)
) 
, bus_partners as (
Select sid, bp_cat, "createdBy", bp_code, bp_name, first_name, family_name, pers_id_type, pers_id, bpstatus, isactive
From "Tbl_Bus_Partners" 
Where 1=1
And bp_cat in  ( 'Company', 'Government' ) 
) 
, "BP_Tbl" as (
Select Distinct
	bus_partners.sid as bp_sid, bus_partners.bp_cat, bus_partners."createdBy", bus_partners.bp_code, bp_vba_tbl.bp_attrib_subtype, bp_vba_tbl.bp_attrib_value, user_mail
From  bus_partners
  Left Join bp_vba_tbl 
  On bp_vba_tbl.pid = bus_partners.sid

  Join "PM_User_Tbl"
  On (("PM_User_Tbl"."bp_attrib_subtype" = bp_vba_tbl."bp_attrib_subtype" And "PM_User_Tbl"."bp_attrib_value" = bp_vba_tbl."bp_attrib_value")
  
      Or bus_partners."createdBy" in (select crt_user from current_user_tbl)

      Or bus_partners.bp_cat in ( 'Person' )
      )
Where 1=1

And bus_partners.sid=:bp_sid /* IN (SELECT DISTINCT "sid" FROM "Tbl_Bus_Partners" WHERE "bp_code" IN ( 'LEER', 'LEEM', 'LEEV', 'AKK', 'WOUK', '1WOUTE2', 'MANSM', 'DOCA', 'MECK1', 'GALLUS', 'BBV', 'ARKG', 'ARKG2', 'JANG' )) */

) /* Select * From "BP_Tbl" */
, "Ident_Address" as ( 
SELECT DISTINCT 
  "Tbl_Addr_Attrib"."pid" as "addr_sid",
  "Tbl_Addr_Attrib"."sid" as "addr_attrib_sid",
  "Tbl_Relations_BPLoc"."sid_to" as "bp_sid",
  "Tbl_VS_Attrib"."vs_attrib_subtype" as "src_tbl",
  "Ident_URL"."vs_attrib_value" as "ident_url",
  "Tbl_Addresses"."addr_code",
  Coalesce("Tbl_Addresses"."addr_name" || ' - ','') || Coalesce("Tbl_Addresses"."street" || ' ','') 
    || Coalesce(Coalesce(Cast("Tbl_Addresses"."house_nr" as text),'') || coalesce('-' || "Tbl_Addresses"."house_nr_ext",'') || ', ','') 
	|| Coalesce("Tbl_Addresses"."postal_code" || ' ', ' ' ) || Coalesce("Tbl_Addresses"."village" || ' ','') ||  Coalesce("Tbl_Addresses"."country",'') 
     as "addr_string",
  "Tbl_Addr_Attrib"."addr_attrib_type",
  "Tbl_Addr_Attrib"."addr_attrib_subtype",
  "Tbl_Addr_Attrib"."addr_attrib_lvl",
  "Tbl_Addr_Attrib"."addr_attrib_value",
  "Tbl_Addr_Attrib"."addr_attrib_nr",
  "Tbl_Addr_Attrib".startdate,
  "Tbl_Addr_Attrib".enddate
FROM "Tbl_Addr_Attrib"
  Join "Tbl_Addresses" on "Tbl_Addresses"."sid" = "Tbl_Addr_Attrib"."pid"
  Join "Tbl_Value_Sets" On "Tbl_Value_Sets"."vs_value" = "Tbl_Addr_Attrib"."addr_attrib_subtype" 
  Join "Tbl_VS_Attrib" On "Tbl_VS_Attrib"."pid" = "Tbl_Value_Sets"."sid"
  Left Join "Tbl_VS_Attrib" as "Ident_URL" On "Ident_URL"."pid" = "Tbl_Value_Sets"."sid" And "Ident_URL"."vs_attrib_type" in (  'Identification URL' )
  Join "Tbl_Locations" On "Tbl_Locations"."pid" = "Tbl_Addr_Attrib"."pid"
  Join "Tbl_Relations_BPLoc" On "Tbl_Relations_BPLoc"."sid_subj" = "Tbl_Locations"."sid"
  Join "BP_Tbl" On "BP_Tbl"."bp_sid" = "Tbl_Relations_BPLoc"."sid_to"
Where 1=1
  And "Tbl_VS_Attrib"."vs_attrib_type" in ( 'Identification' )
  And "Tbl_Addr_Attrib"."addr_attrib_type" not in ( 'KRAS1 tblLocIdStalId' )
  And "Tbl_Relations_BPLoc"."rel_maintype_bploc" in ( 'Comp - Location Relation' )
  And ("Tbl_Addr_Attrib".enddate is null or "Tbl_Addr_Attrib".enddate >= date(now()))
  And Coalesce("Tbl_Addr_Attrib"."isactive",true)
  And ("Tbl_Relations_BPLoc".enddate is null or "Tbl_Relations_BPLoc".enddate >= date(now()))
  And Coalesce("Tbl_Relations_BPLoc"."isactive",true)
  And ("Tbl_Value_Sets".enddate is null or "Tbl_Value_Sets".enddate >= date(now()))
  And Coalesce("Tbl_Value_Sets"."isactive",true)
)
, "Ident_Location" as ( 
SELECT DISTINCT
  "Tbl_Loc_Attrib"."pid" as "loc_sid",
  "Tbl_Loc_Attrib"."sid" as "loc_attrib_sid",
  "Tbl_Relations_BPLoc"."sid_to" as "bp_sid",
  "Tbl_Locations"."loc_code",
  "Tbl_Locations"."loc_name" || '-' || "Tbl_Locations"."loc_nr" as "loc_string",
  "Tbl_VS_Attrib"."vs_attrib_subtype" as "src_tbl",
  "Ident_URL"."vs_attrib_value" as "ident_url",
  "Tbl_Loc_Attrib"."loc_attrib_type",
  "Tbl_Loc_Attrib"."loc_attrib_subtype",
  "Tbl_Loc_Attrib"."loc_attrib_lvl",
  "Tbl_Loc_Attrib"."loc_attrib_value",
  "Tbl_Loc_Attrib"."loc_attrib_nr",
  "Tbl_Loc_Attrib".startdate,
  "Tbl_Loc_Attrib".enddate
FROM "Tbl_Loc_Attrib"
  Join "Tbl_Locations" on "Tbl_Locations"."sid" = "Tbl_Loc_Attrib"."pid"
  Join "Tbl_Value_Sets" On "Tbl_Value_Sets"."vs_value" = "Tbl_Loc_Attrib"."loc_attrib_subtype" 
  Join "Tbl_VS_Attrib" On "Tbl_VS_Attrib"."pid" = "Tbl_Value_Sets"."sid"
  Left Join "Tbl_VS_Attrib" as "Ident_URL" On "Ident_URL"."pid" = "Tbl_Value_Sets"."sid" And "Ident_URL"."vs_attrib_type" in (  'Identification URL' )
  Join "Tbl_Relations_BPLoc" On "Tbl_Relations_BPLoc"."sid_subj" = "Tbl_Loc_Attrib"."pid"
  Join "BP_Tbl" On "BP_Tbl"."bp_sid" = "Tbl_Relations_BPLoc"."sid_to"
Where 1=1
  And "Tbl_VS_Attrib"."vs_attrib_type" in ( 'Identification' )
  And "Tbl_VS_Attrib"."vs_attrib_subtype" in ( 'Tbl_Loc_Attrib' )
  And "Tbl_Loc_Attrib"."loc_attrib_type" not in ( 'KRAS1 tblLocIdStalId' )
  And ("Tbl_Loc_Attrib".enddate is null or "Tbl_Loc_Attrib".enddate >= date(now()))
  And Coalesce("Tbl_Loc_Attrib"."isactive",true)
  And ("Tbl_Relations_BPLoc".enddate is null or "Tbl_Relations_BPLoc".enddate >= date(now()))
  And Coalesce("Tbl_Relations_BPLoc"."isactive",true)
  And ("Tbl_Value_Sets".enddate is null or "Tbl_Value_Sets".enddate >= date(now()))
  And Coalesce("Tbl_Value_Sets"."isactive",true)

)
, "Ident_BP_Attrib" as (
SELECT DISTINCT 
  "Tbl_BP_Attrib"."pid" as "bp_sid",
  "Tbl_BP_Attrib"."sid" as "bp_attrib_sid",
  "Tbl_Bus_Partners"."bp_code",
  "Tbl_Bus_Partners"."bp_name" as "bp_string",
  "Tbl_VS_Attrib"."vs_attrib_subtype" as "src_tbl",
  "Ident_URL"."vs_attrib_value" as "ident_url",
  "Tbl_BP_Attrib"."bp_attrib_type",
  "Tbl_BP_Attrib"."bp_attrib_subtype",
  "Tbl_BP_Attrib"."bp_attrib_lvl",
  "Tbl_BP_Attrib"."bp_attrib_value",
  "Tbl_BP_Attrib"."bp_attrib_nr",
  "Tbl_BP_Attrib".startdate,
  "Tbl_BP_Attrib".enddate
FROM "Tbl_BP_Attrib"
  Join "Tbl_Bus_Partners" on "Tbl_Bus_Partners"."sid" = "Tbl_BP_Attrib"."pid"
  Join "BP_Tbl" On "BP_Tbl"."bp_sid" = "Tbl_Bus_Partners"."sid"
  Join "Tbl_Value_Sets" On "Tbl_Value_Sets"."vs_value" = "Tbl_BP_Attrib"."bp_attrib_subtype"
  Join "Tbl_VS_Attrib" On "Tbl_VS_Attrib"."pid" = "Tbl_Value_Sets"."sid"
  Left Join "Tbl_VS_Attrib" as "Ident_URL" On "Ident_URL"."pid" = "Tbl_Value_Sets"."sid" And "Ident_URL"."vs_attrib_type" in (  'Identification URL' )
Where 1=1
  And "Tbl_VS_Attrib"."vs_attrib_type" in ( 'Identification' )
  And "Tbl_BP_Attrib"."bp_attrib_type" not in ('KRAS1 tblLocIdStalId' )
  And ("Tbl_BP_Attrib".enddate is null or "Tbl_BP_Attrib".enddate >= date(now()))
  And Coalesce("Tbl_BP_Attrib"."isactive",true)
  And ("Tbl_Value_Sets".enddate is null or "Tbl_Value_Sets".enddate >= date(now()))
  And Coalesce("Tbl_Value_Sets"."isactive",true)

)
, "Ident_Rel_To_Tbl" as (
SELECT Distinct
  "Tbl_Relations_BPLoc"."sid_to" as "bp_sid",
  "Tbl_Relations_BPLoc"."sid_subj" as "rel_sid",
  "Tbl_Relations_BPLoc"."sid" as "rel_bploc_sid",
  coalesce("Tbl_Bus_Partners"."bp_code", "Tbl_Locations"."loc_code") as "rel_code",
  coalesce("Tbl_Bus_Partners"."bp_code" || ' - ' || "Tbl_Bus_Partners"."bp_name", 
      "Tbl_Locations"."loc_name"|| '-' || "Tbl_Locations"."loc_nr"
      ) as "rel_string",
  COALESCE("Translations_Tbl"."term_trans","Tbl_Relations_BPLoc"."rel_type_bploc") AS "rel_type_bploc_lang",
  "Tbl_VS_Attrib"."vs_attrib_subtype" as "src_tbl",
  "Ident_URL"."vs_attrib_value" as "ident_url",
  "Tbl_Relations_BPLoc"."rel_lvl",
  "Tbl_Relations_BPLoc"."rel_bploc_value",
  "Tbl_Relations_BPLoc"."rel_bploc_nr",
  "Tbl_Relations_BPLoc".startdate,
  "Tbl_Relations_BPLoc".enddate
FROM "Tbl_Relations_BPLoc"
  Join "BP_Tbl" On "BP_Tbl"."bp_sid" = "Tbl_Relations_BPLoc"."sid_to"
  Left JOIN "Translations_Tbl" ON "Translations_Tbl"."term" = "Tbl_Relations_BPLoc"."rel_type_bploc"
  Left Join "Tbl_Bus_Partners" on "Tbl_Bus_Partners"."sid" = "Tbl_Relations_BPLoc"."sid_subj"
  Left Join "Tbl_Locations" on "Tbl_Locations"."sid" = "Tbl_Relations_BPLoc"."sid_subj"
  Join "Tbl_Value_Sets" On "Tbl_Value_Sets"."vs_value" = "Tbl_Relations_BPLoc"."rel_type_bploc"
  Join "Tbl_VS_Attrib" On "Tbl_VS_Attrib"."pid" = "Tbl_Value_Sets"."sid" 
  Left Join "Tbl_VS_Attrib" as "Ident_URL" On "Ident_URL"."pid" = "Tbl_Value_Sets"."sid" And "Ident_URL"."vs_attrib_type" in (  'Identification URL' )
Where 1=1
  And "Tbl_VS_Attrib"."vs_attrib_type" in ( 'Identification' )
  And ("Tbl_Relations_BPLoc".enddate is null or "Tbl_Relations_BPLoc".enddate >= date(now()))
  And Coalesce("Tbl_Relations_BPLoc"."isactive",true)
  And ("Tbl_Value_Sets".enddate is null or "Tbl_Value_Sets".enddate >= date(now()))
  And Coalesce("Tbl_Value_Sets"."isactive",true)

)
Select Distinct 
  "Tbl"."bp_sid", 
  "Tbl"."rel_sid",
  "Tbl"."src_tbl_sid",
  "Tbl"."code", 
  "Tbl"."id_string", 
  "Tbl"."src_tbl",
  "Tbl"."src_type",
  "Tbl"."ident_url",
  COALESCE("Translations_Tbl"."term_trans","Tbl"."ident_type") AS "ident_type", 
  "Tbl"."ident_lvl",
  "Tbl"."ident_value",
  "Tbl".startdate,
  "Tbl".enddate
From (
  Select "bp_sid", "rel_sid", "rel_bploc_sid" as "src_tbl_sid", "rel_code" as "code", "rel_string" as "id_string", "src_tbl", 'Relations' as "src_type", 
    "ident_url", "rel_type_bploc_lang" as "ident_type", "rel_lvl" as "ident_lvl",
    coalesce("rel_bploc_value", cast("rel_bploc_nr" as text)) as "ident_value", startdate, enddate
	From "Ident_Rel_To_Tbl"
  UNION
  Select "bp_sid", "addr_sid", "addr_attrib_sid", "addr_code" as "code", "addr_string" as "id_string", "src_tbl", 'Address Attribute', 
    "ident_url", "addr_attrib_subtype" as "ident_type", "addr_attrib_lvl" as "ident_lvl",
    coalesce("addr_attrib_value", cast("addr_attrib_nr" as text)) as "ident_value", startdate, enddate
	from "Ident_Address"
  UNION
  Select "bp_sid", Null, "bp_attrib_sid", "bp_code" as "code", "bp_string" as "id_string", "src_tbl", 'BP Attribute',
    "ident_url", "bp_attrib_subtype" as "ident_type", "bp_attrib_lvl" as "ident_lvl",
    coalesce("bp_attrib_value", cast("bp_attrib_nr" as text)) as "ident_value", startdate, enddate
	from "Ident_BP_Attrib"
  UNION
  Select "bp_sid", "loc_sid", "loc_attrib_sid" as "src_tbl_sid", "loc_code" as "code", "loc_string" as "id_string", "src_tbl", 'Location Attribute', 
    "ident_url", "loc_attrib_subtype" as "ident_type", "loc_attrib_lvl" as "ident_lvl",
    coalesce("loc_attrib_value", cast("loc_attrib_nr" as text)) as "ident_value", startdate, enddate
	from "Ident_Location"
  ) as "Tbl"
  Join "BP_Tbl" on "BP_Tbl"."bp_sid" = "Tbl"."bp_sid"
  Left JOIN "Translations_Tbl" ON "Translations_Tbl"."term" = "Tbl"."ident_type"

Where 1=1