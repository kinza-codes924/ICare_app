const mongoose = require('mongoose');

const healthTrackerEntrySchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    vitalType: {
      type: String,
      required: true,
      enum: [
        'Blood Pressure',
        'Heart Rate',
        'Blood Glucose',
        'Weight',
        'Temperature',
        'Oxygen Level',
        'Steps',
        'Sleep',
        'Water Intake',
        'Medication Adherence',
      ],
      index: true,
    },
    value: {
      type: String,
      required: true,
    },
    unit: {
      type: String,
      required: true,
    },
    notes: {
      type: String,
      default: '',
    },
    timestamp: {
      type: Date,
      required: true,
      default: Date.now,
      index: true,
    },
    status: {
      type: String,
      enum: ['Normal', 'Healthy', 'Elevated', 'High', 'Low', 'No Data', 'Taken', 'Missed'],
      default: 'Normal',
    },
  },
  {
    timestamps: true,
  }
);

// Compound index for efficient queries
healthTrackerEntrySchema.index({ userId: 1, vitalType: 1, timestamp: -1 });

// Virtual for formatted date
healthTrackerEntrySchema.virtual('formattedDate').get(function () {
  return this.timestamp.toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
  });
});

// Method to determine status based on vital type and value
healthTrackerEntrySchema.methods.determineStatus = function () {
  try {
    const val = parseFloat(this.value.split('/')[0]); // Handle BP like 120/80

    switch (this.vitalType) {
      case 'Blood Pressure':
        const systolic = parseInt(this.value.split('/')[0]);
        const diastolic = parseInt(this.value.split('/')[1]);
        if (systolic >= 140 || diastolic >= 90) return 'High';
        if (systolic >= 120 || diastolic >= 80) return 'Elevated';
        return 'Normal';

      case 'Heart Rate':
        if (val > 100) return 'High';
        if (val < 60) return 'Low';
        return 'Normal';

      case 'Blood Glucose':
        if (val > 140) return 'High';
        if (val < 70) return 'Low';
        return 'Normal';

      case 'Temperature':
        if (val > 37.5) return 'Elevated';
        if (val < 36.0) return 'Low';
        return 'Normal';

      case 'Oxygen Level':
        if (val < 95) return 'Low';
        return 'Normal';

      case 'Weight':
        return 'Normal';

      case 'Steps':
        return 'Normal';

      case 'Sleep':
        if (val < 6) return 'Low';
        if (val > 9) return 'High';
        return 'Normal';

      case 'Water Intake':
        return 'Normal';

      case 'Medication Adherence':
        if (isNaN(val)) return 'Normal';
        if (val >= 80) return 'Taken';
        return 'Missed';

      default:
        return 'Normal';
    }
  } catch (e) {
    return 'Normal';
  }
};

// Static method to get latest entry for each vital type
healthTrackerEntrySchema.statics.getLatestEntries = async function (userId) {
  const vitalTypes = [
    'Blood Pressure',
    'Heart Rate',
    'Blood Glucose',
    'Weight',
    'Temperature',
    'Oxygen Level',
    'Steps',
    'Sleep',
    'Water Intake',
    'Medication Adherence',
  ];

  const latestEntries = await Promise.all(
    vitalTypes.map(async (type) => {
      return await this.findOne({ userId, vitalType: type })
        .sort({ timestamp: -1 })
        .limit(1);
    })
  );

  return latestEntries.filter((entry) => entry !== null);
};

// Static method to get entries for a date range
healthTrackerEntrySchema.statics.getEntriesInRange = async function (
  userId,
  vitalType,
  startDate,
  endDate
) {
  return await this.find({
    userId,
    vitalType,
    timestamp: {
      $gte: startDate,
      $lte: endDate,
    },
  }).sort({ timestamp: -1 });
};

// Static method to get summary statistics
healthTrackerEntrySchema.statics.getSummaryStats = async function (userId, vitalType, days = 7) {
  const startDate = new Date();
  startDate.setDate(startDate.getDate() - days);

  const entries = await this.find({
    userId,
    vitalType,
    timestamp: { $gte: startDate },
  }).sort({ timestamp: 1 });

  if (entries.length === 0) {
    return {
      count: 0,
      average: null,
      min: null,
      max: null,
      trend: 'stable',
    };
  }

  // Calculate statistics (for numeric values)
  const values = entries
    .map((e) => {
      const val = parseFloat(e.value.split('/')[0]);
      return isNaN(val) ? null : val;
    })
    .filter((v) => v !== null);

  if (values.length === 0) {
    return {
      count: entries.length,
      average: null,
      min: null,
      max: null,
      trend: 'stable',
    };
  }

  const average = values.reduce((a, b) => a + b, 0) / values.length;
  const min = Math.min(...values);
  const max = Math.max(...values);

  // Determine trend (compare first half vs second half)
  const midpoint = Math.floor(values.length / 2);
  const firstHalf = values.slice(0, midpoint);
  const secondHalf = values.slice(midpoint);

  const firstAvg = firstHalf.reduce((a, b) => a + b, 0) / firstHalf.length;
  const secondAvg = secondHalf.reduce((a, b) => a + b, 0) / secondHalf.length;

  let trend = 'stable';
  const diff = ((secondAvg - firstAvg) / firstAvg) * 100;
  if (diff > 5) trend = 'increasing';
  if (diff < -5) trend = 'decreasing';

  return {
    count: entries.length,
    average: Math.round(average * 10) / 10,
    min,
    max,
    trend,
    entries: entries.slice(-10), // Last 10 entries
  };
};

module.exports = mongoose.model('HealthTrackerEntry', healthTrackerEntrySchema);
