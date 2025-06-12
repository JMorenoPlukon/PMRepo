SELECT DISTINCT
  "Tbl"."pid" as "bp_sid",
  "Tbl"."sid" as "bp_attrib_sid",
  "Tbl"."bp_attrib_lvl" as "comm_lvl",
  "Tbl"."bp_attrib_value" as "comm_type"
FROM (Select *, row_number() over (partition by "pid" order by bp_attrib_lvl, bp_attrib_value) as "rec_nr"
      From "Tbl_BP_Attrib"
      Where 1=1
      And "bp_attrib_subtype" in ( 'Email' ) /* 'Mobile', 'Tel' */
      And (enddate is null or enddate >= date(now()))
      And Coalesce("isactive",true)
	) as "Tbl"
WHERE 1=1
And "rec_nr" = 1
And "Tbl"."pid"=:bp_sid /* IN (SELECT DISTINCT "sid" FROM "Tbl_Bus_Partners" WHERE "bp_code" IN ( 'AKK', '1WOUTE2', 'MANSM', 'MECK1' )) */