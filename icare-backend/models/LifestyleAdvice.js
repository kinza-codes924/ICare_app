const mongoose = require('mongoose');

// Sub-schemas for lifestyle advice categories

const dietAdviceSchema = new mongoose.Schema({
  recommendations: String,
  foodsToAvoid: [String],
  foodsToInclude: [String],
  mealTiming: String,
  hydration: String
}, { _id: false });

const exerciseAdviceSchema = new mongoose.Schema({
  type: String,
  frequency: String,
  duration: String,
  intensity: String,
  precautions: [String]
}, { _id: false });

const sleepAdviceSchema = new mongoose.Schema({
  recommendedHours: String,
  sleepSchedule: String,
  sleepHygieneTips: [String]
}, { _id: false });

const stressManagementSchema = new mongoose.Schema({
  techniques: [String],
  recommendations: String
}, { _id: false });

const smokingCessationSchema = new mongoose.Schema({
  plan: String,
  resources: [String],
  timeline: String
}, { _id: false });

const alcoholModerationSchema = new mongoose.Schema({
  recommendations: String,
  limits: String
}, { _id: false });

const weightManagementSchema = new mongoose.Schema({
  targetWeight: Number,
  plan: String,
  timeline: String
}, { _id: false });

// Main Lifestyle Advice Schema
const lifestyleAdviceSchema = new mongoose.Schema({
  consultationId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Consultation',
    required: true
  },
  prescriptionId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'EnhancedPrescription',
    required: true
  },
  
  // Lifestyle advice categories
  diet: dietAdviceSchema,
  exercise: exerciseAdviceSchema,
  sleep: sleepAdviceSchema,
  stress: stressManagementSchema,
  smoking: smokingCessationSchema,
  alcohol: alcoholModerationSchema,
  weight: weightManagementSchema,
  otherAdvice: [String]
}, {
  timestamps: true
});

// Indexes
lifestyleAdviceSchema.index({ consultationId: 1 });
lifestyleAdviceSchema.index({ prescriptionId: 1 });

// Virtual to check if any advice exists
lifestyleAdviceSchema.virtual('hasAnyAdvice').get(function() {
  return !!(
    this.diet ||
    this.exercise ||
    this.sleep ||
    this.stress ||
    this.smoking ||
    this.alcohol ||
    this.weight ||
    (this.otherAdvice && this.otherAdvice.length > 0)
  );
});

module.exports = mongoose.model('LifestyleAdvice', lifestyleAdviceSchema);
