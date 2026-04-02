class NutritionPer100g {
  final double kcal;
  final double proteinG;
  final double fatG;
  final double carbsG;

  const NutritionPer100g({
    required this.kcal,
    required this.proteinG,
    required this.fatG,
    required this.carbsG,
  });

  factory NutritionPer100g.fromJson(Map<String, dynamic> json) {
    return NutritionPer100g(
      kcal: (json['kcal'] as num).toDouble(),
      proteinG: (json['protein_g'] as num).toDouble(),
      fatG: (json['fat_g'] as num).toDouble(),
      carbsG: (json['carbs_g'] as num).toDouble(),
    );
  }
}

class EstimatedTotals {
  final double kcal;
  final double proteinG;
  final double fatG;
  final double carbsG;

  const EstimatedTotals({
    required this.kcal,
    required this.proteinG,
    required this.fatG,
    required this.carbsG,
  });

  factory EstimatedTotals.fromJson(Map<String, dynamic> json) {
    return EstimatedTotals(
      kcal: (json['kcal'] as num).toDouble(),
      proteinG: (json['protein_g'] as num).toDouble(),
      fatG: (json['fat_g'] as num).toDouble(),
      carbsG: (json['carbs_g'] as num).toDouble(),
    );
  }
}

class Item {
  final String name;
  final String? category;
  final String? foodType;
  final double confidence;
  final NutritionPer100g nutritionPer100g;
  final List<String> warnings;

  const Item({
    required this.name,
    required this.category,
    required this.foodType,
    required this.confidence,
    required this.nutritionPer100g,
    required this.warnings,
  });

  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      name: json['name'] as String,
      category: json['category'] as String?,
      foodType: json['food_type'] as String?,
      confidence: (json['confidence'] as num).toDouble(),
      nutritionPer100g: NutritionPer100g.fromJson(
        json['nutrition_per_100g'] as Map<String, dynamic>,
      ),
      warnings: ((json['warnings'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
    );
  }
}

class UiFlags {
  final bool requiresUserConfirmation;
  final String highlightLevel;

  const UiFlags({
    required this.requiresUserConfirmation,
    required this.highlightLevel,
  });

  factory UiFlags.fromJson(Map<String, dynamic> json) {
    return UiFlags(
      requiresUserConfirmation: json['requires_user_confirmation'] as bool,
      highlightLevel: json['highlight_level'] as String,
    );
  }
}

class Meta {
  final bool needsConfirmation;
  final double? estimatedPortionG;
  final String? portionBasis;
  final String? confirmationSource;
  final bool totalsAreEstimate;
  final EstimatedTotals? estimatedTotals;

  const Meta({
    required this.needsConfirmation,
    required this.estimatedPortionG,
    required this.portionBasis,
    required this.confirmationSource,
    required this.totalsAreEstimate,
    required this.estimatedTotals,
  });

  factory Meta.fromJson(Map<String, dynamic> json) {
    final totalsJson = json['estimated_totals'];
    return Meta(
      needsConfirmation: json['needs_confirmation'] as bool,
      estimatedPortionG: (json['estimated_portion_g'] as num?)?.toDouble(),
      portionBasis: json['portion_basis'] as String?,
      confirmationSource: json['confirmation_source'] as String?,
      totalsAreEstimate: json['totals_are_estimate'] as bool,
      estimatedTotals: totalsJson is Map<String, dynamic>
          ? EstimatedTotals.fromJson(totalsJson)
          : null,
    );
  }
}

class PhotoFoodResponse {
  final String requestId;
  final Item item;
  final UiFlags uiFlags;
  final Meta meta;

  const PhotoFoodResponse({
    required this.requestId,
    required this.item,
    required this.uiFlags,
    required this.meta,
  });

  factory PhotoFoodResponse.fromJson(Map<String, dynamic> json) {
    return PhotoFoodResponse(
      requestId: json['request_id'] as String,
      item: Item.fromJson(json['item'] as Map<String, dynamic>),
      uiFlags: UiFlags.fromJson(json['ui_flags'] as Map<String, dynamic>),
      meta: Meta.fromJson(json['meta'] as Map<String, dynamic>),
    );
  }
}
