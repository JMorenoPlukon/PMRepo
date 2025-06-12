WITH lang_tbl as (
  Select :CurrentUser_LanguageCode as lang 
  /* Select 'nl' as lang */
)
, current_user_tbl as (
  Select :CurrentUser_Email as crt_user	
  /* Select 'f.wester@plukon.nl'as crt_user */
)
, translations_tbl as (
Select 
  term,
  COALESCE((CASE WHEN lang_tbl.lang IN ( 'nl' ) THEN dutch
        ELSE (CASE WHEN lang_tbl.lang IN ( 'de' ) THEN german
          ELSE (CASE WHEN lang_tbl.lang IN ( 'fr' ) THEN french
            ELSE (CASE WHEN lang_tbl.lang IN ( 'pl' ) THEN polish
              ELSE (CASE WHEN lang_tbl.lang IN ( 'es' ) THEN spanish
                ELSE (CASE WHEN lang_tbl.lang IN ( 'dk' ) THEN danish
                  ELSE (CASE WHEN lang_tbl.lang IN ( 'en' ) THEN english
          END) END) END) END) END) END)
    END), term) AS term_trans
From "Translations"
Cross join lang_tbl
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
	bus_partners.sid as bp_sid, bus_partners.bp_cat, bus_partners."createdBy", bus_partners.bp_code, bus_partners.bpstatus, 
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

  AND (:bp_sid IS NULL 
      OR Cast(Coalesce(bus_partners.sid,'yyy') as varchar) 
        Ilike ANY(string_to_array(CONCAT('%',CAST(:bp_sid AS varchar),'%'), ','))    /* IN (SELECT DISTINCT "sid" FROM "Tbl_Bus_Partners" WHERE "bp_code" IN ( 'LEER', 'LEEM', 'LEEV', 'AKK', 'WOUK', '1WOUTE2', 'MANSM', 'DOCA', 'MECK1', 'GALLUS', 'BBV', 'ARKG', 'ARKG2', 'JANG' )) */
      )

) /* Select * From "BP_Tbl" */
, "VS_Ident_Attrib" as (
select "Tbl_Value_Sets"."value_set", "Tbl_Value_Sets"."vs_value", "Tbl_Value_Sets"."sid" as "pid", "Tbl_VS_Attrib"."vs_attrib_lvl", "Tbl_VS_Attrib"."vs_attrib_type", "VS_Attrib_Ctry"."vs_attrib_value"
from "Tbl_Value_Sets"
Join "Tbl_VS_Attrib" On "Tbl_VS_Attrib"."pid" = "Tbl_Value_Sets"."sid"
Join "Tbl_VS_Attrib" as "VS_Attrib_Ctry" On "VS_Attrib_Ctry"."pid" = "Tbl_Value_Sets"."sid"
where 1=1
And "Tbl_VS_Attrib"."vs_attrib_type" in ( 'Identification' )
And "VS_Attrib_Ctry"."vs_attrib_subtype" in ( 'Country' )
And "VS_Attrib_Ctry"."vs_attrib_lvl" = 1
And ("Tbl_Value_Sets".startdate is null or "Tbl_Value_Sets".startdate < now())
And ("Tbl_Value_Sets".enddate is null or "Tbl_Value_Sets".enddate >= date(now()))
And Coalesce("Tbl_Value_Sets"."isactive",true)
)
, "Ident_Address" as ( 
SELECT DISTINCT
  "Tbl_Addr_Attrib"."pid" as "addr_sid",
  "Tbl_Relations_BPLoc"."sid_to" as "bp_sid", 
  "Tbl_Addr_Attrib"."sid" as "addr_attrib_sid",
  "Tbl_Addr_Attrib"."addr_attrib_type",
  "Tbl_Addr_Attrib"."addr_attrib_subtype",
  "Tbl_Addr_Attrib"."addr_attrib_lvl",
  "Tbl_Addr_Attrib"."addr_attrib_value",
  "Tbl_Addr_Attrib"."addr_attrib_nr",
  "Tbl_Addr_Attrib".startdate,
  "Tbl_Addr_Attrib".enddate,
  "Tbl_Addr_Attrib"."isactive"
FROM "Tbl_Addr_Attrib"
  Join "VS_Ident_Attrib" 
  On "VS_Ident_Attrib"."value_set" = "Tbl_Addr_Attrib"."addr_attrib_type" 
  And "VS_Ident_Attrib"."vs_value" = "Tbl_Addr_Attrib"."addr_attrib_subtype" 

  Join "Tbl_Locations" On "Tbl_Locations"."pid" = "Tbl_Addr_Attrib"."pid"
  Join "Tbl_Relations_BPLoc" On "Tbl_Relations_BPLoc"."sid_subj" = "Tbl_Locations"."sid"
  Join "BP_Tbl" On "BP_Tbl"."bp_sid" = "Tbl_Relations_BPLoc"."sid_to"
Where 1=1
And ("Tbl_Addr_Attrib".enddate is null or "Tbl_Addr_Attrib".enddate >= date(now()))
And coalesce("Tbl_Addr_Attrib"."isactive", True)
And ("Tbl_Relations_BPLoc".enddate is null or "Tbl_Relations_BPLoc".enddate >= date(now()))
And coalesce("Tbl_Relations_BPLoc"."isactive", True)
)
, "BP_Prod_Addr_Tbl" as (
SELECT Distinct
  "Tbl_Relations_BPLoc"."sid_to" as "bp_sid",
  "Tbl_Relations_BPLoc"."rel_type_bploc",
  "Tbl_Addresses"."sid" as "linked_addr_sid",
  "Tbl_Locations"."sid" as "linked_loc_sid",
  Coalesce(translations_tbl.term_trans, "Tbl_Relations_BPLoc"."rel_type_bploc") as "addr_relation",
  "Tbl_Addresses"."addr_code",
  "BP_Tbl"."user_mail"
FROM "Tbl_Relations_BPLoc"
  Join "BP_Tbl" On "BP_Tbl"."bp_sid" = "Tbl_Relations_BPLoc"."sid_to"
  Join "Tbl_Value_Sets" On "Tbl_Value_Sets"."vs_value" = "Tbl_Relations_BPLoc"."rel_type_bploc"
  JOIN "Tbl_Locations" ON "Tbl_Locations"."sid" = "Tbl_Relations_BPLoc"."sid_subj"
  Join "Tbl_Addresses" ON "Tbl_Addresses"."sid" = "Tbl_Locations"."pid"
  Left Join translations_tbl ON translations_tbl.term = "Tbl_Relations_BPLoc".rel_type_bploc

Where 1=1
And "Tbl_Value_Sets"."value_set" in ( 'Comp - Location Relation' )
And "Tbl_Relations_BPLoc"."rel_type_bploc" not IN ( 'Address Reg' )
And ("Tbl_Relations_BPLoc".enddate is null or "Tbl_Relations_BPLoc".enddate >= date(now()))
And coalesce("Tbl_Relations_BPLoc"."isactive", True)
And ("Tbl_Value_Sets".enddate is null or "Tbl_Value_Sets".enddate >= date(now()))
And Coalesce("Tbl_Value_Sets"."isactive",true))
, "BPKRAS_SidTo_Tbl" as (
Select distinct "bp_sid", bpstatus, "sid_to", "user_mail"
From (Select bp_sid, bpstatus, bp_sid as sid_to, user_mail from "BP_Tbl"
      UNION
      Select bp_sid, null, linked_addr_sid, user_mail from "BP_Prod_Addr_Tbl"
	  ) as Tbl
)
SELECT DISTINCT 
  "Tbl_Relations_BPLoc"."sid_to" AS "bp_sid",
  (Case when "BPKRAS_SidTo_Tbl".bpstatus in ( 'APPROVED', 'APPROVED_COMPANY_HYP_INPUT_REQUESTED', 'APPROVED_COMPANY_HYP_FARMER_CHANGE', 'APPROVED_COMPANY_HYP_FARMER_CHANGE_PENDING',
												'APPROVED_COMPANY_HYP_FARMER_REJECTED', 'APPROVED_COMPANY_HYP_CHANGE', 'BLACKLIST', 'CLOSED' ) 
	Then 'Approved' Else 'Not Approved' 
	End) as bpstatus, 
  "Tbl_Addresses"."sid" as "addr_sid",
  "Ident_Address"."addr_attrib_sid",
  "Tbl_Addresses"."addr_code",
  "Tbl_Addresses"."country",
  COALESCE(translations_tbl."term_trans","Tbl_Addresses"."country") AS "country_lang",
  "Tbl_Addresses"."addr_name",
  "Tbl_Addresses"."village",
  "Tbl_Addresses"."street",
  "Tbl_Addresses"."house_nr",
  "Tbl_Addresses"."house_nr_ext",
  "Tbl_Addresses"."postal_code",
  Coalesce("Tbl_Addresses"."addr_name" || ' - ','') || Coalesce("Tbl_Addresses"."street" || ' ','') 
    || Coalesce(Coalesce(Cast("Tbl_Addresses"."house_nr" as text),'') || coalesce('-' || "Tbl_Addresses"."house_nr_ext",'') || ', ','') 
	|| Coalesce("Tbl_Addresses"."postal_code" || ' ', ' ' ) || Coalesce("Tbl_Addresses"."village" || ' ','') ||  Coalesce("Tbl_Addresses"."country",'') 
     as "addr_string",
  COALESCE("Trans_Ident"."term_trans","addr_attrib_subtype") as "ident_type", 
  (case when "addr_attrib_value" is null then Cast("addr_attrib_nr" as text) else "addr_attrib_value" end) as "ident_value"
FROM "Tbl_Relations_BPLoc"
  JOIN "Tbl_Locations" ON "Tbl_Locations"."sid" = "Tbl_Relations_BPLoc"."sid_subj"
  JOIN "Tbl_Addresses" ON "Tbl_Addresses"."sid" = "Tbl_Locations"."pid"
  JOIN "Tbl_Value_Sets" On "Tbl_Value_Sets"."vs_value" = "Tbl_Relations_BPLoc"."rel_type_bploc"
  Join "BPKRAS_SidTo_Tbl" On "BPKRAS_SidTo_Tbl"."sid_to" = "Tbl_Relations_BPLoc"."sid_to"

  Left Join "BP_Prod_Addr_Tbl" On "BP_Prod_Addr_Tbl"."linked_addr_sid" = "Tbl_Locations"."pid"
  Left Join "Ident_Address" ON "Ident_Address"."addr_sid" = "Tbl_Addresses"."sid"

  Left JOIN translations_tbl ON translations_tbl."term" = "Tbl_Addresses"."country"
  Left JOIN translations_tbl as "Trans_Ident" ON "Trans_Ident"."term" = "addr_attrib_subtype"

WHERE 1=1
  AND "Tbl_Value_Sets"."value_set" in ( 'Comp - Location Relation', 'Address Relation' )
  And ("Tbl_Value_Sets".startdate is null or "Tbl_Value_Sets".startdate < now())
  And ("Tbl_Value_Sets".enddate is null or "Tbl_Value_Sets".enddate >= date(now()))
  And Coalesce("Tbl_Value_Sets"."isactive",true)

  AND (:rel_type_bploc IS NULL 
      OR Cast(Coalesce("Tbl_Relations_BPLoc".rel_type_bploc,'yyy') as varchar) 
        /* NOT */ 
		Ilike ANY(string_to_array(CONCAT('%',CAST(:rel_type_bploc AS varchar),'%'), ',')) /* ( 'Stable Loc', 'Address Reg' ) */
      )

  And ("Tbl_Locations".enddate is null or "Tbl_Locations".enddate >= date(now()))
  And Coalesce("Tbl_Locations"."isactive",true)
  And ("Tbl_Relations_BPLoc".enddate is null or "Tbl_Relations_BPLoc".enddate >= date(now()))
  And Coalesce("Tbl_Relations_BPLoc"."isactive",true)


Order By 1, 2, 3, 4