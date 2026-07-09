const mongoose = require('mongoose');

const userHealthProfileSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      unique: true,
      index: true,
    },

    // Basic Health Information
    bloodGroup: {
      type: String,
      enum: ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-', 'Unknown'],
      default: 'Unknown',
    },

    height: {
      value: Number,
      unit: {
        type: String,
        enum: ['cm', 'ft'],
        default: 'cm',
      },
    },

    // Medical Conditions
    medicalConditions: [
      {
        name: {
          type: String,
          required: true,
        },
        diagnosedDate: Date,
        notes: String,
        isActive: {
          type: Boolean,
          default: true,
        },
      },
    ],

    // Allergies
    allergies: [
      {
        allergen: {
          type: String,
          required: true,
        },
        type: {
          type: String,
          enum: ['Food', 'Medicine', 'Environmental', 'Other'],
          default: 'Other',
        },
        severity: {
          type: String,
          enum: ['Mild', 'Moderate', 'Severe'],
          default: 'Moderate',
        },
        reaction: String,
        notes: String,
      },
    ],

    // Current Medications
    currentMedications: [
      {
        name: {
          type: String,
          required: true,
        },
        dosage: String,
        frequency: String, // "Once daily", "Twice daily", "As needed"
        startDate: Date,
        endDate: Date,
        prescribedBy: String, // Doctor name
        purpose: String,
        isActive: {
          type: Boolean,
          default: true,
        },
      },
    ],

    // Health Goals
    healthGoals: [
      {
        goal: {
          type: String,
          required: true,
        },
        targetDate: Date,
        status: {
          type: String,
          enum: ['Not Started', 'In Progress', 'Achieved', 'Abandoned'],
          default: 'Not Started',
        },
        notes: String,
      },
    ],

    // Emergency Contacts
    emergencyContacts: [
      {
        name: {
          type: String,
          required: true,
        },
        phone: {
          type: String,
          required: true,
        },
        relation: {
          type: String,
          required: true,
        },
        isPrimary: {
          type: Boolean,
          default: false,
        },
      },
    ],

    // Family Medical History
    familyMedicalHistory: [
      {
        relation: String, // "Father", "Mother", "Sibling"
        condition: String,
        notes: String,
      },
    ],

    // Lifestyle Information
    lifestyle: {
      smokingStatus: {
        type: String,
        enum: ['Never', 'Former', 'Current', 'Unknown'],
        default: 'Unknown',
      },
      alcoholConsumption: {
        type: String,
        enum: ['Never', 'Occasional', 'Regular', 'Unknown'],
        default: 'Unknown',
      },
      exerciseFrequency: {
        type: String,
        enum: ['Sedentary', 'Light', 'Moderate', 'Active', 'Very Active', 'Unknown'],
        default: 'Unknown',
      },
      dietType: {
        type: String,
        enum: ['Regular', 'Vegetarian', 'Vegan', 'Pescatarian', 'Other', 'Unknown'],
        default: 'Unknown',
      },
    },

    // Insurance Information (Optional)
    insurance: {
      provider: String,
      policyNumber: String,
      expiryDate: Date,
    },
  },
  {
    timestamps: true,
  }
);

// Method to get active medications
userHealthProfileSchema.methods.getActiveMedications = function () {
  return this.currentMedications.filter((med) => med.isActive);
};

// Method to get active medical conditions
userHealthProfileSchema.methods.getActiveConditions = function () {
  return this.medicalConditions.filter((cond) => cond.isActive);
};

// Method to get primary emergency contact
userHealthProfileSchema.methods.getPrimaryEmergencyContact = function () {
  return this.emergencyContacts.find((contact) => contact.isPrimary) || this.emergencyContacts[0];
};

// Static method to get or create profile for a user
userHealthProfileSchema.statics.getOrCreate = async function (userId) {
  let profile = await this.findOne({ userId });
  if (!profile) {
    profile = await this.create({ userId });
  }
  return profile;
};

// Method to check if profile is complete
userHealthProfileSchema.methods.isComplete = function () {
  const requiredFields = [
    this.bloodGroup !== 'Unknown',
    this.emergencyContacts.length > 0,
    this.medicalConditions.length > 0 || this.allergies.length > 0,
  ];
  return requiredFields.every((field) => field);
};

module.exports = mongoose.model('UserHealthProfile', userHealthProfileSchema);
