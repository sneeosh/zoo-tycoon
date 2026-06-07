# Placeables — Zoo

<!--
v0.4.0: things that go INSIDE a region (an exhibit, made up of
connected zone-tile entities from entities.md). Two flavors:

  - Animals: the main attraction. Each has space, social, habitat
    requirements; contribute appeal axes to their containing region.
  - Infrastructure: feeding troughs, water troughs. Don't contribute
    appeal themselves, but provide tags (provides_food, provides_water)
    that animals' happiness needs.

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
| feeding_trough | Feeding Trough | feeding_trough | 60         | 2                | 1              | 1           | 0          | 99         |                    |                   | provides_food,infrastructure   |                              |                               |
| water_trough   | Water Trough   | water_trough   | 50         | 1                | 1              | 1           | 0          | 99         |                    |                   | provides_water,infrastructure  |                              |                               |
| donation_box   | Donation Box   | donation_box   | 80         | 0                | 1              | 1           | 0          | 99         |                    |                   | donation_box,infrastructure    |                              |                               |
