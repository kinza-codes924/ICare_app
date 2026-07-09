const mongoose = require('mongoose');

const userHealthSettingsSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      unique: true,
      index: true,
    },

    // Health Mode Settings
    healthModeEnabled: {
      type: Boolean,
      default: false,
    },
    selectedConditions: {
      type: [String],
      enum: ['Diabetes', 'Hypertension', 'Heart Disease', 'Weight Management', 'General'],
      default: ['General'],
    },

    // Tracker Settings - What to track
    trackedVitals: {
      bloodPressure: { type: Boolean, default: true },
      bloodSugar: { type: Boolean, default: true },
      weight: { type: Boolean, default: false },
      water: { type: Boolean, default: true },
      medication: { type: Boolean, default: true },
      steps: { type: Boolean, default: false },
      sleep: { type: Boolean, default: false },
      heartRate: { type: Boolean, default: true },
      temperature: { type: Boolean, default: false },
      oxygenLevel: { type: Boolean, default: false },
    },

    // Daily Goals
    dailyGoals: {
      water: { type: Number, default: 8 }, // glasses
      steps: { type: Number, default: 10000 },
      sleep: { type: Number, default: 8 }, // hours
    },

    // Unit Preferences
    unitPreferences: {
      weight: {
        type: String,
        enum: ['kg', 'lbs'],
        default: 'kg',
      },
      bloodSugar: {
        type: String,
        enum: ['mg/dL', 'mmol/L'],
        default: 'mg/dL',
      },
    },

    // Reminders
    reminders: {
      medication: [
        {
          time: String, // "09:00", "14:00", "21:00"
          enabled: { type: Boolean, default: true },
          label: String, // Optional label like "Morning dose"
        },
      ],
      water: {
        interval: { type: Number, default: 120 }, // minutes
        enabled: { type: Boolean, default: false },
      },
      healthCheck: {
        time: { type: String, default: '09:00' },
        enabled: { type: Boolean, default: false },
      },
    },

    // Consultation Preferences
    consultationPreferences: {
      preferredLanguage: {
        type: String,
        enum: ['English', 'Urdu'],
        default: 'English',
      },
      preferredDoctorGender: {
        type: String,
        enum: ['Male', 'Female', 'No Preference'],
        default: 'No Preference',
      },
      allowHistoryAccess: { type: Boolean, default: true },
      videoQuality: {
        type: String,
        enum: ['Auto', 'High', 'Medium', 'Low'],
        default: 'Auto',
      },
    },

    // Pharmacy Preferences
    pharmacyPreferences: {
      preferredPharmacyId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Pharmacy',
        default: null,
      },
      defaultDeliveryAddress: {
        street: String,
        city: String,
        postalCode: String,
        phone: String,
      },
      deliveryPreference: {
        type: String,
        enum: ['Home Delivery', 'Self Pickup'],
        default: 'Home Delivery',
      },
    },

    // Lab/Diagnostics Preferences
    labPreferences: {
      homeSampleCollection: { type: Boolean, default: true },
      reportDeliveryMethod: {
        type: String,
        enum: ['Email', 'SMS', 'App Only', 'All'],
        default: 'All',
      },
    },

    // Learning/LMS Preferences
    learningPreferences: {
      notifyNewCourses: { type: Boolean, default: true },
      notifyAssignments: { type: Boolean, default: true },
      notifyCertificates: { type: Boolean, default: true },
    },

    // Notification Preferences
    notificationPreferences: {
      appointments: { type: Boolean, default: true },
      prescriptions: { type: Boolean, default: true },
      labResults: { type: Boolean, default: true },
      promotions: { type: Boolean, default: false },
      healthTips: { type: Boolean, default: true },
    },
  },
  {
    timestamps: true,
  }
);

// Method to get vitals to display based on health mode
userHealthSettingsSchema.methods.getRelevantVitals = function () {
  if (!this.healthModeEnabled) {
    // Return all tracked vitals
    return Object.keys(this.trackedVitals).filter((key) => this.trackedVitals[key]);
  }

  // Map conditions to relevant vitals
  const conditionVitalsMap = {
    Diabetes: ['bloodSugar', 'weight', 'medication', 'steps'],
    Hypertension: ['bloodPressure', 'heartRate', 'medication', 'weight'],
    'Heart Disease': ['heartRate', 'bloodPressure', 'steps', 'weight', 'oxygenLevel'],
    'Weight Management': ['weight', 'steps', 'water', 'sleep'],
    General: Object.keys(this.trackedVitals),
  };

  // Combine vitals from all selected conditions
  const relevantVitals = new Set();
  this.selectedConditions.forEach((condition) => {
    const vitals = conditionVitalsMap[condition] || [];
    vitals.forEach((vital) => {
      if (this.trackedVitals[vital]) {
        relevantVitals.add(vital);
      }
    });
  });

  return Array.from(relevantVitals);
};

// Static method to get or create settings for a user
userHealthSettingsSchema.statics.getOrCreate = async function (userId) {
  let settings = await this.findOne({ userId });
  if (!settings) {
    settings = await this.create({ userId });
  }
  return settings;
};

module.exports = mongoose.model('UserHealthSettings', userHealthSettingsSchema);
