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
  COALESCE((CASE WHEN "lang_tbl".lang IN ( 'nl' ) THEN "dutch"
        ELSE (CASE WHEN "lang_tbl".lang IN ( 'de' ) THEN "german"
          ELSE (CASE WHEN "lang_tbl".lang IN ( 'fr' ) THEN "french"
            ELSE (CASE WHEN "lang_tbl".lang IN ( 'pl' ) THEN "polish"
              ELSE (CASE WHEN "lang_tbl".lang IN ( 'es' ) THEN "spanish"
                ELSE (CASE WHEN "lang_tbl".lang IN ( 'dk' ) THEN "danish"
                  ELSE (CASE WHEN "lang_tbl".lang IN ( 'en' ) THEN "english"
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
  And ("Tbl_BP_Attrib"."startdate" is Null or "Tbl_BP_Attrib"."startdate" < now())
  And ("Tbl_BP_Attrib"."enddate" is Null or "Tbl_BP_Attrib"."enddate" > date(now())+1)
  And coalesce("Tbl_BP_Attrib"."isactive", True)
)
, pm_user_tbl as (
Select Distinct
	"Tbl_Bus_Partners".sid as user_sid, "Tbl_Bus_Partners".pers_id as user_mail, bp_vba_tbl.bp_attrib_subtype, bp_vba_tbl.bp_attrib_value
From "Tbl_Bus_Partners"
  Join  bp_vba_tbl On bp_vba_tbl.pid = "Tbl_Bus_Partners".sid  
Where 1=1
  And "Tbl_Bus_Partners".bp_cat in ( 'PM User' )

  And "Tbl_Bus_Partners".pers_id in (select crt_user from current_user_tbl)
) 
, bus_partners as (
Select sid, bp_cat, "createdBy", "modifiedBy", "modifiedDate", startdate, enddate, bp_code, bp_name, first_name, family_name, pers_id_type, pers_id, bpstatus, isactive
From "Tbl_Bus_Partners" 
Where 1=1
) 
, bp_tbl as (
Select Distinct
	bus_partners.sid as bp_sid, bus_partners.bp_cat, bpstatus, bp_code, bp_name
From  bus_partners
  Left Join bp_vba_tbl 
  On bp_vba_tbl.pid = bus_partners.sid

  Left Join pm_user_tbl
  On ((pm_user_tbl."bp_attrib_subtype" = bp_vba_tbl."bp_attrib_subtype" And pm_user_tbl."bp_attrib_value" = bp_vba_tbl."bp_attrib_value")
  
      Or bus_partners."createdBy" in (select crt_user from current_user_tbl)

      Or bus_partners.bp_cat in ( 'Person' )
      )
Where 1=1
  
  And bp_cat in ( 'Company', 'Government', 'Person' )

  AND (:bp_sid IS NULL 
      OR Cast(COALESCE(bus_partners.sid,'yyy') as varchar) /* bus_partners.sid IN (SELECT DISTINCT "sid" FROM "Tbl_Bus_Partners" WHERE "bp_code" IN ( 'LEER', 'LEEM', 'LEEV', 'AKK', 'WOUK', '1WOUTE2', 'MANSM', 'DOCA', 'MECK1', 'GALLUS', 'BBV', 'ARKG', 'ARKG2', 'JANG', 'NIJH' )) */
        Ilike ANY(string_to_array(CONCAT('%',CAST(:bp_sid AS varchar),'%'), ',')) 
      )

) /* select * From bp_tbl */
, flocks_shortlist as (
select flocknr as flocknr_list
From "Tbl_Flocks"
where 1 = 1
And install_date < now()
order by install_date desc
limit 100
)
, flocks_tbl as (
Select "Tbl_Flocks".*, bp_name, bp_sid
From "Tbl_Flocks"
  Join bp_tbl On bp_tbl.bp_code = "Tbl_Flocks".bp_code
Where 1=1

And (Case when coalesce(cast(:flocknr as text), cast(:farmer as text),cast(:building_id as text),cast(:bp_sid as text)) is null
		Then "Tbl_Flocks".flocknr in (Select flocknr_list from flocks_shortlist)
		Else (:flocknr IS NULL OR Cast(COALESCE("Tbl_Flocks".flocknr,'yyy') as varchar)  Ilike ANY(string_to_array(CONCAT('%',CAST(:flocknr AS varchar),'%'), ',')))
    End)

)
, flock_attrib_tbl as (
Select "Tbl_Flock_Attrib".*, flocks_tbl.loc_code
From flocks_tbl
  Join "Tbl_Flock_Attrib"  On "Tbl_Flock_Attrib".pid = flocks_tbl.sid
)
, flock_qty_tbl as (
Select pid as flock_pid,
	flock_attrib_subtype as qty_type, 
	sum(flock_attrib_tbl.flock_attrib_nr) as qty
From flock_attrib_tbl
Where 1=1
And flock_attrib_tbl.flock_attrib_type in ( 'Quantities' )
Group By pid, flock_attrib_subtype
) 
, flock_feed_spl_src as (
Select distinct pid as flock_pid, loc_code, flock_attrib_value as feed_supplier
From flock_attrib_tbl
Where 1=1
And flock_attrib_tbl.flock_attrib_type in ( 'Company' )
And flock_attrib_tbl.flock_attrib_subtype in ( 'Feed Supplier' ) 
)
, flock_feed_spl as (
Select flock_pid, loc_code, 
    string_agg(feed_supplier, ', ' order by feed_supplier) as feed_supplier_list
From flock_feed_spl_src
Group By flock_pid, loc_code
) /* select * From flock_feed_spl */
Select distinct
  flocks_tbl.sid as flock_sid,
  bp_sid,
  "Tbl_Locations".sid as loc_sid,
  flocknr,
  flocks_tbl.bp_code,
  flocks_tbl.bp_name,
  coalesce(flocks_tbl.bp_code,'') || ' - '|| coalesce(flocks_tbl.bp_name,'') as farmer,
  flocks_tbl.loc_code,
  Coalesce(loc_name, '') || Coalesce( '-' || loc_nr, '') as building_id,
  flock_round_nr,
  install_date,
  flocks_tbl.enddate,
  expect_qty_tbl.qty as qty_expected,
  plan_qty_tbl.qty as qty_planned,
  breed,
  flock_cat,
  flock_status,
  data_status,
  salmo_status,
  hatchery,
  hatch_date,
  hatching_system,
  bird_type,
  concept,
  feed_supplier_list,
  origin,
  flocknr_ps_id,
  flocks_tbl.isactive as is_active
From flocks_tbl
  Left Join "Tbl_Locations" on "Tbl_Locations".loc_code = flocks_tbl.loc_code

  Left Join flock_qty_tbl as expect_qty_tbl
  on expect_qty_tbl.flock_pid = flocks_tbl.sid
  And expect_qty_tbl.qty_type in ( 'Expected' )
  Left Join flock_qty_tbl as plan_qty_tbl
  on plan_qty_tbl.flock_pid = flocks_tbl.sid
  And plan_qty_tbl.qty_type in ( 'Planned' )

  Left Join flock_feed_spl on flock_feed_spl.flock_pid = flocks_tbl.sid

Where 1=1

  AND (:flock_sid IS NULL 
      OR Cast(COALESCE(flocks_tbl.sid,'yyy') as varchar)
        Ilike ANY(string_to_array(CONCAT('%',CAST(:flock_sid AS varchar),'%'), ',')) 
      ) 
  AND (:farmer IS NULL 
      OR Cast(COALESCE(coalesce(flocks_tbl.bp_code,'') || ' - '|| coalesce(flocks_tbl.bp_name,''),'yyy') as varchar) 
        Ilike ANY(string_to_array(CONCAT('%',CAST(:farmer AS varchar),'%'), ',')) 
      )
  AND (:building_id IS NULL 
      OR Cast(COALESCE(Coalesce(loc_name, '') || Coalesce( '-' || loc_nr, ''),'yyy') as varchar) 
        Ilike ANY(string_to_array(CONCAT('%',CAST(:building_id AS varchar),'%'), ',')) 
      )

Order by bp_code, install_date desc