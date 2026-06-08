# Marketing — Zoo

<!--
Roadmap 4.2 (Marketing campaigns). Spend cash to bias guest arrivals toward a
chosen archetype for a few days — closing the loop between investment and
visitor mix. Build a park of cute animals, then run a "Family" campaign to
pack it with high-spending families. While a campaign runs, the target
archetype's spawn weight is multiplied by campaign_boost; one campaign at a
time.

Game-side tuning (the engine doesn't read it), compiled by
src/marketing_config.gd; the campaign logic lives in src/bootstrap.gd.
-->

## Settings

campaign_cost  = 800
campaign_days  = 5
campaign_boost = 3.0
