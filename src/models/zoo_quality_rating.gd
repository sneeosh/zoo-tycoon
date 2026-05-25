extends IQualityRating
class_name ZooQualityRating
# Zoo's IQualityRating.
#
# v0.4.0: rating is the mean of compute_region_appeal scores across all
# regions that have at least one placement. Empty pens / no placements →
# 0 stars. A region's appeal contribution is the max of its
# appeal_profile axis values (the strongest signal — a region with one
# stand-out exhibit shouldn't get penalised for not also having every
# other axis). EffectResolver.compute_quality_modifier() still adds on
# top for any active quality Effects.


func compute_rating() -> float:
	var scored: float = 0.0
	var count: int = 0
	for region: Region in RegionRegistry.all_regions():
		if region.placements.is_empty():
			continue
		var appeal: Dictionary = EffectResolver.compute_region_appeal(region)
		if appeal.is_empty():
			continue
		var max_axis: float = 0.0
		for v in appeal.values():
			if v > max_axis:
				max_axis = v
		scored += max_axis
		count += 1
	if count == 0:
		return 0.0
	var rating := (scored / float(count)) * 5.0 + EffectResolver.compute_quality_modifier()
	return clampf(rating, 0.0, 5.0)
