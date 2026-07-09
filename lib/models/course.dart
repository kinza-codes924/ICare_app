class Course {
  final String id;
  final String title;
  final String description;
  final String instructorId;
  final String? instructorName;
  final String? instructorEmail;
  final CourseCategory category;
  final TargetAudience targetAudience;
  final List<String> healthConditions;
  final CourseDifficulty? difficulty;
  final int? duration; // hours
  final List<CourseModule> modules;
  final String? thumbnail;
  final bool isPublished;
  final DateTime? publishedAt;
  final int enrollmentCount;
  final CourseRating rating;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String courseType; // 'self-paced' or 'pragmatic'
  final DateTime? startDate; // For pragmatic courses

  Course({
    required this.id,
    required this.title,
    required this.description,
    required this.instructorId,
    this.instructorName,
    this.instructorEmail,
    required this.category,
    required this.targetAudience,
    this.healthConditions = const [],
    this.difficulty,
    this.duration,
    this.modules = const [],
    this.thumbnail,
    this.isPublished = false,
    this.publishedAt,
    this.enrollmentCount = 0,
    required this.rating,
    required this.createdAt,
    required this.updatedAt,
    this.courseType = 'self-paced',
    this.startDate,
  });

  factory Course.fromJson(Map<String, dynamic> json) {
    // Handle instructor field (can be ObjectId string or populated object)
    String instructorId;
    String? instructorName;
    String? instructorEmail;

    if (json['instructor'] is String) {
      instructorId = json['instructor'];
    } else if (json['instructor'] is Map) {
      final instructor = json['instructor'] as Map<String, dynamic>;
      instructorId = instructor['_id'] ?? instructor['id'] ?? '';
      instructorName = instructor['name'];
      instructorEmail = instructor['email'];
    } else if (json['instructor_id'] != null) {
      // Backend stores as instructor_id
      instructorId = json['instructor_id'].toString();
    } else {
      instructorId = '';
    }

    return Course(
      id: json['_id'] ?? json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      instructorId: instructorId,
      instructorName: instructorName,
      instructorEmail: instructorEmail,
      category: CourseCategoryExtension.fromString(
        json['category'] ?? 'HealthProgram',
      ),
      targetAudience: TargetAudienceExtension.fromString(
        json['targetAudience'] ?? 'Patient',
      ),
      healthConditions:
          (json['healthConditions'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      difficulty: json['difficulty'] != null
          ? CourseDifficultyExtension.fromString(json['difficulty'])
          : null,
      duration: _parseDuration(json['duration']),
      modules:
          (json['modules'] as List?)
              ?.map((m) => CourseModule.fromJson(m))
              .toList() ??
          [],
      thumbnail: json['thumbnail'] ?? json['thumbnail_url'],
      isPublished: json['isPublished'] == true || json['visibility'] == 'public',
      publishedAt: json['publishedAt'] != null
          ? DateTime.parse(json['publishedAt'])
          : null,
      enrollmentCount: json['enrollmentCount'] ?? 0,
      rating: CourseRating.fromJson(json['rating']),
      createdAt: DateTime.parse(
        json['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        json['updatedAt'] ?? DateTime.now().toIso8601String(),
      ),
      courseType: json['courseType']?.toString() ?? 'self-paced',
      startDate: json['startDate'] != null
          ? DateTime.parse(json['startDate'])
          : null,
    );
  }

  static int? _parseDuration(dynamic duration) {
    if (duration == null) return null;
    if (duration is int) return duration;
    if (duration is String) {
      // Handle strings like "15 minutes" or "2 hours"
      final match = RegExp(r'(\d+)').firstMatch(duration);
      if (match != null) {
        return int.tryParse(match.group(1)!);
      }
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'category': category.value,
      'targetAudience': targetAudience.value,
      'healthConditions': healthConditions,
      if (difficulty != null) 'difficulty': difficulty!.value,
      if (duration != null) 'duration': duration,
      'modules': modules.map((m) => m.toJson()).toList(),
      if (thumbnail != null) 'thumbnail': thumbnail,
      'courseType': courseType,
      if (startDate != null) 'startDate': startDate!.toIso8601String(),
    };
  }
}

class CourseModule {
  final String? id;
  final String title;
  final String description;
  final int order;
  final List<Lesson> lessons;
  final Quiz? quiz;
  final int unlockAfterDays; // For pragmatic courses

  CourseModule({
    this.id,
    required this.title,
    required this.description,
    required this.order,
    this.lessons = const [],
    this.quiz,
    this.unlockAfterDays = 0,
  });

  factory CourseModule.fromJson(Map<String, dynamic> json) {
    return CourseModule(
      id: json['_id'],
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      order: json['order'] ?? 0,
      lessons:
          (json['lessons'] as List?)?.map((l) => Lesson.fromJson(l)).toList() ??
          [],
      quiz: json['quiz'] != null ? Quiz.fromJson(json['quiz']) : null,
      unlockAfterDays: json['unlockAfterDays'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'order': order,
      'lessons': lessons.map((l) => l.toJson()).toList(),
      if (quiz != null) 'quiz': quiz!.toJson(),
      'unlockAfterDays': unlockAfterDays,
    };
  }
}

class Lesson {
  final String? id;
  final String title;
  final String content;
  final String? videoUrl;
  final String? documentUrl;
  final int? duration; // minutes
  final int order;
  final List<LessonResource> resources;

  Lesson({
    this.id,
    required this.title,
    required this.content,
    this.videoUrl,
    this.documentUrl,
    this.duration,
    required this.order,
    this.resources = const [],
  });

  factory Lesson.fromJson(Map<String, dynamic> json) {
    return Lesson(
      id: json['_id'],
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      videoUrl: json['videoUrl'] ?? json['video_url'],
      documentUrl: json['documentUrl'] ?? json['document_url'],
      duration: json['duration'] ?? json['duration_minutes'],
      order: json['order'] ?? 0,
      resources:
          (json['resources'] as List?)
              ?.map((r) => LessonResource.fromJson(r))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'content': content,
      if (videoUrl != null) 'videoUrl': videoUrl,
      if (documentUrl != null) 'documentUrl': documentUrl,
      if (duration != null) 'duration': duration,
      'order': order,
      'resources': resources.map((r) => r.toJson()).toList(),
    };
  }
}

class LessonResource {
  final String title;
  final String url;
  final String type;

  LessonResource({required this.title, required this.url, required this.type});

  factory LessonResource.fromJson(Map<String, dynamic> json) {
    return LessonResource(
      title: json['title'] ?? '',
      url: json['url'] ?? '',
      type: json['type'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'title': title, 'url': url, 'type': type};
  }
}

class Quiz {
  final List<QuizQuestion> questions;
  final int passingScore;

  Quiz({required this.questions, required this.passingScore});

  factory Quiz.fromJson(Map<String, dynamic> json) {
    return Quiz(
      questions:
          (json['questions'] as List?)
              ?.map((q) => QuizQuestion.fromJson(q))
              .toList() ??
          [],
      passingScore: json['passingScore'] ?? 70,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'questions': questions.map((q) => q.toJson()).toList(),
      'passingScore': passingScore,
    };
  }
}

class QuizQuestion {
  final String question;
  final List<String> options;
  final int correctAnswer;
  final String? explanation;

  QuizQuestion({
    required this.question,
    required this.options,
    required this.correctAnswer,
    this.explanation,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    return QuizQuestion(
      question: json['question'] ?? '',
      options:
          (json['options'] as List?)?.map((o) => o.toString()).toList() ?? [],
      correctAnswer: json['correctAnswer'] ?? 0,
      explanation: json['explanation'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'question': question,
      'options': options,
      'correctAnswer': correctAnswer,
      if (explanation != null) 'explanation': explanation,
    };
  }
}

class CourseRating {
  final double average;
  final int count;

  CourseRating({this.average = 0.0, this.count = 0});

  factory CourseRating.fromJson(dynamic json) {
    if (json is num) return CourseRating(average: json.toDouble());
    if (json is Map<String, dynamic>) {
      return CourseRating(
        average: (json['average'] ?? 0).toDouble(),
        count: json['count'] ?? 0,
      );
    }
    return CourseRating();
  }

  Map<String, dynamic> toJson() {
    return {'average': average, 'count': count};
  }
}

enum CourseCategory { healthProgram, professionalCourse, fcpsPart1 }

extension CourseCategoryExtension on CourseCategory {
  String get value {
    switch (this) {
      case CourseCategory.healthProgram:
        return 'HealthProgram';
      case CourseCategory.professionalCourse:
        return 'ProfessionalCourse';
      case CourseCategory.fcpsPart1:
        return 'FCPSPart1';
    }
  }

  String get displayName {
    switch (this) {
      case CourseCategory.healthProgram:
        return 'Health Program';
      case CourseCategory.professionalCourse:
        return 'Professional Course';
      case CourseCategory.fcpsPart1:
        return 'FCPS Part 1';
    }
  }

  static CourseCategory fromString(String value) {
    switch (value) {
      case 'HealthProgram':
        return CourseCategory.healthProgram;
      case 'ProfessionalCourse':
        return CourseCategory.professionalCourse;
      case 'FCPSPart1':
        return CourseCategory.fcpsPart1;
      default:
        return CourseCategory.healthProgram;
    }
  }
}

enum TargetAudience {
  patient,
  doctor,
  laboratory,
  pharmacy,
  student,
  instructor,
  both,
  all,
}

extension TargetAudienceExtension on TargetAudience {
  String get value {
    switch (this) {
      case TargetAudience.patient:
        return 'Patient';
      case TargetAudience.doctor:
        return 'Doctor';
      case TargetAudience.laboratory:
        return 'Laboratory';
      case TargetAudience.pharmacy:
        return 'Pharmacy';
      case TargetAudience.student:
        return 'Student';
      case TargetAudience.instructor:
        return 'Instructor';
      case TargetAudience.both:
        return 'Both';
      case TargetAudience.all:
        return 'All';
    }
  }

  String get displayName {
    switch (this) {
      case TargetAudience.patient:
        return 'For Patients (Diet Plan & Health Courses)';
      case TargetAudience.doctor:
        return 'For Healthcare Professionals (Training Programs)';
      case TargetAudience.laboratory:
        return 'Laboratories';
      case TargetAudience.pharmacy:
        return 'Pharmacies';
      case TargetAudience.student:
        return 'Students';
      case TargetAudience.instructor:
        return 'Instructors';
      case TargetAudience.both:
        return 'Both Patients & Professionals';
      case TargetAudience.all:
        return 'All Users';
    }
  }

  static TargetAudience fromString(String value) {
    switch (value) {
      case 'Patient':
        return TargetAudience.patient;
      case 'Doctor':
        return TargetAudience.doctor;
      case 'Laboratory':
        return TargetAudience.laboratory;
      case 'Pharmacy':
        return TargetAudience.pharmacy;
      case 'Student':
        return TargetAudience.student;
      case 'Instructor':
        return TargetAudience.instructor;
      case 'Both':
        return TargetAudience.both;
      case 'All':
        return TargetAudience.all;
      default:
        return TargetAudience.patient;
    }
  }
}

enum CourseDifficulty { beginner, intermediate, advanced }

extension CourseDifficultyExtension on CourseDifficulty {
  String get value {
    switch (this) {
      case CourseDifficulty.beginner:
        return 'Beginner';
      case CourseDifficulty.intermediate:
        return 'Intermediate';
      case CourseDifficulty.advanced:
        return 'Advanced';
    }
  }

  String get displayName {
    switch (this) {
      case CourseDifficulty.beginner:
        return 'Beginner';
      case CourseDifficulty.intermediate:
        return 'Intermediate';
      case CourseDifficulty.advanced:
        return 'Advanced';
    }
  }

  static CourseDifficulty fromString(String value) {
    switch (value) {
      case 'Beginner':
        return CourseDifficulty.beginner;
      case 'Intermediate':
        return CourseDifficulty.intermediate;
      case 'Advanced':
        return CourseDifficulty.advanced;
      default:
        return CourseDifficulty.beginner;
    }
  }
}
