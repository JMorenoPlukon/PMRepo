WITH lang_tbl as (
  Select :CurrentUser_LanguageCode as lang 
  /* Select 'nl' as lang */
)
, current_user_tbl as (
  Select :CurrentUser_Email as crt_user	
  /* Select 'f.wester@plukon.nl'as crt_user */
)
, "Translations_Tbl" as (
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
  bus_partners.sid as bp_sid, bus_partners.bp_cat, bus_partners."createdBy", bus_partners.bp_code, bus_partners.bp_name,
  bp_vba_tbl.bp_attrib_subtype, bp_vba_tbl.bp_attrib_value, user_mail
From  bus_partners
  Left Join bp_vba_tbl 
  On bp_vba_tbl.pid = bus_partners.sid

  Join "PM_User_Tbl"
  On (("PM_User_Tbl"."bp_attrib_subtype" = bp_vba_tbl."bp_attrib_subtype" And "PM_User_Tbl"."bp_attrib_value" = bp_vba_tbl."bp_attrib_value")
  
      Or bus_partners."createdBy" in (select crt_user from current_user_tbl)

      Or bus_partners.bp_cat in ( 'Person' )
      )
Where 1=1
  
And bus_partners.sid=:bp_sid /* IN (SELECT DISTINCT "sid" FROM "Tbl_Bus_Partners" WHERE "bp_code" IN ( 'LEER', 'LEEM', 'LEEV', 'AKK', 'WOUK', '1WOUTE2', 'MANSM', 'DOCA', 'MECK1', 'GALLUS', 'BBV', 'ARKG', 'ARKG2', 'JANG', 'JALB', 'RAMZA' )) */

) /* Select * From "BP_Tbl" */
, "BP_Prod_Addr_Tbl" as (
SELECT Distinct
  "Tbl_Relations_BPLoc"."sid_to" as "bp_sid",
  "Tbl_Relations_BPLoc"."rel_type_bploc",
  "Tbl_Addresses"."sid" as "linked_addr_sid",
  "Tbl_Locations"."sid" as "linked_loc_sid",
  "Tbl_Relations_BPLoc"."rel_type_bploc" as "addr_relation",
  "Tbl_Addresses"."addr_code"
FROM "Tbl_Relations_BPLoc"
  Join "BP_Tbl" On "BP_Tbl"."bp_sid" = "Tbl_Relations_BPLoc"."sid_to"
  Join "Tbl_Value_Sets" On "Tbl_Value_Sets"."vs_value" = "Tbl_Relations_BPLoc"."rel_type_bploc"
  JOIN "Tbl_Locations" ON "Tbl_Locations"."sid" = "Tbl_Relations_BPLoc"."sid_subj"
  Join "Tbl_Addresses" ON "Tbl_Addresses"."sid" = "Tbl_Locations"."pid"
Where 1=1
And "Tbl_Value_Sets"."value_set" in ( 'Comp - Location Relation' )
And "Tbl_Relations_BPLoc"."rel_type_bploc" not IN ( 'Address Reg' )
And ("Tbl_Relations_BPLoc".enddate is null or "Tbl_Relations_BPLoc".enddate >= date(now()))
And coalesce("Tbl_Relations_BPLoc"."isactive", True)
And ("Tbl_Value_Sets".enddate is null or "Tbl_Value_Sets".enddate >= date(now()))
And Coalesce("Tbl_Value_Sets"."isactive",true)
) /* Select * From "BP_Prod_Addr_Tbl"  */
, "BP_Rel_Subj_Tbl" as (
SELECT Distinct
  "Tbl_Relations_BPLoc"."sid_to" as "rel_sid",
  "Tbl_Relations_BPLoc"."sid_subj" as "bp_sid",
  "Tbl_Relations_BPLoc"."sid" as "rel_bploc_sid",
  "Tbl_Relations_BPLoc"."rel_maintype_bploc" as "rel_maintype_bploc",
  COALESCE("Trans_Rel_MainType_Tbl"."term_trans","Tbl_Relations_BPLoc"."rel_maintype_bploc") AS "rel_maintype_bploc_lang",
  "Tbl_Relations_BPLoc"."rel_type_bploc" as "rel_type_bploc",
  COALESCE("Translations_Tbl"."term_trans","Tbl_Relations_BPLoc"."rel_type_bploc") AS "rel_type_bploc_lang",
  "Tbl_Relations_BPLoc"."rel_lvl",
  "Tbl_Relations_BPLoc"."rel_bploc_value",
  "Tbl_Relations_BPLoc"."rel_bploc_nr",
  "Tbl_Relations_BPLoc".startdate,
  "Tbl_Relations_BPLoc".enddate
FROM "Tbl_Relations_BPLoc"
  Join (Select distinct bp_sid as rel_subj_sid from "BP_Tbl" 
        UNION
        Select distinct linked_loc_sid from "BP_Prod_Addr_Tbl"
        ) As rel_subj_tbl
  On rel_subj_tbl.rel_subj_sid = "Tbl_Relations_BPLoc".sid_subj
  Left JOIN "Translations_Tbl" as "Trans_Rel_MainType_Tbl" ON "Trans_Rel_MainType_Tbl"."term" = "Tbl_Relations_BPLoc"."rel_maintype_bploc"
  Left JOIN "Translations_Tbl" ON "Translations_Tbl"."term" = "Tbl_Relations_BPLoc"."rel_type_bploc"
Where 1=1
  And ("Tbl_Relations_BPLoc".enddate is null or "Tbl_Relations_BPLoc".enddate >= date(now()))
  And Coalesce("Tbl_Relations_BPLoc"."isactive",true)
)
, "BP_Rel_To_Tbl" as (
SELECT Distinct
  "Tbl_Relations_BPLoc"."sid_to" as "bp_sid",
  "Tbl_Relations_BPLoc"."sid_subj" as "rel_sid",
  "Tbl_Relations_BPLoc"."sid" as "rel_bploc_sid",
  "Tbl_Relations_BPLoc"."rel_maintype_bploc" as "rel_maintype_bploc",
  COALESCE("Trans_Rel_MainType_Tbl"."term_trans","Tbl_Relations_BPLoc"."rel_maintype_bploc") AS "rel_maintype_bploc_lang",
  "Tbl_Relations_BPLoc"."rel_type_bploc" as "rel_type_bploc",
  COALESCE("Translations_Tbl"."term_trans","Tbl_Relations_BPLoc"."rel_type_bploc") AS "rel_type_bploc_lang",
  "Tbl_Relations_BPLoc"."rel_lvl",
  "Tbl_Relations_BPLoc"."rel_bploc_value",
  "Tbl_Relations_BPLoc"."rel_bploc_nr",
  "Tbl_Relations_BPLoc".startdate,
  "Tbl_Relations_BPLoc".enddate
FROM "Tbl_Relations_BPLoc"
  Join (Select distinct bp_sid as rel_to_sid from "BP_Tbl" 
        UNION
        Select distinct linked_loc_sid from "BP_Prod_Addr_Tbl"
        ) As rel_to_tbl
  On rel_to_tbl.rel_to_sid = "Tbl_Relations_BPLoc".sid_to
  Left JOIN "Translations_Tbl" as "Trans_Rel_MainType_Tbl" ON "Trans_Rel_MainType_Tbl"."term" = "Tbl_Relations_BPLoc"."rel_maintype_bploc"
  Left JOIN "Translations_Tbl" ON "Translations_Tbl"."term" = "Tbl_Relations_BPLoc"."rel_type_bploc"
Where 1=1
  And ("Tbl_Relations_BPLoc".enddate is null or "Tbl_Relations_BPLoc".enddate >= date(now()))
  And Coalesce("Tbl_Relations_BPLoc"."isactive",true)
)
SELECT DISTINCT 
  "Tbl"."bp_sid",
  "Tbl"."rel_bploc_sid",
  "Tbl"."rel_sid",
  Coalesce("Tbl_Bus_Partners".bp_code || ' - ', '') || Coalesce("Tbl_Bus_Partners".bp_name, '') as "bp_name",
  "Tbl"."rel_maintype_bploc",
  "Tbl"."rel_maintype_bploc_lang",
  "Tbl"."rel_type_bploc",
  "Tbl"."rel_type_bploc_lang",
  "Tbl"."rel_lvl",
  Coalesce(Cast ("Tbl"."rel_bploc_nr" as text), "Tbl"."rel_bploc_value") as "rel_bploc_value",
  "Tbl"."rel_bploc_nr",
  "BP_Rel_Tbl"."bp_code",
  "BP_Rel_Tbl"."bp_cat",
  Coalesce(nullif(Coalesce("Tbl_Bus_Partners".bp_code || ' - ', '') || Coalesce("Tbl_Bus_Partners".bp_name, ''),''),
            Coalesce(Coalesce("Translations_Tbl"."term_trans","Loc_Rel_To_Tbl".loc_cat) || ': ' ||"Loc_Rel_To_Tbl".loc_name || '-', '') || Coalesce( "Loc_Rel_To_Tbl".loc_nr, '')
          ) as "rel_to_name",
  Coalesce("BP_Rel_Tbl"."bp_code" || ' - ', '') || Coalesce("BP_Rel_Tbl"."bp_name", '') as "rel_subj_name"
From (SELECT DISTINCT bp_sid, rel_sid, rel_bploc_sid, rel_maintype_bploc, rel_maintype_bploc_lang, rel_type_bploc, rel_type_bploc_lang, rel_lvl, rel_bploc_value, rel_bploc_nr,
		    startdate, enddate
      From "BP_Rel_To_Tbl"
      UNION
      SELECT DISTINCT bp_sid, rel_sid, rel_bploc_sid, rel_maintype_bploc, rel_maintype_bploc_lang, rel_type_bploc, rel_type_bploc_lang, rel_lvl, rel_bploc_value, rel_bploc_nr,
		    startdate, enddate
	    From "BP_Rel_Subj_Tbl"
    ) As "Tbl"
  Join (Select distinct bp_sid from "BP_Tbl" 
        UNION
        Select distinct linked_loc_sid from "BP_Prod_Addr_Tbl"
        ) as bp_loc_tbl
  on bp_loc_tbl."bp_sid" = "Tbl"."bp_sid"
  Left Join "Tbl_Bus_Partners" ON "Tbl_Bus_Partners"."sid" = "Tbl"."bp_sid"
  Left Join "Tbl_Locations" as "Loc_Rel_To_Tbl" ON "Loc_Rel_To_Tbl".sid = "Tbl".bp_sid
  Left Join "Tbl_Bus_Partners" as "BP_Rel_Tbl" ON "BP_Rel_Tbl"."sid" = "Tbl"."rel_sid"
  Join "Tbl_Value_Sets" On "Tbl_Value_Sets"."vs_value" = "Tbl"."rel_type_bploc"
  Left JOIN "Translations_Tbl" ON "Translations_Tbl"."term" = "Loc_Rel_To_Tbl".loc_cat
Where 1=1
  And "Tbl_Value_Sets"."value_set" in ( 'Finance Relation', 'Finance Location Relation' )
  And ("Tbl_Value_Sets".startdate is null or "Tbl_Value_Sets".startdate < now())
  And ("Tbl_Value_Sets".enddate is null or "Tbl_Value_Sets".enddate >= date(now()))
  And Coalesce("Tbl_Value_Sets"."isactive",true)

UNION

SELECT DISTINCT 
  "Tbl_BP_Attrib"."pid" AS "bp_sid",
  "Tbl_BP_Attrib"."sid" AS "bp_attrib_sid",
  Null, Null,
  "Tbl_BP_Attrib"."bp_attrib_type",
  COALESCE("Translations_Tbl"."term_trans","Tbl_BP_Attrib"."bp_attrib_type") AS "bp_attrib_type_lang",
  "Tbl_BP_Attrib"."bp_attrib_subtype",
  COALESCE("Trans_SubType"."term_trans","Tbl_BP_Attrib"."bp_attrib_subtype") as "bp_attrib_subtype_lang",
  "Tbl_BP_Attrib"."bp_attrib_lvl",
  Coalesce(Cast ("Tbl_BP_Attrib"."bp_attrib_nr" as text), Coalesce("Trans_Value"."term_trans","Tbl_BP_Attrib"."bp_attrib_value")) as "bp_attrib_value",
  "Tbl_BP_Attrib".bp_attrib_nr,
  "BP_Tbl".bp_code,
  "BP_Tbl".bp_cat,
  Null as "rel_to_name",
  Null as "rel_subj_name"
FROM "Tbl_BP_Attrib"
  Join "BP_Tbl" on "BP_Tbl"."bp_sid" = "Tbl_BP_Attrib"."pid"
  Left JOIN "Translations_Tbl" ON "Translations_Tbl"."term" = "Tbl_BP_Attrib"."bp_attrib_type"
  Left JOIN "Translations_Tbl" as "Trans_SubType" ON "Trans_SubType"."term" = "Tbl_BP_Attrib"."bp_attrib_subtype"
  Left JOIN "Translations_Tbl" as "Trans_Value" ON "Trans_Value"."term" = "Tbl_BP_Attrib"."bp_attrib_value"
WHERE 1=1
  AND "Tbl_BP_Attrib"."bp_attrib_type" IN ( 'BP ID FinType', 'BP Financial Exact', 'BP Financial VAT' )
  And ("Tbl_BP_Attrib".enddate is Null or "Tbl_BP_Attrib".enddate >= date(now()))
  And coalesce("Tbl_BP_Attrib"."isactive", True)