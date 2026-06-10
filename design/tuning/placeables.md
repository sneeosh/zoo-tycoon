# Placeables — Zoo

<!--
v0.4.0: things that go INSIDE a region (an exhibit, made up of
connected zone-tile entities from entities.md). Three flavors:

  - Animals: the main attraction. Each has space, social, habitat
    requirements; contribute appeal axes to their containing region.
  - Infrastructure: feeding troughs, water troughs. Don't contribute
    appeal themselves, but provide tags (provides_food, provides_water)
    that animals' happiness needs.
  - Habitat & enrichment (the ZT1 exhibit-authoring layer): foliage,
    rocks, shelters, and toys. space_required 0 — they share tiles with
    the animals, so decorating a pen never crowds anyone out. Their
    own_tags (foliage / plant_* / rock_item / shelter / enrichment) feed
    the per-species habitat axes in design/tuning/habitat.md; the model
    in src/models/zoo_animal_happiness.gd scores them.

The engine ships IPlaceableHappiness as an extension point — zoo's
implementation is in src/models/zoo_animal_happiness.gd and follows
design/algorithms/animal_happiness.md.
-->

## Placeables

| id             | display_name   | sprite_key     | build_cost | maintenance_cost | space_required | space_ideal | social_min | social_max | required_zone_tags | incompatible_tags | own_tags                       | needs_provided_tags          | appeal_contribution           |
| -------------- | -------------- | -------------- | ---------- | ---------------- | -------------- | ----------- | ---------- | ---------- | ------------------ | ----------------- | ------------------------------ | ---------------------------- | ----------------------------- |
| lion           | Lion           | lion           | 600        | 6                | 3              | 4           | 1          | 3          | grass,rocks        | prey              | predator,big_cat               | provides_food,provides_water | thrill:0.8,danger:0.6         |
| zebra          | Zebra          | zebra          | 250        | 3                | 2              | 3           | 3          | 8          | grass              | predator          | prey,herd                      | provides_food,provides_water | beauty:0.4,herd_appeal:0.5    |
| elephant       | Elephant       | elephant       | 800        | 8                | 4              | 6           | 1          | 4          | grass,water        |                   | big,exotic                     | provides_food,provides_water | thrill:0.5,exotic:0.8         |
| parrot         | Parrot         | parrot         | 120        | 1                | 1              | 1           | 2          | 8          | tall_cage          |                   | bird,colorful                  | provides_food                | beauty:0.5,exotic:0.7         |
| penguin        | Penguin        | penguin        | 200        | 2                | 1              | 1           | 4          | 20         | water              |                   | bird,social                    | provides_food                | cute:0.8,beauty:0.5           |
| flamingo       | Flamingo       | flamingo       | 300        | 2                | 1              | 1           | 3          | 10         | water              |                   | bird,colorful,herd             | provides_food                | beauty:0.7,exotic:0.4         |
| toucan         | Toucan         | toucan         | 200        | 1                | 1              | 1           | 1          | 3          | tall_cage          |                   | bird,colorful,exotic           | provides_food                | beauty:0.6,exotic:0.6         |
| peacock        | Peacock        | peacock        | 250        | 2                | 1              | 1           | 1          | 4          | grass              |                   | bird,colorful                  | provides_food                | beauty:0.9,exotic:0.5         |
| giraffe        | Giraffe        | giraffe        | 500        | 5                | 3              | 4           | 2          | 6          | grass              | predator          | prey,herd,tall,exotic          | provides_food,provides_water | beauty:0.5,exotic:0.7         |
| tiger          | Tiger          | tiger          | 700        | 6                | 3              | 4           | 1          | 2          | grass,rocks        | prey              | predator,big_cat,exotic        | provides_food,provides_water | thrill:0.9,danger:0.7         |
| monkey         | Monkey         | monkey         | 200        | 2                | 1              | 2           | 4          | 12         | tall_cage          |                   | primate,social,playful         | provides_food                | cute:0.7,playful:0.8          |
| seal           | Seal           | seal           | 350        | 3                | 2              | 3           | 3          | 8          | water              |                   | aquatic,social,playful         | provides_food                | cute:0.8,exotic:0.4           |
| polar_bear     | Polar Bear     | polar_bear     | 800        | 7                | 3              | 5           | 1          | 2          | water,rocks        | prey              | predator,big,cold              | provides_food,provides_water | thrill:0.7,exotic:0.8         |
| feeding_trough | Feeding Trough | feeding_trough | 60         | 2                | 1              | 1           | 0          | 99         |                    |                   | provides_food,infrastructure   |                              |                               |
| water_trough   | Water Trough   | water_trough   | 50         | 1                | 1              | 1           | 0          | 99         |                    |                   | provides_water,infrastructure  |                              |                               |
| donation_box   | Donation Box   | donation_box   | 80         | 0                | 1              | 1           | 0          | 99         |                    |                   | donation_box,infrastructure    |                              |                               |
| acacia_tree    | Acacia Tree    | tree_oak       | 75         | 0                | 0              | 0           | 0          | 99         |                    |                   | foliage,plant_savannah         |                              |                               |
| shrub          | Shrub          | bush_large     | 35         | 0                | 0              | 0           | 0          | 99         |                    |                   | foliage,plant_savannah         |                              |                               |
| palm_tree      | Palm Tree      | tree_palm      | 80         | 0                | 0              | 0           | 0          | 99         |                    |                   | foliage,plant_rainforest       |                              |                               |
| fern           | Fern           | bush_small     | 40         | 0                | 0              | 0           | 0          | 99         |                    |                   | foliage,plant_rainforest       |                              |                               |
| pine_tree      | Pine Tree      | tree_pine      | 60         | 0                | 0              | 0           | 0          | 99         |                    |                   | foliage,plant_conifer          |                              |                               |
| birch_tree     | Birch Tree     | tree_birch     | 60         | 0                | 0              | 0           | 0          | 99         |                    |                   | foliage,plant_conifer          |                              |                               |
| rock_small     | Small Rock     | boulder        | 50         | 0                | 0              | 0           | 0          | 99         |                    |                   | rock_item                      |                              |                               |
| rock_large     | Large Rock     | boulder        | 120        | 0                | 0              | 0           | 0          | 99         |                    |                   | rock_item,rock_big             |                              |                               |
| wood_shelter   | Wood Shelter   | wood_shelter   | 250        | 1                | 0              | 0           | 0          | 99         |                    |                   | shelter,infrastructure         |                              |                               |
| rock_cave      | Rock Cave      | rock_cave      | 400        | 1                | 0              | 0           | 0          | 99         |                    |                   | shelter,infrastructure         |                              |                               |
| toy_ball       | Play Ball      | toy_ball       | 80         | 1                | 0              | 0           | 0          | 99         |                    |                   | enrichment,infrastructure      |                              |                               |
| climbing_stump | Climbing Stump | tree_stump     | 120        | 1                | 0              | 0           | 0          | 99         |                    |                   | enrichment,infrastructure      |                              |                               |
