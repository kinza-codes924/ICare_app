// Patient History Form Model - Complete Implementation
// Based on client requirements from May 4, 2026 meeting

class PatientHistoryForm {
  final String? id;
  final String patientId;
  final String consultationId;
  final String doctorId;
  
  // 1. Chief Complaint(s)
  final List<ChiefComplaint> chiefComplaints;
  
  // 2. History of Present Illness
  final HistoryOfPresentIllness? hpi;
  
  // 3. Past Medical History
  final PastMedicalHistory? pastMedicalHistory;
  
  // 4. Past Surgical History
  final List<SurgicalHistory> surgicalHistory;
  
  // 5. Drug History
  final DrugHistory? drugHistory;
  
  // 6. Family History
  final FamilyHistory? familyHistory;
  
  // 7. Personal and Social History
  final PersonalSocialHistory? personalSocialHistory;
  
  // 8. Gynecological/Obstetric History
  final GynecologicalHistory? gynecologicalHistory;
  
  // 9. Review of Systems
  final ReviewOfSystems? reviewOfSystems;
  
  // 10. Virtual General Physical Examination
  final VirtualPhysicalExamination? virtualExamination;
  
  final DateTime createdAt;
  final DateTime? updatedAt;

  PatientHistoryForm({
    this.id,
    required this.patientId,
    required this.consultationId,
    required this.doctorId,
    required this.chiefComplaints,
    this.hpi,
    this.pastMedicalHistory,
    required this.surgicalHistory,
    this.drugHistory,
    this.familyHistory,
    this.personalSocialHistory,
    this.gynecologicalHistory,
    this.reviewOfSystems,
    this.virtualExamination,
    required this.createdAt,
    this.updatedAt,
  });

  static String _extractId(dynamic val) {
    if (val == null) return '';
    if (val is String) return val;
    if (val is Map) return (val['_id'] ?? val['id'] ?? '').toString();
    return val.toString();
  }

  factory PatientHistoryForm.fromJson(Map<String, dynamic> json) {
    return PatientHistoryForm(
      id: _extractId(json['_id']),
      patientId: _extractId(json['patientId']),
      consultationId: _extractId(json['consultationId']),
      doctorId: _extractId(json['doctorId']),
      chiefComplaints: (json['chiefComplaints'] as List?)
          ?.map((e) => ChiefComplaint.fromJson(e))
          .toList() ?? [],
      hpi: json['hpi'] != null ? HistoryOfPresentIllness.fromJson(json['hpi']) : null,
      pastMedicalHistory: json['pastMedicalHistory'] != null 
          ? PastMedicalHistory.fromJson(json['pastMedicalHistory']) : null,
      surgicalHistory: (json['surgicalHistory'] as List?)
          ?.map((e) => SurgicalHistory.fromJson(e))
          .toList() ?? [],
      drugHistory: json['drugHistory'] != null 
          ? DrugHistory.fromJson(json['drugHistory']) : null,
      familyHistory: json['familyHistory'] != null 
          ? FamilyHistory.fromJson(json['familyHistory']) : null,
      personalSocialHistory: json['personalSocialHistory'] != null 
          ? PersonalSocialHistory.fromJson(json['personalSocialHistory']) : null,
      gynecologicalHistory: json['gynecologicalHistory'] != null 
          ? GynecologicalHistory.fromJson(json['gynecologicalHistory']) : null,
      reviewOfSystems: json['reviewOfSystems'] != null 
          ? ReviewOfSystems.fromJson(json['reviewOfSystems']) : null,
      virtualExamination: json['virtualExamination'] != null 
          ? VirtualPhysicalExamination.fromJson(json['virtualExamination']) : null,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) '_id': id,
      'patientId': patientId,
      'consultationId': consultationId,
      'doctorId': doctorId,
      'chiefComplaints': chiefComplaints.map((e) => e.toJson()).toList(),
      'hpi': hpi?.toJson(),
      'pastMedicalHistory': pastMedicalHistory?.toJson(),
      'surgicalHistory': surgicalHistory.map((e) => e.toJson()).toList(),
      'drugHistory': drugHistory?.toJson(),
      'familyHistory': familyHistory?.toJson(),
      'personalSocialHistory': personalSocialHistory?.toJson(),
      'gynecologicalHistory': gynecologicalHistory?.toJson(),
      'reviewOfSystems': reviewOfSystems?.toJson(),
      'virtualExamination': virtualExamination?.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}

// 1. Chief Complaint
class ChiefComplaint {
  final String complaint;
  final String duration;

  ChiefComplaint({
    required this.complaint,
    required this.duration,
  });

  factory ChiefComplaint.fromJson(Map<String, dynamic> json) {
    return ChiefComplaint(
      complaint: json['complaint'] ?? '',
      duration: json['duration'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'complaint': complaint,
      'duration': duration,
    };
  }
}

// 2. History of Present Illness
class HistoryOfPresentIllness {
  final String onset;
  final String duration;
  final String progression;
  final String location;
  final String radiation;
  final String character;
  final String severity;
  final String aggravatingFactors;
  final String relievingFactors;
  final String associatedSymptoms;
  final String previousEpisodes;
  final String treatmentTaken;
  final String additionalNotes;

  HistoryOfPresentIllness({
    required this.onset,
    required this.duration,
    required this.progression,
    required this.location,
    required this.radiation,
    required this.character,
    required this.severity,
    required this.aggravatingFactors,
    required this.relievingFactors,
    required this.associatedSymptoms,
    required this.previousEpisodes,
    required this.treatmentTaken,
    required this.additionalNotes,
  });

  factory HistoryOfPresentIllness.fromJson(Map<String, dynamic> json) {
    return HistoryOfPresentIllness(
      onset: json['onset'] ?? '',
      duration: json['duration'] ?? '',
      progression: json['progression'] ?? '',
      location: json['location'] ?? '',
      radiation: json['radiation'] ?? '',
      character: json['character'] ?? '',
      severity: json['severity'] ?? '',
      aggravatingFactors: json['aggravatingFactors'] ?? '',
      relievingFactors: json['relievingFactors'] ?? '',
      associatedSymptoms: json['associatedSymptoms'] ?? '',
      previousEpisodes: json['previousEpisodes'] ?? '',
      treatmentTaken: json['treatmentTaken'] ?? '',
      additionalNotes: json['additionalNotes'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'onset': onset,
      'duration': duration,
      'progression': progression,
      'location': location,
      'radiation': radiation,
      'character': character,
      'severity': severity,
      'aggravatingFactors': aggravatingFactors,
      'relievingFactors': relievingFactors,
      'associatedSymptoms': associatedSymptoms,
      'previousEpisodes': previousEpisodes,
      'treatmentTaken': treatmentTaken,
      'additionalNotes': additionalNotes,
    };
  }
}

// 3. Past Medical History
class PastMedicalHistory {
  final bool hypertension;
  final String? hypertensionDetails;
  final bool diabetesMellitus;
  final String? diabetesDetails;
  final bool ischemicHeartDisease;
  final String? ihdDetails;
  final bool asthma;
  final String? asthmaDetails;
  final bool tuberculosis;
  final String? tbDetails;
  final bool hepatitis;
  final String? hepatitisDetails;
  final bool thyroidDisease;
  final String? thyroidDetails;
  final bool renalDisease;
  final String? renalDetails;
  final bool epilepsy;
  final String? epilepsyDetails;
  final bool psychiatricIllness;
  final String? psychiatricDetails;
  final List<OtherChronicIllness> otherIllnesses;

  PastMedicalHistory({
    required this.hypertension,
    this.hypertensionDetails,
    required this.diabetesMellitus,
    this.diabetesDetails,
    required this.ischemicHeartDisease,
    this.ihdDetails,
    required this.asthma,
    this.asthmaDetails,
    required this.tuberculosis,
    this.tbDetails,
    required this.hepatitis,
    this.hepatitisDetails,
    required this.thyroidDisease,
    this.thyroidDetails,
    required this.renalDisease,
    this.renalDetails,
    required this.epilepsy,
    this.epilepsyDetails,
    required this.psychiatricIllness,
    this.psychiatricDetails,
    required this.otherIllnesses,
  });

  factory PastMedicalHistory.fromJson(Map<String, dynamic> json) {
    return PastMedicalHistory(
      hypertension: json['hypertension'] ?? false,
      hypertensionDetails: json['hypertensionDetails'],
      diabetesMellitus: json['diabetesMellitus'] ?? false,
      diabetesDetails: json['diabetesDetails'],
      ischemicHeartDisease: json['ischemicHeartDisease'] ?? false,
      ihdDetails: json['ihdDetails'],
      asthma: json['asthma'] ?? false,
      asthmaDetails: json['asthmaDetails'],
      tuberculosis: json['tuberculosis'] ?? false,
      tbDetails: json['tbDetails'],
      hepatitis: json['hepatitis'] ?? false,
      hepatitisDetails: json['hepatitisDetails'],
      thyroidDisease: json['thyroidDisease'] ?? false,
      thyroidDetails: json['thyroidDetails'],
      renalDisease: json['renalDisease'] ?? false,
      renalDetails: json['renalDetails'],
      epilepsy: json['epilepsy'] ?? false,
      epilepsyDetails: json['epilepsyDetails'],
      psychiatricIllness: json['psychiatricIllness'] ?? false,
      psychiatricDetails: json['psychiatricDetails'],
      otherIllnesses: (json['otherIllnesses'] as List?)
          ?.map((e) => OtherChronicIllness.fromJson(e))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'hypertension': hypertension,
      'hypertensionDetails': hypertensionDetails,
      'diabetesMellitus': diabetesMellitus,
      'diabetesDetails': diabetesDetails,
      'ischemicHeartDisease': ischemicHeartDisease,
      'ihdDetails': ihdDetails,
      'asthma': asthma,
      'asthmaDetails': asthmaDetails,
      'tuberculosis': tuberculosis,
      'tbDetails': tbDetails,
      'hepatitis': hepatitis,
      'hepatitisDetails': hepatitisDetails,
      'thyroidDisease': thyroidDisease,
      'thyroidDetails': thyroidDetails,
      'renalDisease': renalDisease,
      'renalDetails': renalDetails,
      'epilepsy': epilepsy,
      'epilepsyDetails': epilepsyDetails,
      'psychiatricIllness': psychiatricIllness,
      'psychiatricDetails': psychiatricDetails,
      'otherIllnesses': otherIllnesses.map((e) => e.toJson()).toList(),
    };
  }
}

class OtherChronicIllness {
  final String illness;
  final String details;

  OtherChronicIllness({
    required this.illness,
    required this.details,
  });

  factory OtherChronicIllness.fromJson(Map<String, dynamic> json) {
    return OtherChronicIllness(
      illness: json['illness'] ?? '',
      details: json['details'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'illness': illness,
      'details': details,
    };
  }
}

// 4. Surgical History
class SurgicalHistory {
  final String surgeryProcedure;
  final int year;
  final String? hospitalRemarks;

  SurgicalHistory({
    required this.surgeryProcedure,
    required this.year,
    this.hospitalRemarks,
  });

  factory SurgicalHistory.fromJson(Map<String, dynamic> json) {
    return SurgicalHistory(
      surgeryProcedure: json['surgeryProcedure'] ?? '',
      year: json['year'] ?? 0,
      hospitalRemarks: json['hospitalRemarks'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'surgeryProcedure': surgeryProcedure,
      'year': year,
      'hospitalRemarks': hospitalRemarks,
    };
  }
}

// 5. Drug History
class DrugHistory {
  final List<CurrentMedication> currentMedications;
  final List<Allergy> allergies;

  DrugHistory({
    required this.currentMedications,
    required this.allergies,
  });

  factory DrugHistory.fromJson(Map<String, dynamic> json) {
    return DrugHistory(
      currentMedications: (json['currentMedications'] as List?)
          ?.map((e) => CurrentMedication.fromJson(e))
          .toList() ?? [],
      allergies: (json['allergies'] as List?)
          ?.map((e) => Allergy.fromJson(e))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'currentMedications': currentMedications.map((e) => e.toJson()).toList(),
      'allergies': allergies.map((e) => e.toJson()).toList(),
    };
  }
}

class CurrentMedication {
  final String medication;
  final String dose;
  final String frequency;
  final String duration;

  CurrentMedication({
    required this.medication,
    required this.dose,
    required this.frequency,
    required this.duration,
  });

  factory CurrentMedication.fromJson(Map<String, dynamic> json) {
    return CurrentMedication(
      medication: json['medication'] ?? '',
      dose: json['dose'] ?? '',
      frequency: json['frequency'] ?? '',
      duration: json['duration'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'medication': medication,
      'dose': dose,
      'frequency': frequency,
      'duration': duration,
    };
  }
}

class Allergy {
  final AllergyType type;
  final String allergen;
  final String reaction;

  Allergy({
    required this.type,
    required this.allergen,
    required this.reaction,
  });

  factory Allergy.fromJson(Map<String, dynamic> json) {
    return Allergy(
      type: AllergyType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
        orElse: () => AllergyType.other,
      ),
      allergen: json['allergen'] ?? '',
      reaction: json['reaction'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.toString().split('.').last,
      'allergen': allergen,
      'reaction': reaction,
    };
  }
}

enum AllergyType {
  drug,
  food,
  other,
}

// 6. Family History
class FamilyHistory {
  final FamilyMemberHistory? father;
  final FamilyMemberHistory? mother;
  final List<FamilyMemberHistory> siblings;
  final List<FamilyMemberHistory> children;
  final String? otherRelevantHistory;

  FamilyHistory({
    this.father,
    this.mother,
    required this.siblings,
    required this.children,
    this.otherRelevantHistory,
  });

  factory FamilyHistory.fromJson(Map<String, dynamic> json) {
    return FamilyHistory(
      father: json['father'] != null 
          ? FamilyMemberHistory.fromJson(json['father']) : null,
      mother: json['mother'] != null 
          ? FamilyMemberHistory.fromJson(json['mother']) : null,
      siblings: (json['siblings'] as List?)
          ?.map((e) => FamilyMemberHistory.fromJson(e))
          .toList() ?? [],
      children: (json['children'] as List?)
          ?.map((e) => FamilyMemberHistory.fromJson(e))
          .toList() ?? [],
      otherRelevantHistory: json['otherRelevantHistory'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'father': father?.toJson(),
      'mother': mother?.toJson(),
      'siblings': siblings.map((e) => e.toJson()).toList(),
      'children': children.map((e) => e.toJson()).toList(),
      'otherRelevantHistory': otherRelevantHistory,
    };
  }
}

class FamilyMemberHistory {
  final String? diseaseCondition;
  final int? ageAtDiagnosis;

  FamilyMemberHistory({
    this.diseaseCondition,
    this.ageAtDiagnosis,
  });

  factory FamilyMemberHistory.fromJson(Map<String, dynamic> json) {
    return FamilyMemberHistory(
      diseaseCondition: json['diseaseCondition'],
      ageAtDiagnosis: json['ageAtDiagnosis'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'diseaseCondition': diseaseCondition,
      'ageAtDiagnosis': ageAtDiagnosis,
    };
  }
}

// 7. Personal and Social History
class PersonalSocialHistory {
  final String diet;
  final String appetite;
  final String sleep;
  final String bowelHabits;
  final String bladderHabits;
  final SmokingStatus smoking;
  final AlcoholStatus alcoholUse;
  final bool substanceAbuse;
  final String? substanceDetails;
  final String exercise;
  final String? sexualHistory;
  final String? occupationalExposure;
  final String? travelHistory;
  final String? vaccinationHistory;

  PersonalSocialHistory({
    required this.diet,
    required this.appetite,
    required this.sleep,
    required this.bowelHabits,
    required this.bladderHabits,
    required this.smoking,
    required this.alcoholUse,
    required this.substanceAbuse,
    this.substanceDetails,
    required this.exercise,
    this.sexualHistory,
    this.occupationalExposure,
    this.travelHistory,
    this.vaccinationHistory,
  });

  factory PersonalSocialHistory.fromJson(Map<String, dynamic> json) {
    return PersonalSocialHistory(
      diet: json['diet'] ?? '',
      appetite: json['appetite'] ?? '',
      sleep: json['sleep'] ?? '',
      bowelHabits: json['bowelHabits'] ?? '',
      bladderHabits: json['bladderHabits'] ?? '',
      smoking: SmokingStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['smoking'],
        orElse: () => SmokingStatus.never,
      ),
      alcoholUse: AlcoholStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['alcoholUse'],
        orElse: () => AlcoholStatus.never,
      ),
      substanceAbuse: json['substanceAbuse'] ?? false,
      substanceDetails: json['substanceDetails'],
      exercise: json['exercise'] ?? '',
      sexualHistory: json['sexualHistory'],
      occupationalExposure: json['occupationalExposure'],
      travelHistory: json['travelHistory'],
      vaccinationHistory: json['vaccinationHistory'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'diet': diet,
      'appetite': appetite,
      'sleep': sleep,
      'bowelHabits': bowelHabits,
      'bladderHabits': bladderHabits,
      'smoking': smoking.toString().split('.').last,
      'alcoholUse': alcoholUse.toString().split('.').last,
      'substanceAbuse': substanceAbuse,
      'substanceDetails': substanceDetails,
      'exercise': exercise,
      'sexualHistory': sexualHistory,
      'occupationalExposure': occupationalExposure,
      'travelHistory': travelHistory,
      'vaccinationHistory': vaccinationHistory,
    };
  }
}

enum SmokingStatus {
  never,
  former,
  current,
}

enum AlcoholStatus {
  never,
  occasional,
  regular,
}

// 8. Gynecological History
class GynecologicalHistory {
  final int? menarche;
  final DateTime? lastMenstrualPeriod;
  final String menstrualCycle;
  final int gravida;
  final int para;
  final int abortions;
  final int livingChildren;
  final String? contraceptiveUse;
  final bool menopause;
  final int? menopauseAge;

  GynecologicalHistory({
    this.menarche,
    this.lastMenstrualPeriod,
    required this.menstrualCycle,
    required this.gravida,
    required this.para,
    required this.abortions,
    required this.livingChildren,
    this.contraceptiveUse,
    required this.menopause,
    this.menopauseAge,
  });

  factory GynecologicalHistory.fromJson(Map<String, dynamic> json) {
    return GynecologicalHistory(
      menarche: json['menarche'],
      lastMenstrualPeriod: json['lastMenstrualPeriod'] != null 
          ? DateTime.parse(json['lastMenstrualPeriod']) : null,
      menstrualCycle: json['menstrualCycle'] ?? '',
      gravida: json['gravida'] ?? 0,
      para: json['para'] ?? 0,
      abortions: json['abortions'] ?? 0,
      livingChildren: json['livingChildren'] ?? 0,
      contraceptiveUse: json['contraceptiveUse'],
      menopause: json['menopause'] ?? false,
      menopauseAge: json['menopauseAge'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'menarche': menarche,
      'lastMenstrualPeriod': lastMenstrualPeriod?.toIso8601String(),
      'menstrualCycle': menstrualCycle,
      'gravida': gravida,
      'para': para,
      'abortions': abortions,
      'livingChildren': livingChildren,
      'contraceptiveUse': contraceptiveUse,
      'menopause': menopause,
      'menopauseAge': menopauseAge,
    };
  }
}

// 9. Review of Systems
class ReviewOfSystems {
  final String general;
  final String cardiovascular;
  final String respiratory;
  final String gastrointestinal;
  final String genitourinary;
  final String neurological;
  final String musculoskeletal;
  final String endocrine;
  final String skin;
  final String psychiatric;

  ReviewOfSystems({
    required this.general,
    required this.cardiovascular,
    required this.respiratory,
    required this.gastrointestinal,
    required this.genitourinary,
    required this.neurological,
    required this.musculoskeletal,
    required this.endocrine,
    required this.skin,
    required this.psychiatric,
  });

  factory ReviewOfSystems.fromJson(Map<String, dynamic> json) {
    return ReviewOfSystems(
      general: json['general'] ?? '',
      cardiovascular: json['cardiovascular'] ?? '',
      respiratory: json['respiratory'] ?? '',
      gastrointestinal: json['gastrointestinal'] ?? '',
      genitourinary: json['genitourinary'] ?? '',
      neurological: json['neurological'] ?? '',
      musculoskeletal: json['musculoskeletal'] ?? '',
      endocrine: json['endocrine'] ?? '',
      skin: json['skin'] ?? '',
      psychiatric: json['psychiatric'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'general': general,
      'cardiovascular': cardiovascular,
      'respiratory': respiratory,
      'gastrointestinal': gastrointestinal,
      'genitourinary': genitourinary,
      'neurological': neurological,
      'musculoskeletal': musculoskeletal,
      'endocrine': endocrine,
      'skin': skin,
      'psychiatric': psychiatric,
    };
  }
}

// 10. Virtual Physical Examination
class VirtualPhysicalExamination {
  final VitalSigns vitalSigns;
  final GeneralExaminationFindings generalFindings;
  final String notes;

  VirtualPhysicalExamination({
    required this.vitalSigns,
    required this.generalFindings,
    required this.notes,
  });

  factory VirtualPhysicalExamination.fromJson(Map<String, dynamic> json) {
    return VirtualPhysicalExamination(
      vitalSigns: VitalSigns.fromJson(json['vitalSigns'] ?? {}),
      generalFindings: GeneralExaminationFindings.fromJson(json['generalFindings'] ?? {}),
      notes: json['notes'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'vitalSigns': vitalSigns.toJson(),
      'generalFindings': generalFindings.toJson(),
      'notes': notes,
    };
  }
}

class VitalSigns {
  final String? bloodPressure;
  final String? pulseRate;
  final String? respiratoryRate;
  final String? temperature;
  final String? oxygenSaturation;
  final String? weight;
  final String? height;
  final String? bmi;

  VitalSigns({
    this.bloodPressure,
    this.pulseRate,
    this.respiratoryRate,
    this.temperature,
    this.oxygenSaturation,
    this.weight,
    this.height,
    this.bmi,
  });

  factory VitalSigns.fromJson(Map<String, dynamic> json) {
    return VitalSigns(
      bloodPressure: json['bloodPressure'],
      pulseRate: json['pulseRate'],
      respiratoryRate: json['respiratoryRate'],
      temperature: json['temperature'],
      oxygenSaturation: json['oxygenSaturation'],
      weight: json['weight'],
      height: json['height'],
      bmi: json['bmi'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bloodPressure': bloodPressure,
      'pulseRate': pulseRate,
      'respiratoryRate': respiratoryRate,
      'temperature': temperature,
      'oxygenSaturation': oxygenSaturation,
      'weight': weight,
      'height': height,
      'bmi': bmi,
    };
  }
}

class GeneralExaminationFindings {
  final String generalAppearance;
  final String levelOfConsciousness;
  final String orientation;
  final String hydration;
  final bool pallor;
  final bool icterus;
  final bool cyanosis;
  final bool clubbing;
  final bool edema;
  final bool lymphadenopathy;
  final String nutritionalStatus;
  final String mobilityGait;

  GeneralExaminationFindings({
    required this.generalAppearance,
    required this.levelOfConsciousness,
    required this.orientation,
    required this.hydration,
    required this.pallor,
    required this.icterus,
    required this.cyanosis,
    required this.clubbing,
    required this.edema,
    required this.lymphadenopathy,
    required this.nutritionalStatus,
    required this.mobilityGait,
  });

  factory GeneralExaminationFindings.fromJson(Map<String, dynamic> json) {
    return GeneralExaminationFindings(
      generalAppearance: json['generalAppearance'] ?? '',
      levelOfConsciousness: json['levelOfConsciousness'] ?? '',
      orientation: json['orientation'] ?? '',
      hydration: json['hydration'] ?? '',
      pallor: json['pallor'] ?? false,
      icterus: json['icterus'] ?? false,
      cyanosis: json['cyanosis'] ?? false,
      clubbing: json['clubbing'] ?? false,
      edema: json['edema'] ?? false,
      lymphadenopathy: json['lymphadenopathy'] ?? false,
      nutritionalStatus: json['nutritionalStatus'] ?? '',
      mobilityGait: json['mobilityGait'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'generalAppearance': generalAppearance,
      'levelOfConsciousness': levelOfConsciousness,
      'orientation': orientation,
      'hydration': hydration,
      'pallor': pallor,
      'icterus': icterus,
      'cyanosis': cyanosis,
      'clubbing': clubbing,
      'edema': edema,
      'lymphadenopathy': lymphadenopathy,
      'nutritionalStatus': nutritionalStatus,
      'mobilityGait': mobilityGait,
    };
  }
}
