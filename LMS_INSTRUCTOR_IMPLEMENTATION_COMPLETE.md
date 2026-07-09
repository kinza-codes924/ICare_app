# LMS Instructor Portal - Complete Implementation Guide
**Date**: May 8, 2026
**Status**: In Progress

## Overview
Complete LMS instructor interface similar to Google Classroom and Moodle with full teaching capabilities.

## Instructor Credentials
- **Email**: testinstructuctor@gmail.com
- **Password**: 12345678

## Current Status
- ✅ Dashboard with stats
- ✅ Course creation basic flow
- ⏳ Quiz creation (IN PROGRESS)
- ⏳ Assignment creation (IN PROGRESS)
- ⏳ Grading system (IN PROGRESS)
- ⏳ Student progress monitoring (IN PROGRESS)
- ⏳ Live session scheduling (IN PROGRESS)

## Features to Implement

### 1. Quiz Creation & Management
**Screen**: `instructor_create_quiz_screen.dart`
- Multiple question types (MCQ, True/False, Short Answer)
- Question bank management
- Time limits and attempts
- Auto-grading for MCQs
- Manual grading for subjective questions

### 2. Assignment Creation & Management
**Screen**: `instructor_create_assignment_screen.dart`
- Assignment details (title, description, due date)
- File attachments support
- Rubric creation
- Submission tracking
- Grading interface

### 3. Grading Dashboard
**Screen**: `instructor_grading_screen.dart`
- Pending submissions list
- Quick grading interface
- Feedback system
- Grade book view
- Export grades

### 4. Student Progress Monitoring
**Screen**: `instructor_student_progress_screen.dart`
- Individual student analytics
- Course completion tracking
- Quiz/assignment performance
- Attendance records
- Engagement metrics

### 5. Live Session Management
**Screen**: `instructor_schedule_session_screen.dart`
- Schedule live classes
- Video conferencing integration
- Recording management
- Attendance tracking
- Session materials

### 6. Course Content Management
**Screen**: `instructor_course_content_screen.dart`
- Module organization
- Lesson creation
- Video upload
- Document management
- Content sequencing

### 7. Student Management
**Screen**: `instructor_learners_screen.dart`
- Enrolled students list
- Student profiles
- Communication tools
- Bulk actions
- Performance overview

### 8. Analytics & Reports
**Screen**: `instructor_course_analytics_screen.dart`
- Course performance metrics
- Student engagement
- Completion rates
- Assessment analytics
- Export reports

## Implementation Priority

### Phase 1 (URGENT - Today)
1. ✅ Fix consultation white screen issue
2. ✅ Fix prescription display issue
3. 🔄 Complete quiz creation interface
4. 🔄 Complete assignment creation interface

### Phase 2 (This Week)
1. Grading system
2. Student progress monitoring
3. Live session scheduling
4. Course content management

### Phase 3 (Next Week)
1. Advanced analytics
2. Communication tools
3. Bulk operations
4. Export/import features

## Technical Stack
- **Frontend**: Flutter (Dart)
- **Backend**: Node.js + Express
- **Database**: MongoDB
- **File Storage**: Cloudinary
- **Video**: Agora/Zego

## API Endpoints Needed

### Quiz Management
- POST `/api/quizzes/create` - Create new quiz
- GET `/api/quizzes/course/:courseId` - Get course quizzes
- PUT `/api/quizzes/:quizId` - Update quiz
- DELETE `/api/quizzes/:quizId` - Delete quiz
- GET `/api/quizzes/:quizId/attempts` - Get quiz attempts
- POST `/api/quizzes/:quizId/grade` - Grade quiz attempt

### Assignment Management
- POST `/api/assignments/create` - Create assignment
- GET `/api/assignments/course/:courseId` - Get course assignments
- PUT `/api/assignments/:assignmentId` - Update assignment
- DELETE `/api/assignments/:assignmentId` - Delete assignment
- GET `/api/assignments/:assignmentId/submissions` - Get submissions
- POST `/api/assignments/:assignmentId/grade` - Grade submission

### Student Progress
- GET `/api/instructor/students/:studentId/progress` - Get student progress
- GET `/api/instructor/course/:courseId/analytics` - Get course analytics
- GET `/api/instructor/students/:studentId/attendance` - Get attendance

### Live Sessions
- POST `/api/live-sessions/create` - Schedule session
- GET `/api/live-sessions/instructor/:instructorId` - Get instructor sessions
- PUT `/api/live-sessions/:sessionId` - Update session
- DELETE `/api/live-sessions/:sessionId` - Cancel session
- POST `/api/live-sessions/:sessionId/start` - Start session
- POST `/api/live-sessions/:sessionId/end` - End session

## Database Models

### Quiz Model
```javascript
{
  courseId: ObjectId,
  instructorId: ObjectId,
  title: String,
  description: String,
  duration: Number, // minutes
  totalMarks: Number,
  passingMarks: Number,
  attempts: Number,
  questions: [{
    type: String, // 'mcq', 'true-false', 'short-answer'
    question: String,
    options: [String], // for MCQ
    correctAnswer: String/[String],
    marks: Number,
    explanation: String
  }],
  isPublished: Boolean,
  dueDate: Date,
  createdAt: Date,
  updatedAt: Date
}
```

### Assignment Model
```javascript
{
  courseId: ObjectId,
  instructorId: ObjectId,
  title: String,
  description: String,
  dueDate: Date,
  totalMarks: Number,
  attachments: [String],
  rubric: [{
    criterion: String,
    maxPoints: Number,
    description: String
  }],
  allowLateSubmission: Boolean,
  isPublished: Boolean,
  createdAt: Date,
  updatedAt: Date
}
```

### Assignment Submission Model
```javascript
{
  assignmentId: ObjectId,
  studentId: ObjectId,
  submittedAt: Date,
  files: [String],
  text: String,
  grade: Number,
  feedback: String,
  gradedBy: ObjectId,
  gradedAt: Date,
  status: String // 'submitted', 'graded', 'late'
}
```

## Next Steps
1. Create quiz creation screen with full functionality
2. Create assignment creation screen
3. Implement grading interface
4. Add student progress tracking
5. Integrate live session scheduling

## Notes
- All screens should follow Material Design 3 guidelines
- Use consistent color scheme (AppColors.primaryColor)
- Implement proper error handling
- Add loading states
- Include empty states with helpful messages
- Make responsive for desktop and mobile
