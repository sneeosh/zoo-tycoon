extends IQualityRating
class_name ZooQualityRating
# Zoo's IQualityRating — Prompt 10.
#
# Star rating (0–5) derived from placed exhibits' thrill appeal, scaled
# and bumped by any active EffectResolver quality modifiers. Real games
# would blend in aggregate visitor satisfaction, condition modifiers, etc.


func compute_rating() -> float:
	var thrill_sum: float = 0.0
	var exhibit_count: int = 0
	for inst: EntityInstance in EntityRegistry.instances.values():
		var def := inst.get_def()
		if def == null:
			continue
		if not def.appeal_profile.has(&"thrill"):
			continue
		thrill_sum += def.appeal_profile[&"thrill"]
		exhibit_count += 1
	if exhibit_count == 0:
		return 0.0
	var avg_thrill: float = thrill_sum / exhibit_count
	var rating := avg_thrill * 5.0 + EffectResolver.compute_quality_modifier()
	return clampf(rating, 0.0, 5.0)
