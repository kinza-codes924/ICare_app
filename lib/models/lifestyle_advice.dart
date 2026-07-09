// Lifestyle Advice Model
// New feature as per client requirements - May 4, 2026

class LifestyleAdvice {
  final String? id;
  final String consultationId;
  final String prescriptionId;
  final DietAdvice? diet;
  final ExerciseAdvice? exercise;
  final SleepAdvice? sleep;
  final StressManagement? stress;
  final SmokingCessation? smoking;
  final AlcoholModeration? alcohol;
  final WeightManagement? weight;
  final List<String> otherAdvice;
  final DateTime createdAt;
  final DateTime? updatedAt;

  LifestyleAdvice({
    this.id,
    required this.consultationId,
    required this.prescriptionId,
    this.diet,
    this.exercise,
    this.sleep,
    this.stress,
    this.smoking,
    this.alcohol,
    this.weight,
    required this.otherAdvice,
    required this.createdAt,
    this.updatedAt,
  });

  factory LifestyleAdvice.fromJson(Map<String, dynamic> json) {
    return LifestyleAdvice(
      id: json['_id'],
      consultationId: json['consultationId'] ?? '',
      prescriptionId: json['prescriptionId'] ?? '',
      diet: json['diet'] != null ? DietAdvice.fromJson(json['diet']) : null,
      exercise: json['exercise'] != null ? ExerciseAdvice.fromJson(json['exercise']) : null,
      sleep: json['sleep'] != null ? SleepAdvice.fromJson(json['sleep']) : null,
      stress: json['stress'] != null ? StressManagement.fromJson(json['stress']) : null,
      smoking: json['smoking'] != null ? SmokingCessation.fromJson(json['smoking']) : null,
      alcohol: json['alcohol'] != null ? AlcoholModeration.fromJson(json['alcohol']) : null,
      weight: json['weight'] != null ? WeightManagement.fromJson(json['weight']) : null,
      otherAdvice: List<String>.from(json['otherAdvice'] ?? []),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) '_id': id,
      'consultationId': consultationId,
      'prescriptionId': prescriptionId,
      'diet': diet?.toJson(),
      'exercise': exercise?.toJson(),
      'sleep': sleep?.toJson(),
      'stress': stress?.toJson(),
      'smoking': smoking?.toJson(),
      'alcohol': alcohol?.toJson(),
      'weight': weight?.toJson(),
      'otherAdvice': otherAdvice,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  bool get hasAnyAdvice {
    return diet != null ||
        exercise != null ||
        sleep != null ||
        stress != null ||
        smoking != null ||
        alcohol != null ||
        weight != null ||
        otherAdvice.isNotEmpty;
  }
}

// Diet Advice
class DietAdvice {
  final String recommendations;
  final List<String> foodsToAvoid;
  final List<String> foodsToInclude;
  final String mealTiming;
  final String hydration;

  DietAdvice({
    required this.recommendations,
    required this.foodsToAvoid,
    required this.foodsToInclude,
    required this.mealTiming,
    required this.hydration,
  });

  factory DietAdvice.fromJson(Map<String, dynamic> json) {
    return DietAdvice(
      recommendations: json['recommendations'] ?? '',
      foodsToAvoid: List<String>.from(json['foodsToAvoid'] ?? []),
      foodsToInclude: List<String>.from(json['foodsToInclude'] ?? []),
      mealTiming: json['mealTiming'] ?? '',
      hydration: json['hydration'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'recommendations': recommendations,
      'foodsToAvoid': foodsToAvoid,
      'foodsToInclude': foodsToInclude,
      'mealTiming': mealTiming,
      'hydration': hydration,
    };
  }
}

// Exercise Advice
class ExerciseAdvice {
  final String type;
  final String frequency;
  final String duration;
  final String intensity;
  final List<String> precautions;

  ExerciseAdvice({
    required this.type,
    required this.frequency,
    required this.duration,
    required this.intensity,
    required this.precautions,
  });

  factory ExerciseAdvice.fromJson(Map<String, dynamic> json) {
    return ExerciseAdvice(
      type: json['type'] ?? '',
      frequency: json['frequency'] ?? '',
      duration: json['duration'] ?? '',
      intensity: json['intensity'] ?? '',
      precautions: List<String>.from(json['precautions'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'frequency': frequency,
      'duration': duration,
      'intensity': intensity,
      'precautions': precautions,
    };
  }
}

// Sleep Advice
class SleepAdvice {
  final String recommendedHours;
  final String sleepSchedule;
  final List<String> sleepHygieneTips;

  SleepAdvice({
    required this.recommendedHours,
    required this.sleepSchedule,
    required this.sleepHygieneTips,
  });

  factory SleepAdvice.fromJson(Map<String, dynamic> json) {
    return SleepAdvice(
      recommendedHours: json['recommendedHours'] ?? '',
      sleepSchedule: json['sleepSchedule'] ?? '',
      sleepHygieneTips: List<String>.from(json['sleepHygieneTips'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'recommendedHours': recommendedHours,
      'sleepSchedule': sleepSchedule,
      'sleepHygieneTips': sleepHygieneTips,
    };
  }
}

// Stress Management
class StressManagement {
  final List<String> techniques;
  final String recommendations;

  StressManagement({
    required this.techniques,
    required this.recommendations,
  });

  factory StressManagement.fromJson(Map<String, dynamic> json) {
    return StressManagement(
      techniques: List<String>.from(json['techniques'] ?? []),
      recommendations: json['recommendations'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'techniques': techniques,
      'recommendations': recommendations,
    };
  }
}

// Smoking Cessation
class SmokingCessation {
  final String plan;
  final List<String> resources;
  final String timeline;

  SmokingCessation({
    required this.plan,
    required this.resources,
    required this.timeline,
  });

  factory SmokingCessation.fromJson(Map<String, dynamic> json) {
    return SmokingCessation(
      plan: json['plan'] ?? '',
      resources: List<String>.from(json['resources'] ?? []),
      timeline: json['timeline'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'plan': plan,
      'resources': resources,
      'timeline': timeline,
    };
  }
}

// Alcohol Moderation
class AlcoholModeration {
  final String recommendations;
  final String limits;

  AlcoholModeration({
    required this.recommendations,
    required this.limits,
  });

  factory AlcoholModeration.fromJson(Map<String, dynamic> json) {
    return AlcoholModeration(
      recommendations: json['recommendations'] ?? '',
      limits: json['limits'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'recommendations': recommendations,
      'limits': limits,
    };
  }
}

// Weight Management
class WeightManagement {
  final double? targetWeight;
  final String plan;
  final String timeline;

  WeightManagement({
    this.targetWeight,
    required this.plan,
    required this.timeline,
  });

  factory WeightManagement.fromJson(Map<String, dynamic> json) {
    return WeightManagement(
      targetWeight: json['targetWeight']?.toDouble(),
      plan: json['plan'] ?? '',
      timeline: json['timeline'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'targetWeight': targetWeight,
      'plan': plan,
      'timeline': timeline,
    };
  }
}

// Lifestyle Advice Templates for quick selection
class LifestyleAdviceTemplates {
  static final List<Map<String, dynamic>> dietTemplates = [
    {
      'name': 'Diabetic Diet',
      'recommendations': 'Follow a balanced diet with controlled carbohydrate intake',
      'foodsToAvoid': ['Sugary drinks', 'White bread', 'Processed foods', 'Fried foods'],
      'foodsToInclude': ['Whole grains', 'Vegetables', 'Lean proteins', 'Healthy fats'],
      'mealTiming': 'Eat small frequent meals every 3-4 hours',
      'hydration': 'Drink 8-10 glasses of water daily',
    },
    {
      'name': 'Hypertension Diet',
      'recommendations': 'Follow DASH diet with low sodium intake',
      'foodsToAvoid': ['Salty foods', 'Processed meats', 'Canned foods', 'Fast food'],
      'foodsToInclude': ['Fresh fruits', 'Vegetables', 'Low-fat dairy', 'Whole grains'],
      'mealTiming': 'Regular meal times, avoid late night eating',
      'hydration': 'Adequate water intake, limit caffeine',
    },
    {
      'name': 'Weight Loss Diet',
      'recommendations': 'Calorie-controlled balanced diet',
      'foodsToAvoid': ['Sugary snacks', 'Fried foods', 'Processed foods', 'Sugary beverages'],
      'foodsToInclude': ['Vegetables', 'Fruits', 'Lean proteins', 'Whole grains'],
      'mealTiming': 'Eat breakfast, avoid late night snacking',
      'hydration': 'Drink water before meals, 8-10 glasses daily',
    },
  ];

  static final List<Map<String, dynamic>> exerciseTemplates = [
    {
      'name': 'General Fitness',
      'type': 'Moderate aerobic exercise and strength training',
      'frequency': '5 days per week',
      'duration': '30-45 minutes per session',
      'intensity': 'Moderate',
      'precautions': ['Warm up before exercise', 'Cool down after', 'Stay hydrated'],
    },
    {
      'name': 'Cardiac Rehabilitation',
      'type': 'Low to moderate intensity aerobic exercise',
      'frequency': '3-5 days per week',
      'duration': '20-30 minutes per session',
      'intensity': 'Low to moderate',
      'precautions': ['Start slowly', 'Monitor heart rate', 'Stop if chest pain occurs'],
    },
    {
      'name': 'Diabetes Management',
      'type': 'Aerobic exercise and resistance training',
      'frequency': '5 days per week',
      'duration': '30 minutes per session',
      'intensity': 'Moderate',
      'precautions': ['Check blood sugar before and after', 'Carry glucose tablets', 'Wear proper footwear'],
    },
  ];

  static final List<Map<String, dynamic>> sleepTemplates = [
    {
      'name': 'General Sleep Hygiene',
      'recommendedHours': '7-9 hours',
      'sleepSchedule': 'Consistent bedtime and wake time',
      'sleepHygieneTips': [
        'Avoid screens 1 hour before bed',
        'Keep bedroom cool and dark',
        'Avoid caffeine after 2 PM',
        'Establish relaxing bedtime routine',
      ],
    },
    {
      'name': 'Insomnia Management',
      'recommendedHours': '7-8 hours',
      'sleepSchedule': 'Fixed sleep and wake times',
      'sleepHygieneTips': [
        'Use bed only for sleep',
        'Get up if unable to sleep after 20 minutes',
        'Avoid daytime napping',
        'Practice relaxation techniques',
      ],
    },
  ];

  static final List<Map<String, dynamic>> stressTemplates = [
    {
      'name': 'General Stress Management',
      'techniques': [
        'Deep breathing exercises',
        'Meditation',
        'Progressive muscle relaxation',
        'Mindfulness',
      ],
      'recommendations': 'Practice stress management techniques daily for 10-15 minutes',
    },
    {
      'name': 'Work-Related Stress',
      'techniques': [
        'Time management',
        'Setting boundaries',
        'Regular breaks',
        'Physical activity',
      ],
      'recommendations': 'Take regular breaks, maintain work-life balance, seek support when needed',
    },
  ];
}
