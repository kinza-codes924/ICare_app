const express = require('express');
const router = express.Router();
const { authMiddleware: protect } = require('../middleware/auth');

// Import controllers
const healthTrackerController = require('../controllers/healthTrackerController');
const healthSettingsController = require('../controllers/healthSettingsController');
const healthProfileController = require('../controllers/healthProfileController');

// ═══════════════════════════════════════════════════════════════════════════
// HEALTH TRACKER ROUTES
// ═══════════════════════════════════════════════════════════════════════════

// Dashboard
router.get('/tracker/dashboard', protect, healthTrackerController.getDashboard);

// Entries
router.post('/tracker/entries', protect, healthTrackerController.addEntry);
router.get('/tracker/entries', protect, healthTrackerController.getEntries);
router.get('/tracker/entries/latest', protect, healthTrackerController.getLatestEntries);
router.get('/tracker/entries/:vitalType', protect, healthTrackerController.getEntriesByType);
router.put('/tracker/entries/:id', protect, healthTrackerController.updateEntry);
router.delete('/tracker/entries/:id', protect, healthTrackerController.deleteEntry);

// Summary
router.get('/tracker/summary', protect, healthTrackerController.getSummary);

// ═══════════════════════════════════════════════════════════════════════════
// HEALTH SETTINGS ROUTES
// ═══════════════════════════════════════════════════════════════════════════

// General settings
router.get('/settings', protect, healthSettingsController.getSettings);
router.put('/settings', protect, healthSettingsController.updateSettings);

// Health Mode
router.put('/settings/health-mode', protect, healthSettingsController.toggleHealthMode);

// Tracker toggles
router.put('/settings/tracker-toggles', protect, healthSettingsController.updateTrackerToggles);

// Daily goals
router.put('/settings/daily-goals', protect, healthSettingsController.updateDailyGoals);

// Unit preferences
router.put('/settings/unit-preferences', protect, healthSettingsController.updateUnitPreferences);

// Reminders
router.put('/settings/reminders', protect, healthSettingsController.updateReminders);

// Consultation preferences
router.put('/settings/consultation-preferences', protect, healthSettingsController.updateConsultationPreferences);

// Pharmacy preferences
router.put('/settings/pharmacy-preferences', protect, healthSettingsController.updatePharmacyPreferences);

// Lab preferences
router.put('/settings/lab-preferences', protect, healthSettingsController.updateLabPreferences);

// ═══════════════════════════════════════════════════════════════════════════
// HEALTH PROFILE ROUTES
// ═══════════════════════════════════════════════════════════════════════════

// Profile
router.get('/profile', protect, healthProfileController.getProfile);
router.put('/profile', protect, healthProfileController.updateProfile);

// Medical conditions
router.post('/profile/conditions', protect, healthProfileController.addMedicalCondition);
router.put('/profile/conditions/:conditionId', protect, healthProfileController.updateMedicalCondition);
router.delete('/profile/conditions/:conditionId', protect, healthProfileController.deleteMedicalCondition);

// Allergies
router.post('/profile/allergies', protect, healthProfileController.addAllergy);
router.delete('/profile/allergies/:allergyId', protect, healthProfileController.deleteAllergy);

// Medications
router.post('/profile/medications', protect, healthProfileController.addMedication);
router.delete('/profile/medications/:medicationId', protect, healthProfileController.deleteMedication);

// Emergency contacts
router.post('/profile/emergency-contacts', protect, healthProfileController.addEmergencyContact);
router.delete('/profile/emergency-contacts/:contactId', protect, healthProfileController.deleteEmergencyContact);

module.exports = router;
