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
	bus_partners.sid as bp_sid, bus_partners.bp_cat, bus_partners."createdBy", bus_partners.bp_code, bp_vba_tbl.bp_attrib_subtype, bp_vba_tbl.bp_attrib_value, user_mail
From  bus_partners
  Left Join bp_vba_tbl On bp_vba_tbl.pid = bus_partners.sid

  Join "PM_User_Tbl"
  On (("PM_User_Tbl"."bp_attrib_subtype" = bp_vba_tbl."bp_attrib_subtype" And "PM_User_Tbl"."bp_attrib_value" = bp_vba_tbl."bp_attrib_value")
  
      Or bus_partners."createdBy" in (select crt_user from current_user_tbl)

      Or bus_partners.bp_cat in ( 'Person' )
      )
Where 1=1
  
And bus_partners.sid=:bp_sid /* IN (SELECT DISTINCT "sid" FROM "Tbl_Bus_Partners" WHERE "bp_code" IN ( 'LEER', 'LEEM', 'LEEV', 'AKK', 'WOUK', '1WOUTE2', 'MANSM', 'DOCA', 'MECK1', 'GALLUS', 'BBV', 'ARKG', 'ARKG2', 'JANG' )) */

) /* Select * From "BP_Tbl" */
SELECT DISTINCT
  "Tbl"."pid" as "bp_sid",
  "Tbl"."sid" as "bp_attrib_sid",
  "Tbl"."bp_attrib_value" as "bp_type", 
  COALESCE("Translations_Tbl"."term_trans","Tbl"."bp_attrib_value") as "bp_type_lang",
  "Tbl"."bp_attrib_lvl"
FROM (Select "Tbl_BP_Attrib".*, row_number() over (partition by "pid" order by "Tbl_BP_Attrib"."bp_attrib_lvl", "Tbl_BP_Attrib"."bp_attrib_value") as "rec_nr"
      From "Tbl_BP_Attrib"
      Join "BP_Tbl" On "BP_Tbl"."bp_sid" = "Tbl_BP_Attrib"."pid"
      Where 1=1
      And "Tbl_BP_Attrib".bp_attrib_type in ( 'BP Type' )
      And (enddate is null or enddate >= date(now()))
      And Coalesce("isactive",true)
	) as "Tbl"
  Left JOIN "Translations_Tbl" ON "Translations_Tbl"."term" = "Tbl"."bp_attrib_value"
where 1=1
and "rec_nr" = 1