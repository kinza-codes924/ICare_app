const UserHealthSettings = require('../models/UserHealthSettings');

// ═══════════════════════════════════════════════════════════════════════════
// GET USER HEALTH SETTINGS
// ═══════════════════════════════════════════════════════════════════════════
exports.getSettings = async (req, res) => {
  try {
    const userId = req.user.id;
    const settings = await UserHealthSettings.getOrCreate(userId);

    res.json({
      success: true,
      settings,
    });
  } catch (error) {
    console.error('Error fetching health settings:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch health settings',
      error: error.message,
    });
  }
};

// ═══════════════════════════════════════════════════════════════════════════
// UPDATE HEALTH SETTINGS
// ═══════════════════════════════════════════════════════════════════════════
exports.updateSettings = async (req, res) => {
  try {
    const userId = req.user.id;
    const updates = req.body;

    const settings = await UserHealthSettings.findOneAndUpdate(
      { userId },
      { $set: updates },
      { new: true, upsert: true, runValidators: true }
    );

    res.json({
      success: true,
      message: 'Settings updated successfully',
      settings,
    });
  } catch (error) {
    console.error('Error updating health settings:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to update health settings',
      error: error.message,
    });
  }
};

// ═══════════════════════════════════════════════════════════════════════════
// TOGGLE HEALTH MODE
// ═══════════════════════════════════════════════════════════════════════════
exports.toggleHealthMode = async (req, res) => {
  try {
    const userId = req.user.id;
    const { enabled, conditions } = req.body;

    const settings = await UserHealthSettings.findOneAndUpdate(
      { userId },
      {
        $set: {
          healthModeEnabled: enabled,
          ...(conditions && { selectedConditions: conditions }),
        },
      },
      { new: true, upsert: true }
    );

    res.json({
      success: true,
      message: `Health Mode ${enabled ? 'enabled' : 'disabled'}`,
      settings,
    });
  } catch (error) {
    console.error('Error toggling health mode:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to toggle health mode',
      error: error.message,
    });
  }
};

// ═══════════════════════════════════════════════════════════════════════════
// UPDATE TRACKER TOGGLES
// ═══════════════════════════════════════════════════════════════════════════
exports.updateTrackerToggles = async (req, res) => {
  try {
    const userId = req.user.id;
    const { trackedVitals } = req.body;

    if (!trackedVitals || typeof trackedVitals !== 'object') {
      return res.status(400).json({
        success: false,
        message: 'Invalid tracker toggles data',
      });
    }

    const settings = await UserHealthSettings.findOneAndUpdate(
      { userId },
      { $set: { trackedVitals } },
      { new: true, upsert: true }
    );

    res.json({
      success: true,
      message: 'Tracker toggles updated successfully',
      settings,
    });
  } catch (error) {
    console.error('Error updating tracker toggles:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to update tracker toggles',
      error: error.message,
    });
  }
};

// ═══════════════════════════════════════════════════════════════════════════
// UPDATE DAILY GOALS
// ═══════════════════════════════════════════════════════════════════════════
exports.updateDailyGoals = async (req, res) => {
  try {
    const userId = req.user.id;
    const { dailyGoals } = req.body;

    if (!dailyGoals || typeof dailyGoals !== 'object') {
      return res.status(400).json({
        success: false,
        message: 'Invalid daily goals data',
      });
    }

    const settings = await UserHealthSettings.findOneAndUpdate(
      { userId },
      { $set: { dailyGoals } },
      { new: true, upsert: true }
    );

    res.json({
      success: true,
      message: 'Daily goals updated successfully',
      settings,
    });
  } catch (error) {
    console.error('Error updating daily goals:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to update daily goals',
      error: error.message,
    });
  }
};

// ═══════════════════════════════════════════════════════════════════════════
// UPDATE UNIT PREFERENCES
// ═══════════════════════════════════════════════════════════════════════════
exports.updateUnitPreferences = async (req, res) => {
  try {
    const userId = req.user.id;
    const { unitPreferences } = req.body;

    if (!unitPreferences || typeof unitPreferences !== 'object') {
      return res.status(400).json({
        success: false,
        message: 'Invalid unit preferences data',
      });
    }

    const settings = await UserHealthSettings.findOneAndUpdate(
      { userId },
      { $set: { unitPreferences } },
      { new: true, upsert: true }
    );

    res.json({
      success: true,
      message: 'Unit preferences updated successfully',
      settings,
    });
  } catch (error) {
    console.error('Error updating unit preferences:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to update unit preferences',
      error: error.message,
    });
  }
};

// ═══════════════════════════════════════════════════════════════════════════
// UPDATE REMINDERS
// ═══════════════════════════════════════════════════════════════════════════
exports.updateReminders = async (req, res) => {
  try {
    const userId = req.user.id;
    const { reminders } = req.body;

    if (!reminders || typeof reminders !== 'object') {
      return res.status(400).json({
        success: false,
        message: 'Invalid reminders data',
      });
    }

    const settings = await UserHealthSettings.findOneAndUpdate(
      { userId },
      { $set: { reminders } },
      { new: true, upsert: true }
    );

    res.json({
      success: true,
      message: 'Reminders updated successfully',
      settings,
    });
  } catch (error) {
    console.error('Error updating reminders:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to update reminders',
      error: error.message,
    });
  }
};

// ═══════════════════════════════════════════════════════════════════════════
// UPDATE CONSULTATION PREFERENCES
// ═══════════════════════════════════════════════════════════════════════════
exports.updateConsultationPreferences = async (req, res) => {
  try {
    const userId = req.user.id;
    const { consultationPreferences } = req.body;

    const settings = await UserHealthSettings.findOneAndUpdate(
      { userId },
      { $set: { consultationPreferences } },
      { new: true, upsert: true }
    );

    res.json({
      success: true,
      message: 'Consultation preferences updated successfully',
      settings,
    });
  } catch (error) {
    console.error('Error updating consultation preferences:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to update consultation preferences',
      error: error.message,
    });
  }
};

// ═══════════════════════════════════════════════════════════════════════════
// UPDATE PHARMACY PREFERENCES
// ═══════════════════════════════════════════════════════════════════════════
exports.updatePharmacyPreferences = async (req, res) => {
  try {
    const userId = req.user.id;
    const { pharmacyPreferences } = req.body;

    const settings = await UserHealthSettings.findOneAndUpdate(
      { userId },
      { $set: { pharmacyPreferences } },
      { new: true, upsert: true }
    );

    res.json({
      success: true,
      message: 'Pharmacy preferences updated successfully',
      settings,
    });
  } catch (error) {
    console.error('Error updating pharmacy preferences:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to update pharmacy preferences',
      error: error.message,
    });
  }
};

// ═══════════════════════════════════════════════════════════════════════════
// UPDATE LAB PREFERENCES
// ═══════════════════════════════════════════════════════════════════════════
exports.updateLabPreferences = async (req, res) => {
  try {
    const userId = req.user.id;
    const { labPreferences } = req.body;

    const settings = await UserHealthSettings.findOneAndUpdate(
      { userId },
      { $set: { labPreferences } },
      { new: true, upsert: true }
    );

    res.json({
      success: true,
      message: 'Lab preferences updated successfully',
      settings,
    });
  } catch (error) {
    console.error('Error updating lab preferences:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to update lab preferences',
      error: error.message,
    });
  }
};

