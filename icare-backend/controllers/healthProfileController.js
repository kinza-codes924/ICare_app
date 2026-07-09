const UserHealthProfile = require('../models/UserHealthProfile');

// ═══════════════════════════════════════════════════════════════════════════
// GET USER HEALTH PROFILE
// ═══════════════════════════════════════════════════════════════════════════
exports.getProfile = async (req, res) => {
  try {
    const userId = req.user.id;
    const profile = await UserHealthProfile.getOrCreate(userId);

    res.json({
      success: true,
      profile,
      isComplete: profile.isComplete(),
    });
  } catch (error) {
    console.error('Error fetching health profile:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch health profile',
      error: error.message,
    });
  }
};

// ═══════════════════════════════════════════════════════════════════════════
// UPDATE HEALTH PROFILE
// ═══════════════════════════════════════════════════════════════════════════
exports.updateProfile = async (req, res) => {
  try {
    const userId = req.user.id;
    const updates = req.body;

    const profile = await UserHealthProfile.findOneAndUpdate(
      { userId },
      { $set: updates },
      { new: true, upsert: true, runValidators: true }
    );

    res.json({
      success: true,
      message: 'Health profile updated successfully',
      profile,
    });
  } catch (error) {
    console.error('Error updating health profile:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to update health profile',
      error: error.message,
    });
  }
};

// ═══════════════════════════════════════════════════════════════════════════
// ADD MEDICAL CONDITION
// ═══════════════════════════════════════════════════════════════════════════
exports.addMedicalCondition = async (req, res) => {
  try {
    const userId = req.user.id;
    const { name, diagnosedDate, notes } = req.body;

    if (!name) {
      return res.status(400).json({
        success: false,
        message: 'Condition name is required',
      });
    }

    const profile = await UserHealthProfile.findOneAndUpdate(
      { userId },
      {
        $push: {
          medicalConditions: {
            name,
            diagnosedDate: diagnosedDate ? new Date(diagnosedDate) : undefined,
            notes,
            isActive: true,
          },
        },
      },
      { new: true, upsert: true }
    );

    res.json({
      success: true,
      message: 'Medical condition added successfully',
      profile,
    });
  } catch (error) {
    console.error('Error adding medical condition:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to add medical condition',
      error: error.message,
    });
  }
};

// ═══════════════════════════════════════════════════════════════════════════
// UPDATE MEDICAL CONDITION
// ═══════════════════════════════════════════════════════════════════════════
exports.updateMedicalCondition = async (req, res) => {
  try {
    const userId = req.user.id;
    const { conditionId } = req.params;
    const updates = req.body;

    const profile = await UserHealthProfile.findOne({ userId });
    if (!profile) {
      return res.status(404).json({
        success: false,
        message: 'Profile not found',
      });
    }

    const condition = profile.medicalConditions.id(conditionId);
    if (!condition) {
      return res.status(404).json({
        success: false,
        message: 'Medical condition not found',
      });
    }

    Object.assign(condition, updates);
    await profile.save();

    res.json({
      success: true,
      message: 'Medical condition updated successfully',
      profile,
    });
  } catch (error) {
    console.error('Error updating medical condition:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to update medical condition',
      error: error.message,
    });
  }
};

// ═══════════════════════════════════════════════════════════════════════════
// DELETE MEDICAL CONDITION
// ═══════════════════════════════════════════════════════════════════════════
exports.deleteMedicalCondition = async (req, res) => {
  try {
    const userId = req.user.id;
    const { conditionId } = req.params;

    const profile = await UserHealthProfile.findOneAndUpdate(
      { userId },
      { $pull: { medicalConditions: { _id: conditionId } } },
      { new: true }
    );

    if (!profile) {
      return res.status(404).json({
        success: false,
        message: 'Profile not found',
      });
    }

    res.json({
      success: true,
      message: 'Medical condition deleted successfully',
      profile,
    });
  } catch (error) {
    console.error('Error deleting medical condition:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to delete medical condition',
      error: error.message,
    });
  }
};

// ═══════════════════════════════════════════════════════════════════════════
// ADD ALLERGY
// ═══════════════════════════════════════════════════════════════════════════
exports.addAllergy = async (req, res) => {
  try {
    const userId = req.user.id;
    const { allergen, type, severity, reaction, notes } = req.body;

    if (!allergen) {
      return res.status(400).json({
        success: false,
        message: 'Allergen is required',
      });
    }

    const profile = await UserHealthProfile.findOneAndUpdate(
      { userId },
      {
        $push: {
          allergies: { allergen, type, severity, reaction, notes },
        },
      },
      { new: true, upsert: true }
    );

    res.json({
      success: true,
      message: 'Allergy added successfully',
      profile,
    });
  } catch (error) {
    console.error('Error adding allergy:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to add allergy',
      error: error.message,
    });
  }
};

// ═══════════════════════════════════════════════════════════════════════════
// DELETE ALLERGY
// ═══════════════════════════════════════════════════════════════════════════
exports.deleteAllergy = async (req, res) => {
  try {
    const userId = req.user.id;
    const { allergyId } = req.params;

    const profile = await UserHealthProfile.findOneAndUpdate(
      { userId },
      { $pull: { allergies: { _id: allergyId } } },
      { new: true }
    );

    if (!profile) {
      return res.status(404).json({
        success: false,
        message: 'Profile not found',
      });
    }

    res.json({
      success: true,
      message: 'Allergy deleted successfully',
      profile,
    });
  } catch (error) {
    console.error('Error deleting allergy:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to delete allergy',
      error: error.message,
    });
  }
};

// ═══════════════════════════════════════════════════════════════════════════
// ADD MEDICATION
// ═══════════════════════════════════════════════════════════════════════════
exports.addMedication = async (req, res) => {
  try {
    const userId = req.user.id;
    const { name, dosage, frequency, startDate, endDate, prescribedBy, purpose } = req.body;

    if (!name) {
      return res.status(400).json({
        success: false,
        message: 'Medication name is required',
      });
    }

    const profile = await UserHealthProfile.findOneAndUpdate(
      { userId },
      {
        $push: {
          currentMedications: {
            name,
            dosage,
            frequency,
            startDate: startDate ? new Date(startDate) : undefined,
            endDate: endDate ? new Date(endDate) : undefined,
            prescribedBy,
            purpose,
            isActive: true,
          },
        },
      },
      { new: true, upsert: true }
    );

    res.json({
      success: true,
      message: 'Medication added successfully',
      profile,
    });
  } catch (error) {
    console.error('Error adding medication:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to add medication',
      error: error.message,
    });
  }
};

// ═══════════════════════════════════════════════════════════════════════════
// DELETE MEDICATION
// ═══════════════════════════════════════════════════════════════════════════
exports.deleteMedication = async (req, res) => {
  try {
    const userId = req.user.id;
    const { medicationId } = req.params;

    const profile = await UserHealthProfile.findOneAndUpdate(
      { userId },
      { $pull: { currentMedications: { _id: medicationId } } },
      { new: true }
    );

    if (!profile) {
      return res.status(404).json({
        success: false,
        message: 'Profile not found',
      });
    }

    res.json({
      success: true,
      message: 'Medication deleted successfully',
      profile,
    });
  } catch (error) {
    console.error('Error deleting medication:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to delete medication',
      error: error.message,
    });
  }
};

// ═══════════════════════════════════════════════════════════════════════════
// ADD/UPDATE EMERGENCY CONTACT
// ═══════════════════════════════════════════════════════════════════════════
exports.addEmergencyContact = async (req, res) => {
  try {
    const userId = req.user.id;
    const { name, phone, relation, isPrimary } = req.body;

    if (!name || !phone || !relation) {
      return res.status(400).json({
        success: false,
        message: 'Name, phone, and relation are required',
      });
    }

    const profile = await UserHealthProfile.findOne({ userId });
    if (!profile) {
      const newProfile = await UserHealthProfile.create({
        userId,
        emergencyContacts: [{ name, phone, relation, isPrimary: isPrimary || false }],
      });
      return res.json({
        success: true,
        message: 'Emergency contact added successfully',
        profile: newProfile,
      });
    }

    // If setting as primary, unset other primary contacts
    if (isPrimary) {
      profile.emergencyContacts.forEach((contact) => {
        contact.isPrimary = false;
      });
    }

    profile.emergencyContacts.push({ name, phone, relation, isPrimary: isPrimary || false });
    await profile.save();

    res.json({
      success: true,
      message: 'Emergency contact added successfully',
      profile,
    });
  } catch (error) {
    console.error('Error adding emergency contact:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to add emergency contact',
      error: error.message,
    });
  }
};

// ═══════════════════════════════════════════════════════════════════════════
// DELETE EMERGENCY CONTACT
// ═══════════════════════════════════════════════════════════════════════════
exports.deleteEmergencyContact = async (req, res) => {
  try {
    const userId = req.user.id;
    const { contactId } = req.params;

    const profile = await UserHealthProfile.findOneAndUpdate(
      { userId },
      { $pull: { emergencyContacts: { _id: contactId } } },
      { new: true }
    );

    if (!profile) {
      return res.status(404).json({
        success: false,
        message: 'Profile not found',
      });
    }

    res.json({
      success: true,
      message: 'Emergency contact deleted successfully',
      profile,
    });
  } catch (error) {
    console.error('Error deleting emergency contact:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to delete emergency contact',
      error: error.message,
    });
  }
};

